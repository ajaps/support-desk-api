class CommentPolicy < ApplicationPolicy
  def create?
    return true if user.agent?

    # Customers can only comment on their own ticket AND only after an agent has
    # already commented
    return false unless record.ticket.customer_id == user.id

    record.ticket.comments.joins(:user).where(users: { role: "agent" }).exists?
  end

  def show? = ticket_visible?

  private

  def ticket_visible?
    user.agent? || record.ticket.customer_id == user.id
  end
end
