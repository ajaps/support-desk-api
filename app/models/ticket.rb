class Ticket < ApplicationRecord
  include TicketStateMachine

  belongs_to :customer, class_name: "User"
  belongs_to :agent,    class_name: "User", optional: true

  has_many :comments, dependent: :destroy
  has_one_attached :file

  validates :title, presence: true, length: { maximum: 255 }
  validates :description, presence: true
  validate :creator_must_be_customer, on: :create
  validate :file_content_type
  validate :assigned_must_be_agent
  validates :file, size: { less_than: 4.megabytes }, if: -> { file.attached? }


  scope :recently_closed, -> { where(status: "closed").where(closed_at: 1.month.ago.beginning_of_day..Time.current) }
  scope :open_tickets,    -> { where.not(status: "closed") }

  def agent_comments
    comments.joins(:user).where(users: { role: User.roles[:agent] })
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
      errors.add(:file, "must be PNG, JPEG, or PDF")
    end
  end
end
