module V1
    module Helpers
        module LoggingHelper
            def log_request
                Rails.logger.info("API Request: #{request.request_method} #{request.path}")
                Rails.logger.info("Params: #{params.to_h.except('route_info').to_json}")
            end
        end
    end
end