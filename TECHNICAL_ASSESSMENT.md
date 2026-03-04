# Technical Assessment Report — Customer Support Ticketing System

---

## 1. Architecture & Design

### Overview

The system is a full-stack customer support ticketing platform built as two decoupled applications:

- **Backend:** Rails 8.1 API (`support_desk_api`) — GraphQL, PostgreSQL, SolidQueue
- **Frontend:** Vue 3 SPA (`support-desk-ui`) — Apollo Client, Pinia, Tailwind CSS

Communication between the two is entirely through a single GraphQL endpoint (`POST /graphql`).

---

### Backend Architecture

#### Technology Choices

| Layer | Technology | Rationale |
|---|---|---|
| Framework | Rails 8.1 (API-only) | Mature conventions, fast to build correct things |
| Database | PostgreSQL | Relational data with FK constraints and indexing |
| API Layer | GraphQL (graphql-ruby) | Single endpoint, self-documenting schema, flexible queries for different client roles |
| Auth | JWT (HS256) + bcrypt | Stateless, fits an API-first design; bcrypt for secure password storage |
| Authorization | Pundit | Policy objects that are explicit, testable, and co-located with domain logic |
| Background Jobs | SolidQueue | Runs in-process within Puma — no external queue dependency, backed by PostgreSQL |
| File Storage | Active Storage | Direct upload to storage (no round-tripping files through the API server) |
| Testing | RSpec + FactoryBot + SimpleCov | Industry-standard Rails test stack; 90% coverage enforced |

#### Domain Model

```
User (customer | agent)
  └── has_many tickets (as customer)
  └── has_many tickets (as agent, optional)
  └── has_many exports (as agent)

Ticket
  └── belongs_to customer (User)
  └── belongs_to agent (User, optional)
  └── has_many comments
  └── has_one_attached file

Comment
  └── belongs_to ticket
  └── belongs_to user (customer or agent)

Export
  └── belongs_to agent (User, optional — nil for system exports)
  └── has_one_attached file (CSV)
  └── enum status: { pending: 0, completed: 1, failed: 2 }
```

#### Ticket Lifecycle

```
[Customer] CreateTicket
      │
      ▼
  status: open  (closed_at: nil)
      │
      ├── [Agent] AssignTicket → ticket.agent = current_user
      │
      ├── [Agent/Customer] CreateComment
      │       └── auto-assigns agent on first agent comment
      │
      └── [Agent] CloseTicket → closed_at = Time.current
                    └── auto-assigns if still unassigned
                    └── status: closed
```

#### GraphQL Schema

**Queries (6):** `tickets`, `ticket`, `me`, `node`, `nodes`, `averageAgentResponseTime`

**Mutations (7):** `signUp`, `signIn`, `createTicket`, `assignTicket`, `closeTicket`, `createComment`, `exportRecentlyClosedTickets`

Role-based scoping is enforced at the Pundit policy level — agents see all tickets, customers see only their own.

#### Background Jobs & Async Workflows

**ExportTicketsJob** (queue: `exports`)
- Triggered by `exportRecentlyClosedTickets` mutation
- Generates a CSV of tickets closed in the past 30 days
- Attaches the file to the Export record, updates status to `completed`, emails a presigned download link
- Retries up to 3 times with polynomial backoff on failure

**DailyTicketReminderJob** (queue: `mailers`)
- Scheduled via SolidQueue recurring tasks
- Generates a CSV of all currently open tickets
- Emails every agent a daily summary

#### Authentication & Authorization

- JWT tokens (HS256, 24-hour TTL) are issued on sign-in and signed with a secret stored in Rails credentials
- Every request authenticates via `Authorization: Bearer <token>` — extracted in an `Authenticatable` concern on the controller, user loaded from the database
- Pundit policies are called inside each mutation; authorization failures surface as GraphQL errors
- Policy scopes control what records are returned in queries (agents see all tickets; customers see their own)

#### Deployment

The API is containerized with a `Dockerfile.dev` / `docker-compose.yml` for local development and a production `Dockerfile` targeting Kamal or Render. SolidQueue is activated in Docker via `SOLID_QUEUE_IN_PUMA=true`, running jobs in-process alongside Puma.

---

### Frontend Architecture

#### Technology Choices

