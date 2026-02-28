class User < ApplicationRecord
  has_secure_password

  enum :role, { customer: 0, agent: 1 }
  # has_many :submitted_tickets, class_name: "Ticket", foreign_key: "customer_id", dependent: :nullify
  # has_many :assigned_tickets, class_name: "Ticket", foreign_key: "agent_id", dependent: :nullify

  validates :email,    presence: true,
                       uniqueness: { case_sensitive: false },
                       format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name,     presence: true
  validates :password, length: { minimum: 8 }, if: -> { new_record? || password.present? }

  before_save { email.downcase! }

  def tickets_as_customer
    Ticket.where(customer_id: id)
  end
end
