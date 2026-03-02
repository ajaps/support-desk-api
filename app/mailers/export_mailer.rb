class ExportMailer < ApplicationMailer
  default from: "no-reply@support-desk.com"

  def ready(user, export)
    @user   = user
    @export = export

    raise "Export file not attached" unless @export.file.attached?

    @download_url = Rails.application.routes.url_helpers.rails_blob_url(
      @export.file,
      host: Rails.application.config.action_mailer.default_url_options[:host]
    )

    mail(
      to: @user.email,
      subject: "Your closed tickets export is ready - #{export.created_at.strftime('%Y-%m-%d %H:%M')}"
    )
  end
end
