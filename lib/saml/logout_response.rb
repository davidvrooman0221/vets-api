# frozen_string_literal: true

module SAML
  class LogoutResponse < OneLogin::RubySaml::Logoutresponse
    ERRORS = { auth_too_late:  { code: 'L002',
                                 tag: :auth_too_late,
                                 short_message: 'Current time is on or after NotOnOrAfter condition',
                                 level: :warn },
               auth_too_early: { code: 'L003',
                                 tag: :auth_too_early,
                                 short_message: 'Current time is earlier than NotBefore condition',
                                 level: :error },
               blank:           { code: 'L007',
                                  tag: :blank,
                                  short_message: 'Blank response',
                                  level: :error },
               unknown:         { code: 'L007',
                                  tag: :unknown,
                                  short_message: 'Other SAML Response Error(s)',
                                  level: :error } }.freeze

    def normalized_errors
      @normalized_errors ||= []
    end

    def valid?
      @normalized_errors = []
      # passing true collects all validation errors
      is_valid_result = is_valid?(true)
      errors.each do |error_message|
        normalized_errors << map_message_to_error(error_message).merge(full_message: error_message)
      end
      is_valid_result
    end

    def map_message_to_error(error_message)
      ERRORS.each_key do |key|
        return ERRORS[key] if error_message.include?(ERRORS[key][:short_message])
      end
      ERRORS[:unknown]
    end

    def authn_context_text
      REXML::XPath.first(decrypted_document, '//saml:AuthnContextClassRef')&.text
    end

    def authn_context
      if decrypted_document
        authn_context_text || SAML::User::UNKNOWN_AUTHN_CONTEXT
      else
        SAML::User::UNKNOWN_AUTHN_CONTEXT
      end
    end
  end
end
