class Comment < ApplicationRecord
  belongs_to :ticket
  belongs_to :user

  validates :body, presence: true, length: { maximum: 5000 }

  validate   :customer_can_only_reply_after_agent, if: :customer_commenter?
  validate   :customer_cannot_comment_on_closed_ticket, if: :customer_commenter?
  validate   :user_must_be_ticket_owner, if: :customer_commenter?
  after_create :set_agent_replied_at, if: -> { user.agent? && ticket.agent_replied_at.nil? }

  def customer_commenter?
    return false unless user

    user.customer?
  end

  private

  def set_agent_replied_at
    now = Time.current
    ticket.update_column(:agent_replied_at, now)
    ticket.agent_replied_at = now
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
