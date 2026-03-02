class User < ApplicationRecord
  has_secure_password
  has_many :exports, foreign_key: "agent_id", dependent: :nullify

  enum :role, { customer: 0, agent: 1 }

  validates :email,
          presence: true,
          uniqueness: { case_sensitive: false },
          format: {
            with: /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/,
            message: "must be a valid email address"
          }
  validates :name,     presence: true
  validates :password, length: { minimum: 8 }, if: -> { new_record? || password.present? }

  before_save { email.downcase! }

  def tickets_as_customer
    Ticket.where(customer_id: id)
  end
end
