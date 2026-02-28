module Mutations
  module Auth
    class SignUp < BaseMutation
      argument :name,     String, required: true
      argument :email,    String, required: true
      argument :password, String, required: true
      argument :role,     String, required: false, default_value: "customer"

      field :token,  String,          null: true
      field :user,   Types::UserType, null: true
      field :errors, [String],        null: false

      def resolve(name:, email:, password:, role:)
        user = User.new(name: name, email: email, password: password, role: role)
        if user.save
          { token: TokenService.encode(user), user: user, errors: [] }
        else
          { token: nil, user: nil, errors: user.errors.full_messages }
        end
      end
    end
  end
end