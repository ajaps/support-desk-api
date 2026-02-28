module Types
  class CommentType < BaseObject
    field :id,         ID,       null: false
    field :body,       String,   null: false
    field :user,       UserType, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end