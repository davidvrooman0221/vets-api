# frozen_string_literal: true

require 'rails_helper'

describe Veteran do
  context 'initialization' do
    let(:user) { FactoryBot.create(:user, :loa3) }
    let(:auth_headers) { EVSS::AuthHeaders.new(user).to_h }

    before do
      @client_stub = instance_double('EVSS::CommonService')
      allow(EVSS::CommonService).to receive(:new).with(auth_headers) { @client_stub }
    end

    it 'should initialize from a user' do
      allow(@client_stub).to receive(:get_current_info) { get_fixture('json/veteran_with_poa') }
      veteran = Veteran.new(user)
      expect(veteran.veteran_name).to eq('JEFF TERRELL WATSON')
      expect(veteran.power_of_attorney.code).to eq('A1Q')
    end

    it 'should not bomb out if poa is missing' do
      allow(@client_stub).to receive(:get_current_info) { get_fixture('json/veteran_without_poa') }
      veteran = Veteran.new(user)
      expect(veteran.veteran_name).to eq('JEFF TERRELL WATSON')
      expect(veteran.power_of_attorney).to eq(nil)
    end
  end
end