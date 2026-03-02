class Export < ApplicationRecord
  belongs_to :agent, class_name: "User"
  has_one_attached :file

  enum :status, { pending: 0, completed: 1, failed: 2 }
  validates :export_type, presence: true
  validates :exported_at, presence: true
  validates :status, presence: true
  validates :agent, presence: true

  # prevent multiple exports creating at the same time for the same user
  validates :agent_id, uniqueness: { scope: :status, conditions: -> { where(status: :pending) }, message: "already has a pending export" }

  scope :recent, -> { order(created_at: :desc) }

  def presigned_url
    return unless file.attached?

    file.url(expires_in: 10.minutes)
  end
end
