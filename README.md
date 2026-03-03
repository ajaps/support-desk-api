# Support Desk API

A GraphQL API for a customer support ticketing system. Customers submit tickets, agents manage and respond to them, and the system handles file attachments, comments, role-based access, and async job processing.

## Tech Stack

| Layer | Technology |
| --- | --- |
| Framework | Rails 8.1 (API mode) |
| Language | Ruby 3.4.3 |
| API | GraphQL |
| Database | PostgreSQL |
| Auth | JWT + bcrypt |
| Authorization | Pundit |
| Background jobs | SolidQueue (runs inside Puma) |
| File uploads | Active Storage |
| Rate limiting | Rack::Attack |
| Deployment | Render (Docker) |

---

## Getting Started

### Prerequisites

- Ruby 3.4.3 ([rbenv](https://github.com/rbenv/rbenv) or [mise](https://mise.jdx.dev) recommended)
- PostgreSQL
- Bundler

### Local setup

```bash
git clone <repo-url>
cd support_desk_api

bundle install
rails db:prepare
rails s
```

The API is available at `http://localhost:3000/graphql`.

### Docker (dev) - Recommended

```bash
docker compose build
docker compose up
```

The API is available at `http://localhost:3000/graphql`.

> `docker compose up` and `rails s` are interchangeable — use whichever you prefer. They connect to separate databases so data does not mix between the two.

---

## Environment Variables

Copy `.env.example` to `.env` and fill in the values:

```bash
cp .env.example .env
```

| Variable | Description | Default |
| --- | --- | --- |
| `DATABASE_URL` | PostgreSQL connection URL | Unix socket (local) |
| `QUEUE_DATABASE_URL` | SolidQueue DB URL (defaults to `DATABASE_URL`) | — |
| `REDIS_URL` | Redis for ActionCable | `redis://localhost:6379/0` |
| `RAILS_MASTER_KEY` | Decrypts `config/credentials.yml.enc` | read from `config/master.key` |
| `FRONTEND_URL` | Allowed CORS origin | `http://localhost:5173` |
| `APP_HOST` | Used in mailer link generation | `localhost:3000` |
| `APP_PROTOCOL` | `http` or `https` | `http` |
| `SOLID_QUEUE_IN_PUMA` | Set to `"true"` to run SolidQueue inside Puma | off locally |

---

## API

All requests go to a single endpoint:

```text
POST /graphql
Content-Type: application/json
Authorization: Bearer <token>   # required for authenticated operations
```

### Authentication

#### Sign up

```graphql
mutation {
  signUp(input: {
    name: "Jane Doe"
    email: "jane@example.com"
    password: "password123"
  }) {
    token
    user { id name email role }
  }
}
```

#### Sign in

```graphql
mutation {
  signIn(input: {
    email: "jane@example.com"
    password: "password123"
  }) {
    token
    user { id name email role }
  }
}
```

### Queries

#### List tickets

```graphql
query {
  tickets(status: "open") {
    edges {
      node {
        id title description status createdAt
        customer { id name }
        agent { id name }
      }
    }
  }
}
```

`status` accepts `"open"` or `"closed"`. Omit to return all tickets the current user can see.

#### Get a ticket

```graphql
query {
  ticket(id: "1") {
    id title description status
    comments { id body user { name role } }
  }
}
```

#### Current user

```graphql
query {
  me { id name email role }
}
```

### Mutations

#### Create ticket *(customers only)*

```graphql
mutation {
  createTicket(input: {
    title: "Login button is broken"
    description: "Clicking the login button does nothing on mobile."
  }) {
    ticket { id title status }
    errors
  }
}
```

Accepts an optional `file` upload (PNG, JPEG, PDF — max 4 MB).

#### Assign ticket *(agents only)*

```graphql
mutation {
  assignTicket(input: { ticketId: "1", agentId: "5" }) {
    ticket { id agent { name } }
    errors
  }
}
```

#### Close ticket *(agents only)*

```graphql
mutation {
  closeTicket(input: { ticketId: "1" }) {
    ticket { id status closedAt }
    errors
  }
}
```

#### Add comment

```graphql
mutation {
  createComment(input: { ticketId: "1", body: "We are looking into this." }) {
    comment { id body user { name role } }
    errors
  }
}
```

#### Export recently closed tickets *(agents only)*

```graphql
mutation {
  exportRecentlyClosedTickets(input: {}) {
    export { id status }
    errors
  }
}
```

Enqueues a background job that generates a CSV of tickets closed in the last month and emails it to the requesting agent.

---

## User Roles

| Capability | Customer | Agent |
| --- | --- | --- |
| Create ticket | ✓ | |
| View own tickets | ✓ | |
| View all tickets | | ✓ |
| Assign ticket | | ✓ |
| Close ticket | | ✓ |
| Comment on ticket | ✓ | ✓ |
| Export closed tickets | | ✓ |

---

## Development

### View sent emails

Emails are captured locally and viewable in the browser — no mail server required:

```text
http://localhost:3000/letter_opener
```

### Run tests

```bash
bundle exec rspec
```

### Security audit

```bash
bundle exec brakeman          # static analysis
bundle exec bundle-audit      # dependency vulnerabilities
```

### Background jobs

SolidQueue runs inside Puma when `SOLID_QUEUE_IN_PUMA=true` (set automatically in Docker). It is off by default for `rails s` so no extra setup is needed locally.

To process jobs locally when needed:

```bash
SOLID_QUEUE_IN_PUMA=true rails s
# first-time queue table setup also required:
# rails db:schema:load:queue
```

---

## Deployment (Render)

The repository includes a `render.yaml` blueprint that provisions:

- PostgreSQL database
- Redis instance
- Web service (built from `Dockerfile`)

### Steps

1. Push the repo to GitHub
2. In the Render dashboard — **New** → **Blueprint** → connect the repo
3. Render auto-detects `render.yaml` and creates all services
4. Set the following **secret** environment variables in the Render dashboard:

| Variable | Where to get it |
| --- | --- |
| `RAILS_MASTER_KEY` | Contents of `config/master.key` |
| `FRONTEND_URL` | Your frontend URL, e.g. `https://your-app.vercel.app` |
| `APP_HOST` | Your Render API URL, e.g. `your-api.onrender.com` |

On the first deploy, `db:prepare` runs automatically and the SolidQueue tables are created if they do not exist yet.
