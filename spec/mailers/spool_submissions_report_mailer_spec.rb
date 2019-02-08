# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SpoolSubmissionsReportMailer, type: %i[mailer aws_helpers] do
  describe '#build' do
    let(:filename) { 'foo' }
    let(:mail) { described_class.build(filename).deliver_now }
    subject do
      stub_reports_s3(filename) do
        mail
      end
    end

    it 'should send the right email' do
      subject
      text = described_class::REPORT_TEXT
      expect(mail.body.encoded).to eq("#{text} (link expires in one week)<br>#{subject}")
      expect(mail.subject).to eq(text)
      expect(mail.to).to include('lihan@adhocteam.us')
    end

    context 'when not sending staging emails' do
      before do
        expect(FeatureFlipper).to receive(:staging_email?).once.and_return(false)
      end

      it 'should email the the right recipients' do
        subject

        expect(mail.to).to eq(
          %w[
            lihan@adhocteam.us
            dana.kuykendall@va.gov
            Jennifer.Waltz2@va.gov
            shay.norton@va.gov
            DONALD.NOBLE2@va.gov
            Darla.VanNieukerk@va.gov
            Walter_Jenny@bah.com
            Hoffmaster_David@bah.com
            akulkarni@meetveracity.com
          ]
        )
      end
    end

    context 'when sending staging emails' do
      before do
        expect(FeatureFlipper).to receive(:staging_email?).once.and_return(true)
        expect(FeatureFlipper).to receive(:staging_host?).once.and_return(true)
      end

      it 'should email the the right staging recipients' do
        subject

        expect(mail.to).to eq(
          %w[
            lihan@adhocteam.us
            akulkarni@meetveracity.com
            Hoffmaster_David@bah.com
            Turner_Desiree@bah.com
            Delli-Gatti_Michael@bah.com
            Walter_Jenny@bah.com
          ]
        )
      end
    end

    context 'when sending dev emails' do
      before do
        expect(FeatureFlipper).to receive(:staging_email?).once.and_return(true)
        expect(FeatureFlipper).to receive(:staging_host?).once.and_return(false)
      end

      it 'should email the the right staging recipients' do
        subject

        expect(mail.to).to eq(
          %w[
            lihan@adhocteam.us
          ]
        )
      end
    end
  end
end
