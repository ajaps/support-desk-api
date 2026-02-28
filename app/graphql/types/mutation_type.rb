# frozen_string_literal: true

module Types
  class MutationType < Types::BaseObject
    field :sign_up,              mutation: Mutations::Auth::SignUp
    field :sign_in,              mutation: Mutations::Auth::SignIn
    field :create_ticket,        mutation: Mutations::Tickets::CreateTicket
    field :close_ticket,         mutation: Mutations::Tickets::CloseTicket
    field :assign_ticket,        mutation: Mutations::Tickets::AssignTicket
    field :create_comment,       mutation: Mutations::Comments::CreateComment
  end
end
