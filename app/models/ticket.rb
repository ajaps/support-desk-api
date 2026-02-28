class Ticket < ApplicationRecord
  belongs_to :customer, class_name: "User"
  belongs_to :agent,    class_name: "User", optional: true

  has_many :comments, dependent: :destroy
  has_many_attached :attachments

  validates :title, presence: true, length: { maximum: 255 }
  validates :description, presence: true
  validate :attachments_content_type
  validate :creator_must_be_customer, on: :create
  validate :assigned_must_be_agent

  scope :recently_closed, -> { where.not(closed_at: nil).where("closed_at >= ?", 1.month.ago) }
  scope :open_tickets, -> { where(closed_at: nil) }

  def close!
    return true if closed?
    
    update(closed_at: Time.current)
  end

  def closed?
    closed_at.present?
  end

  def status
    return "pending" if agent.present? && closed_at.nil?

    closed? ? "closed" : "open"
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

  def attachments_content_type
    attachments.each do |attachment|
      unless attachment.content_type.in?(%w[image/png image/jpeg image/gif application/pdf])
        errors.add(:attachments, "must be PNG, JPEG, GIF, or PDF")
      end
    end
  end
end
