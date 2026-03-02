class Export < ApplicationRecord
  belongs_to :agent, class_name: "User"
  has_one_attached :file

  validates :export_type, presence: true
  validates :status, presence: true
  validates :agent, presence: true

  validate :single_pending_export_per_agent, if: :pending?
  validate :cannot_download_multiple_exports_within_short_timeframe

  scope :recent, -> { order(created_at: :desc) }

  enum :status, { pending: 0, completed: 1, failed: 2 }

  def presigned_url
    return unless file.attached?

    file.url(expires_in: 10.minutes)
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

  def cannot_download_multiple_exports_within_short_timeframe
    return unless agent_id

    if Export.where(agent_id: agent_id, filename: filename)
                           .where.not(id: id).exists?
      errors.add(:base, "You have recently exported tickets. Please wait before exporting again.")
    end
  end
end
