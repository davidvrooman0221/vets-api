# frozen_string_literal: true

require 'rails_helper'

describe EVSS::EVSSCommon::Service do
  let(:current_user) { build(:evss_user) }

  subject { described_class.new(current_user) }

  context 'with a user' do
    it 'posts to create a user account' do
      VCR.use_cassette('evss/common/create_user_account_client', VCR::MATCH_EVERYTHING) do
        response = subject.create_user_account
        expect(response).to be_success
      end
    end
  end
end