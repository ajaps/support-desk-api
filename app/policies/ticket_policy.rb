class TicketPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      user.agent? ? scope.all : scope.where(customer: user)
    end
  end

  # Any authenticated customer can create a ticket
  def create?  = user.customer?

  # Agents see all; customers see only their own
  def show?
    user.agent? || record.customer_id == user.id
  end

  # Only agents may change status or reassign
  def update?  = user.agent?

  # support tickets are generally immutable for audit purposes
  def destroy? = false

  # CSV export is agent-only
  def export?  = user.agent?
end
