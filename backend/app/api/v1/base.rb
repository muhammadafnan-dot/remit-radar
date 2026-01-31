module V1
    class Base < Grape::API
        version 'v1', using: :path
        include V1::ErrorHandler
        helpers Helpers::LoggingHelper

        before do
            log_request
        end
        format :json
        require_relative 'rates'

        mount V1::Rates
    end
end