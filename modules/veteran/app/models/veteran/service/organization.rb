# frozen_string_literal: true

module Veteran
  # Not technically a Service Object, this is a term used by the VA internally.
  module Service
    class Organization < ActiveRecord::Base
      self.primary_key = :poa

      def self.reload!
        csv = fetch_page('repexcellist.asp')
      end
    end
  end
end
