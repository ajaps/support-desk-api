class Comment < ApplicationRecord
  belongs_to :ticket
  belongs_to :user

  validates :body, presence: true, length: { maximum: 5000 }

  validate   :customer_can_only_reply_after_agent, if: :customer_commenter?
  validate   :customer_cannot_comment_on_closed_ticket, if: :customer_commenter?
  validate   :user_must_be_ticket_owner, if: :customer_commenter?
  after_create :update_ticket_state

  def customer_commenter?
    return false unless user

    user.customer?
  end

  private

  def update_ticket_state
    if user.agent?
      unless ticket.closed?
        ticket.agent_replied_at ||= Time.current  # set timestamp on first agent reply
        ticket.agent_replied! if ticket.may_agent_replied?
        # agent_replied! (AASM) persists both agent_replied_at and the status change.
        # When already awaiting_customer, may_agent_replied? is false — no save needed
        # because agent_replied_at was already set (||= is a no-op).
      end
    elsif user.customer?
      ticket.customer_replied! if ticket.may_customer_replied?
    end
  end

  def user_must_be_ticket_owner
    unless ticket.customer == user
      errors.add(:user, "must be the ticket owner")
    end
  end

  def customer_cannot_comment_on_closed_ticket
    if ticket.closed?
      errors.add(:base, "Customers cannot comment on a closed ticket.")
    end
  end

  def customer_can_only_reply_after_agent
    if ticket.agent_replied_at.nil?
      errors.add(:base, "Customers can only comment after a support agent has replied.")
    end
  end
end
