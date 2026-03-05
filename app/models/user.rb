class User < ApplicationRecord
  has_secure_password
  has_many :exports,             foreign_key: "agent_id",    dependent: :nullify
  has_many :assigned_tickets,    class_name:  "Ticket",
                                 foreign_key: :agent_id,     dependent: :nullify
  has_many :tickets_as_customer, class_name:  "Ticket",
                                 foreign_key: :customer_id,  dependent: :restrict_with_error

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

  before_save { self.email = email.downcase }
end
