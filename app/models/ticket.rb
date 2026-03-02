class Ticket < ApplicationRecord
  belongs_to :customer, class_name: "User"
  belongs_to :agent,    class_name: "User", optional: true

  has_many :comments, dependent: :destroy
  has_one_attached :file

  validates :title, presence: true, length: { maximum: 255 }
  validates :description, presence: true
  validate :creator_must_be_customer, on: :create
  validate :file_content_type
  validate :assigned_must_be_agent
  validates :file, attached: false, if: -> { file.attached? }
  validates :file, content_type: [ "image/png", "image/jpeg", "application/pdf" ], if: -> { file.attached? }
  validates :file, size: { less_than: 4.megabytes }, if: -> { file.attached? }

  scope :recently_closed, -> { where.not(closed_at: nil).where(closed_at: 1.month.ago.beginning_of_day..Time.current) }
  scope :open_tickets, -> { where(closed_at: nil) }

  def close!
    return true if closed?

    update(closed_at: Time.current)
  end

  def closed?
    closed_at.present?
  end

  def status
    # return "pending" if agent.present? && closed_at.nil?

    closed? ? "closed" : "open"
  end

  def agent_comments
    comments.joins(:user).where(users: { role: "agent" })
  end

  private

  def creator_must_be_customer
    if customer && !customer.customer?
      errors.add(:customer, "must be a customer")
    end
  end

  def assigned_must_be_agent
    return if agent.nil?

    errors.add(:agent, "must be an agent") if !agent.agent?
  end

  def file_content_type
    return unless file.attached?

    unless file.content_type.in?(%w[image/png image/jpeg image/gif application/pdf])
      errors.add(:file, "must be PNG, JPEG, GIF, or PDF")
    end
  end
end
