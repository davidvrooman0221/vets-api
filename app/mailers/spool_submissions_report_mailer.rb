# frozen_string_literal: true

class SpoolSubmissionsReportMailer < ApplicationMailer
  REPORT_TEXT = 'Spool submissions report'
  RECIPIENTS = %w[
    lihan@adhocteam.us
    dana.kuykendall@va.gov
    Jennifer.Waltz2@va.gov
    shay.norton@va.gov
    DONALD.NOBLE2@va.gov
    Darla.VanNieukerk@va.gov
    Walter_Jenny@bah.com
    Hoffmaster_David@bah.com
    akulkarni@meetveracity.com
  ].freeze
  STAGING_RECIPIENTS = %w[
    lihan@adhocteam.us
    akulkarni@meetveracity.com
    Hoffmaster_David@bah.com
    Turner_Desiree@bah.com
    Delli-Gatti_Michael@bah.com
    Walter_Jenny@bah.com
  ].freeze
  DEV_RECIPIENTS = %w[
    lihan@adhocteam.us
  ].freeze

  def build(report_file)
    url = Reports::Uploader.get_s3_link(report_file)

    opt = {}
    # just send email for staging as dev doesn't have SFTP enabled
    opt[:to] =
      if FeatureFlipper.staging_email?
        if FeatureFlipper.staging_host?
          STAGING_RECIPIENTS.clone
        else
          DEV_RECIPIENTS.clone
        end
      else
        RECIPIENTS.clone
      end

    mail(
      opt.merge(
        subject: REPORT_TEXT,
        body: "#{REPORT_TEXT} (link expires in one week)<br>#{url}"
      )
    )
  end
end
