module TicketStateMachine
  extend ActiveSupport::Concern

  included do
    include AASM

    # State machine for the ticket lifecycle.
    #
    # States:
    #   open              – ticket created, awaiting first agent response
    #   awaiting_agent    – customer has replied; agent needs to act
    #   awaiting_customer – agent has replied; waiting on the customer
    #   closed            – ticket resolved; no further action expected
    #
    # Transitions are driven by comment creation (see Comment#update_ticket_state)
    # and by the explicit closeTicket mutation.

    aasm column: :status do
      state :open,              initial: true
      state :awaiting_agent
      state :awaiting_customer
      state :closed

      # Agent posts a reply → move to awaiting_customer
      event :agent_replied do
        transitions from: %i[open awaiting_agent], to: :awaiting_customer
      end

      # Customer posts a reply → move back to awaiting_agent
      event :customer_replied do
        transitions from: :awaiting_customer, to: :awaiting_agent
      end

      # Agent explicitly closes the ticket (from any non-closed state)
      event :close do
        before { self.closed_at = Time.current }
        transitions from: %i[open awaiting_agent awaiting_customer], to: :closed
      end
    end
  end
end
