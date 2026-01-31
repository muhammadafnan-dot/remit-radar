module V1
  module ErrorHandler
    extend ActiveSupport::Concern

    included do
      rescue_from ActiveRecord::RecordNotFound do |e|
        error!({ error: 'Resource not found', details: e.message }, 404)
      end

      rescue_from ActiveRecord::RecordInvalid do |e|
        error!({ error: 'Validation failed', details: e.record.errors.full_messages }, 422)
      end

      rescue_from Grape::Exceptions::ValidationErrors do |e|
        error!({ error: 'Invalid parameters', details: e.full_messages }, 400)
      end

      rescue_from :all do |e|
        Rails.logger.error("API Error: #{e.message}\n#{e.backtrace.join("\n")}")

        if Rails.env.development?
          error!({ error: e.message, backtrace: e.backtrace.first(5) }, 500)
        else
          error!({ error: 'Internal server error' }, 500)
        end
      end
    end
  end
end