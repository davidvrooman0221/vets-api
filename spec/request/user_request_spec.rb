# frozen_string_literal: true

require 'rails_helper'
require 'backend_services'

RSpec.describe 'Fetching user data', type: :request do
  include SchemaMatchers

  context 'GET /v0/user - when an LOA 3 user is logged in' do
    let(:mhv_user) { build(:user, :mhv) }

    before(:each) do
      allow_any_instance_of(MhvAccountTypeService).to receive(:mhv_account_type).and_return('Premium')
      mhv_account = double('MhvAccount', creatable?: false, upgradable?: false, account_state: 'upgraded')
      allow(MhvAccount).to receive(:find_or_initialize_by).and_return(mhv_account)
      allow(mhv_account).to receive(:user_uuid).and_return(mhv_user.uuid)
      allow(mhv_account).to receive(:terms_and_conditions_accepted?).and_return(true)
      allow(mhv_account).to receive(:needs_terms_acceptance?).and_return(false)
      allow(mhv_account).to receive(:user=).and_return(mhv_user)
      create(:account, idme_uuid: mhv_user.uuid)
      sign_in_as(mhv_user)
      get v0_user_url, params: nil
    end

    it 'GET /v0/user - returns proper json' do
      assert_response :success
      expect(response).to match_response_schema('user_loa3')
    end

    it 'gives me the list of available prefill forms' do
      num_enabled = 2
      num_enabled += FormProfile::EDU_FORMS.length if Settings.edu.prefill
      num_enabled += FormProfile::HCA_FORMS.length if Settings.hca.prefill
      num_enabled += FormProfile::PENSION_BURIAL_FORMS.length if Settings.pension_burial.prefill
      num_enabled += FormProfile::VIC_FORMS.length if Settings.vic.prefill
      num_enabled += FormProfile::EVSS_FORMS.length if Settings.evss.prefill

      expect(JSON.parse(response.body)['data']['attributes']['prefills_available'].length).to be(num_enabled)
    end

    it 'gives me the list of available services' do
      expect(JSON.parse(response.body)['data']['attributes']['services'].sort).to eq(
        [
          BackendServices::FACILITIES,
          BackendServices::HCA,
          BackendServices::EDUCATION_BENEFITS,
          BackendServices::EVSS_CLAIMS,
          BackendServices::FORM526,
          BackendServices::USER_PROFILE,
          BackendServices::RX,
          BackendServices::MESSAGING,
          BackendServices::HEALTH_RECORDS,
          # BackendServices::MHV_AC, this will be false if mhv account is premium
          BackendServices::FORM_PREFILL,
          BackendServices::SAVE_IN_PROGRESS,
          BackendServices::APPEALS_STATUS,
          BackendServices::IDENTITY_PROOFED,
          BackendServices::VET360
        ].sort
      )
    end

    context 'with an error from a 503 raised by Vet360::ContactInformation::Service#get_person', skip_vet360: true do
      before do
        exception  = 'the server responded with status 503'
        error_body = { 'status' => 'some service unavailable status' }
        allow_any_instance_of(Vet360::Service).to receive(:perform).and_raise(
          Common::Client::Errors::ClientError.new(exception, 503, error_body)
        )
        get v0_user_url, params: nil
      end

      let(:body) { JSON.parse(response.body) }

      it 'returns a status of 296' do
        expect(response.status).to eq(296)
      end

      it 'sets the vet360_contact_information to nil' do
        expect(body.dig('data', 'attributes', 'vet360_contact_information')).to be_nil
      end

      it 'returns meta.errors information', :aggregate_failures do
        error = body.dig('meta', 'errors').first

        expect(error['external_service']).to eq 'Vet360'
        expect(error['description']).to be_present
        expect(error['status']).to eq 502
      end
    end
  end

  context 'GET /v0/user - when an LOA 1 user is logged in', :skip_mvi do
    before(:each) do
      sign_in_as(new_user(:loa1))
      get v0_user_url, params: nil
    end

    it 'returns proper json' do
      expect(response).to match_response_schema('user_loa1')
    end

    it 'returns a status of 296 with errors', :aggregate_failures do
      body  = JSON.parse(response.body)
      error = body.dig('meta', 'errors').first

      expect(response.status).to eq 296
      expect(error['external_service']).to eq 'MVI'
      expect(error['description']).to be_present
      expect(error['status']).to eq 401
    end

    it 'gives me the list of available services' do
      expect(JSON.parse(response.body)['data']['attributes']['services'].sort).to eq(
        [
          BackendServices::FACILITIES,
          BackendServices::HCA,
          BackendServices::EDUCATION_BENEFITS,
          BackendServices::USER_PROFILE,
          BackendServices::SAVE_IN_PROGRESS,
          BackendServices::FORM_PREFILL
        ].sort
      )
    end
  end

  context 'GET /v0/user - MVI Integration', :skip_mvi do
    before(:each) do
      sign_in_as(new_user(:loa3))
    end

    it 'MVI error should only make a request to MVI one time per request!', :aggregate_failures do
      stub_mvi_failure
      expect { get v0_user_url, params: nil }
        .to trigger_statsd_increment('api.external_http_request.MVI.failed', times: 1, value: 1)
        .and not_trigger_statsd_increment('api.external_http_request.MVI.skipped')
        .and not_trigger_statsd_increment('api.external_http_request.MVI.success')

      body  = JSON.parse(response.body)
      error = body.dig('meta', 'errors').first

      expect(body['data']['attributes']['va_profile']).to be_nil
      expect(response.status).to eq 296
      expect(error['external_service']).to eq 'MVI'
      expect(error['description']).to be_present
      expect(error['status']).to eq 504
    end

    it 'MVI RecordNotFound should only make a request to MVI one time per request!', :aggregate_failures do
      stub_mvi_record_not_found
      expect { get v0_user_url, params: nil }
        .to trigger_statsd_increment('api.external_http_request.MVI.success', times: 1, value: 1)
        .and not_trigger_statsd_increment('api.external_http_request.MVI.skipped')
        .and not_trigger_statsd_increment('api.external_http_request.MVI.failed')

      body  = JSON.parse(response.body)
      error = body.dig('meta', 'errors').first

      expect(body['data']['attributes']['va_profile']).to be_nil
      expect(response.status).to eq 296
      expect(error['external_service']).to eq 'MVI'
      expect(error['description']).to be_present
      expect(error['status']).to eq 404
    end

    it 'MVI DuplicateRecords should only make a request to MVI one time per request!', :aggregate_failures do
      stub_mvi_duplicate_record
      expect { get v0_user_url, params: nil }
        .to trigger_statsd_increment('api.external_http_request.MVI.success', times: 1, value: 1)
        .and not_trigger_statsd_increment('api.external_http_request.MVI.skipped')
        .and not_trigger_statsd_increment('api.external_http_request.MVI.failed')

      body  = JSON.parse(response.body)
      error = body.dig('meta', 'errors').first

      expect(body['data']['attributes']['va_profile']).to be_nil
      expect(response.status).to eq 296
      expect(error['external_service']).to eq 'MVI'
      expect(error['description']).to be_present
      expect(error['status']).to eq 404
    end

    it 'MVI success should only make a request to MVI one time per multiple requests!' do
      stub_mvi_success
      expect_any_instance_of(Common::Client::Base).to receive(:perform).once.and_call_original
      expect { get v0_user_url, params: nil }
        .to trigger_statsd_increment('api.external_http_request.MVI.success', times: 1, value: 1)
      expect { get v0_user_url, params: nil }
        .not_to trigger_statsd_increment('api.external_http_request.MVI.success', times: 1, value: 1)
      expect { get v0_user_url, params: nil }
        .not_to trigger_statsd_increment('api.external_http_request.MVI.success', times: 1, value: 1)
    end

    it 'MVI raises a breakers exception after 50% failure rate', :aggregate_failures do
      now = Time.current
      start_time = now - 120
      Timecop.freeze(start_time)
      # Starts out successful
      stub_mvi_success
      sign_in_as(new_user)
      expect { get v0_user_url, params: nil }
        .to trigger_statsd_increment('api.external_http_request.MVI.success', times: 1, value: 1)
        .and not_trigger_statsd_increment('api.external_http_request.MVI.failed')
        .and not_trigger_statsd_increment('api.external_http_request.MVI.skipped')

      # Encounters failure and breakers kicks in
      stub_mvi_failure
      1.times do |_count|
        sign_in_as(new_user)
        expect { get v0_user_url, params: nil }
          .to trigger_statsd_increment('api.external_http_request.MVI.failed', times: 1, value: 1)
          .and not_trigger_statsd_increment('api.external_http_request.MVI.skipped')
          .and not_trigger_statsd_increment('api.external_http_request.MVI.success')
      end
      expect(MVI::Configuration.instance.breakers_service.latest_outage.start_time.to_i).to eq(start_time.to_i)

      # skipped because breakers is active
      stub_mvi_success
      sign_in_as(new_user)
      expect { get v0_user_url, params: nil }
        .to trigger_statsd_increment('api.external_http_request.MVI.skipped', times: 1, value: 1)
        .and not_trigger_statsd_increment('api.external_http_request.MVI.failed')
        .and not_trigger_statsd_increment('api.external_http_request.MVI.success')
      expect(MVI::Configuration.instance.breakers_service.latest_outage.ended?).to eq(false)
      Timecop.freeze(now)
      # sufficient time has elasped that new requests are made, resulting in succses
      sign_in_as(new_user)
      expect { get v0_user_url, params: nil }
        .to trigger_statsd_increment('api.external_http_request.MVI.success', times: 1, value: 1)
        .and not_trigger_statsd_increment('api.external_http_request.MVI.skipped')
        .and not_trigger_statsd_increment('api.external_http_request.MVI.failed')
      expect(response.status).to eq(200)
      expect(MVI::Configuration.instance.breakers_service.latest_outage.ended?).to eq(true)
    end
  end

  def new_user(type = :loa3)
    user = build(:user, type, uuid: rand(1000..100_000))
    create(:account, idme_uuid: user.uuid)
    user
  end

  def stub_mvi_failure
    stub_mvi_external_request File.read('spec/support/mvi/find_candidate_soap_fault.xml')
  end

  def stub_mvi_record_not_found
    stub_mvi_external_request File.read('spec/support/mvi/find_candidate_no_subject.xml')
  end

  def stub_mvi_duplicate_record
    stub_mvi_external_request File.read('spec/support/mvi/find_candidate_multiple_match_response.xml')
  end

  def stub_mvi_success
    stub_mvi_external_request File.read('spec/support/mvi/find_candidate_response.xml')
  end

  def stub_mvi_external_request(file)
    stub_request(:post, Settings.mvi.url)
      .to_return(status: 200, headers: { 'Content-Type' => 'text/xml' }, body: file)
  end
end
