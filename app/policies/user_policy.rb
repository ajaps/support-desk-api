class UserPolicy < ApplicationPolicy
  def show? = user.agent? || record.id == user.id
end