| Layer | Technology | Rationale |
|---|---|---|
| Framework | Vue 3 (Composition API) | Reactive, composable, ergonomic with `<script setup>` |
| Build Tool | Vite | Sub-second HMR, ESM-native |
| GraphQL Client | Apollo Client + `@vue/apollo-composable` | Deep Vue integration; reactive `useQuery`/`useMutation` composables |
| State Management | Pinia | Lightweight, Composition API-native; simpler than Vuex |
| Routing | Vue Router 4 | Navigation guards for auth + role enforcement |
| Styling | Tailwind CSS + CSS custom properties | Utility classes with a theme system (dark/light) via CSS variables |
| File Upload | `@rails/activestorage` DirectUpload | Files go directly to storage, returning a signed ID — no file payload in GraphQL |

#### Application Structure

```
src/
├── apollo/        Apollo Client (auth link, error link, HTTP link chain)
├── graphql/       GQL operation definitions (auth, tickets, comments, analytics)
├── stores/        Pinia stores (auth — JWT + user; theme — dark/light)
├── router/        Routes + navigation guards
├── composables/   useGraphqlErrors (error normalization), useTimeAgo (reactive dayjs)
├── utils/         upload.js (ActiveStorage DirectUpload with progress tracking)
├── components/    Shared UI primitives (AppButton, AppAlert, AppBadge, AppInput…)
├── layout/        AppSidebar (agent-only), AppTopbar
└── views/         Auth, TicketList, TicketDetail, CreateTicket
```

#### Authentication Flow

1. User submits credentials → `signIn`/`signUp` mutation
2. JWT + user object stored in `localStorage` via Pinia auth store
3. Apollo `authLink` injects `Authorization: Bearer <token>` on every request
4. Apollo `errorLink` listens for auth errors; clears token and redirects to `/login` automatically
5. Vue Router guard blocks unauthenticated navigation at the route level

#### Role-Based UI

Both roles (customer, agent) share the same views but render conditionally based on `auth.isAgent` / `auth.isCustomer`:

- Agents see the `AppSidebar` with open/closed ticket counts and the average response time widget
- Customers see a "New Ticket" button and only their own tickets
- The `/tickets/new` route is guarded — agents are redirected away

#### Error Handling

A `useGraphqlErrors` composable normalizes errors from three sources:
1. Top-level GraphQL errors (e.g., auth failures)
2. Mutation-level `errors[]` arrays (e.g., validation messages)
3. Network-level `ApolloError` exceptions

A `safeCall(fn, mutationKey)` wrapper catches all three shapes and populates a reactive `errors` array that views bind to `<AppAlert>`.

---

## 2. Key Implementation Decisions

### Soft-delete tickets via `closed_at` timestamp instead of a status enum

Ticket status (`open`/`closed`) is derived from the presence of `closed_at`. This means no enum to migrate if states change, and the close timestamp is a first-class audit datum available for queries (e.g., `recently_closed` scope) rather than having to store it separately. A boolean or enum would have required a separate `closed_at` column anyway.

### GraphQL over REST

A single endpoint simplifies routing configuration, CORS setup, and deployment. The self-documenting schema (introspection) is useful for a take-home assessment context. The cost is slightly higher initial setup. With two clearly distinct roles that need different data shapes from the same resources, the flexibility of GraphQL field selection was worth it.

### Pundit policies as the single source of authorization truth

Authorization rules are enforced in one place (policy objects) rather than scattered across mutations, models, and queries. The policy scope pattern (`Scope#resolve`) ensures that record-level scoping is consistent — there is no way to call a mutation and accidentally fetch a record you should not see, because scoped queries are used to look up records before acting on them.

### SolidQueue in-process instead of Sidekiq/Redis

The assessment does not require a horizontally scaled queue. Running SolidQueue inside Puma via `SOLID_QUEUE_IN_PUMA=true` means the Docker Compose setup is just two containers (app + database) — no Redis, no separate worker process. The trade-off is that jobs contend with web requests for Puma threads in production, but this is acceptable for the scale of this project.

### Active Storage DirectUpload for file attachments

Files are sent from the browser directly to storage, bypassing the API server entirely. The frontend receives a `signed_id` which it passes in the GraphQL mutation. This keeps the API server stateless with respect to file data and avoids holding large payloads in memory during uploads.

### Presigned URLs with short TTL for exports

Export download URLs expire in 10 minutes (file preview) and 24 hours (email link). This prevents stale links from granting access to sensitive data indefinitely without requiring a server-side token invalidation mechanism.

### `useGraphqlErrors` composable on the frontend

