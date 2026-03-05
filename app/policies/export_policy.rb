class ExportPolicy < ApplicationPolicy
  def show? = user.agent? && record.agent_id == user.id
end
