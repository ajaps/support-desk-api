class Export < ApplicationRecord
  belongs_to :agent, class_name: "User", optional: true
  has_one_attached :file

  validates :export_type, presence: true
  validates :status, presence: true
  validates :agent, presence: true, unless: -> { export_type == "daily_reminder" }

  validate :single_pending_export_per_agent, if: :pending?
  validate :cannot_export_too_frequently
  validate :ticket_array_valid_json, if: -> { ticket_array.present? }

  scope :recent, -> { order(created_at: :desc) }

  enum :status, { pending: 0, completed: 1, failed: 2 }

  def presigned_url
    return unless file.attached?

    file.url(expires_in: 10.minutes)
  end

  def ticket_count
    return 0 unless ticket_array.present?

    JSON.parse(ticket_array).size
  end

  private

  def single_pending_export_per_agent
    return unless agent_id

    if Export.where(agent_id: agent_id, status: Export.statuses[:pending])
             .where.not(id: id)
             .exists?
      errors.add(:base, "Agent already has a pending export")
    end
  end

  def cannot_export_too_frequently
    return unless agent_id

    if Export.where(agent_id: agent_id)
             .where(created_at: 5.minutes.ago..)
             .where.not(id: id)
             .exists?
      errors.add(:base, "You have recently exported tickets. Please wait before exporting again.")
    end
  end

  def ticket_array_valid_json
    JSON.parse(ticket_array)
  rescue JSON::ParserError
    errors.add(:ticket_array, "must be valid JSON")
  end
end
