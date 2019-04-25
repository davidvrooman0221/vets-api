# frozen_string_literal: true

module Veteran
  module V0
    class RepresentativesController < ApplicationController
      skip_before_action :set_tags_and_extra_content, raise: false
      skip_before_action :authenticate

      def search
        rep = Veteran::Service::Representative.for_user(first_name: params[:first_name], last_name: params[:last_name])
        if rep.present?
          render json: rep,
                 serializer: Veteran::Service::RepresentativeSerializer
        else
          render json: { errors: [{ detail: 'Representative not found' }] }
        end
      end
    end
  end
end
