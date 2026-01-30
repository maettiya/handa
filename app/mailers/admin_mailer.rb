class AdminMailer < ApplicationMailer
  ADMIN_EMAIL = "matt@handa.app".freeze

  # Notify admin when a new user signs up
  def new_signup(user)
    @user = user
    @user_count = User.count

    mail(
      to: ADMIN_EMAIL,
      subject: "New handa signup: #{user.username}"
    )
  end
end
