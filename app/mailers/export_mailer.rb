class ExportMailer < ApplicationMailer
  default from: "no-reply@support-desk.com"

  def ready(user, export)
    @user   = user
    @export = export

    raise "Export file not attached" unless @export.file.attached?
    ActiveStorage::Current.url_options = Rails.application.config.action_mailer.default_url_options
    @download_url = @export.file.url(expires_in: 24.hours)

    mail(
      to: @user.email,
      subject: "Your closed tickets export is ready - #{export.created_at.strftime('%Y-%m-%d %H:%M')}"
    )
  end
end
