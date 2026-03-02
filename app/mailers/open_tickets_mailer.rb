class OpenTicketsMailer < ApplicationMailer
  default from: "no-reply@support-desk.com"

  def ready(user, export)
    @user   = user
    @export = export
    @url    = Rails.application.routes.url_helpers.rails_blob_url(
      @export.file,
      host: Rails.application.config.action_mailer.default_url_options[:host]
    )

    mail(
      to:      @user.email,
      subject: "📋 Daily Open Tickets Report — #{Date.today.strftime("%B %d, %Y")}"
    )
  end
end