GraphQL error payloads from `graphql-ruby` can arrive in three different shapes depending on where the error originates. Rather than handling each shape ad-hoc in every view, a single composable with a `safeCall` wrapper normalizes them all. This avoided significant repetition across four views that all perform mutations.

### Denormalized `agent_replied_at` column instead of a JOIN query

To determine whether a customer is allowed to comment, the app needs to know if an agent has already replied on the ticket. The naive approach queries comments on every permission check — a JOIN across `comments` and `users`, fired from both `TicketPolicy#add_comment?` and `CommentPolicy#create?`. Instead, a `agent_replied_at :datetime` column on `tickets` is set via an `after_create` callback on `Comment` when the first agent comment is saved. The policy checks become single column reads (`record.agent_replied_at.present?`), and the callback runs inside the same transaction as the comment insert so both succeed or fail atomically. The column also doubles as a first-response timestamp for SLA analytics.

### Cursor-based pagination with server-side filtering on the ticket list

The backend's `tickets` query already exposed Relay-style cursor pagination (`first`, `after`, `pageInfo`, `totalCount`). Rather than loading all tickets and filtering client-side — which does not scale — the frontend passes `first: 10` and the active status filter as query variables. Results are accumulated across pages via a `watch` on the query result, and a separate aliased `TicketCounts` query (`open: tickets(status: "open") { totalCount }` / `closed: tickets(status: "closed") { totalCount }`) keeps the stats accurate regardless of which page or filter is active.

---

## 3. Issues Faced

### SolidQueue table setup was non-obvious

SolidQueue requires its own schema separate from the main application schema. The tables are loaded with `bundle exec rails db:schema:load:queue` — a distinct command that is easy to miss. Running `db:migrate` alone results in missing queue tables and a silent startup failure where background jobs are never processed.

### `DailyTicketReminderJob` had two bugs introduced during implementation

- The ticket scope used `status: "ready"` (a non-existent value) instead of `where(closed_at: nil)` to find open tickets
- `User.agents` was used instead of the correct `User.agent` scope (generated by `enum :role`)

Both failures were silent at boot time and only surfaced when the job was executed, requiring careful reading of the job code against the model's actual scope names.

### Export model validation conflicted with system-generated exports

The `Export` model originally required an `agent` (the belongs_to association). The `DailyTicketReminderJob` creates exports with no agent (they are system-generated), causing validation failures that silently swallowed the job. The fix was making `belongs_to :agent` optional and adding a conditional validation: `validates :agent, presence: true, unless: -> { export_type == "daily_reminder" }`.

### CORS configuration for DirectUpload

The Rails ActiveStorage direct upload endpoint (`/rails/active_storage/direct_uploads`) requires its own CORS configuration. The initial CORS setup only allowed `POST /graphql`, so file uploads failed in the browser with a CORS preflight error. Ensuring the `rack-cors` configuration covered the Active Storage paths as well resolved this.

---

## 4. What I Would Do Differently With More Time

**Fix the role injection vulnerability in `signUp`.** The mutation currently accepts a `role:` argument, meaning anyone can self-register as an agent. The fix is to remove `role` from the public input and default all registrations to `customer`. Agents would be promoted via an admin mutation or a separate invite flow.

**Implement JWT logout with a denylist.** The token payload already includes a `jti` (JWT ID) claim. A `revoked_tokens` table keyed on `jti` with an expiry-aware cleanup job would allow true sign-out without requiring short token TTLs for all users.

**Add TypeScript to the frontend.** The Vue 3 + Vite setup supports TypeScript out of the box. Type-safe GraphQL operations (via codegen from the schema) and typed Pinia stores would eliminate a whole class of runtime errors and make refactoring safer.

**Introduce a richer ticket lifecycle with an `awaiting_customer` state.** The current binary open/closed model is sufficient, but a real support product benefits from distinguishing "waiting on agent" from "waiting on customer". Adding an `awaiting_customer` state — set when an agent replies — would enable agent dashboards to split queues by urgency, power SLA tracking per-phase, and support a proper resolve/reopen flow (agent marks resolved → customer has a window to reopen → auto-closes). This is worth implementing once the product has the corresponding UI and business logic; adding the state without those would be premature complexity.

**Improve observability.** There is no structured logging, no error tracking (Sentry), and no job monitoring dashboard. For a production deployment, integrating Sentry (or similar) on both the Rails API and the Vue frontend, and enabling SolidQueue's built-in web UI, would be the first operational additions.
