module Mutations
  module Auth
    class SignIn < BaseMutation
      argument :email,    String, required: true
      argument :password, String, required: true

      field :token,  String,          null: true
      field :user,   Types::UserType, null: true
      field :errors, [String],        null: false

      def resolve(email:, password:)
        user = User.find_by(email: email.downcase.strip)

        if user&.authenticate(password)   # has_secure_password method
          { token: TokenService.encode(user), user: user, errors: [] }
        else
          { token: nil, user: nil, errors: ["Invalid email or password"] }
        end
      end
    end
  end
end