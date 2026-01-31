module V1
    module Entities
        class Rate < Grape::Entity
            expose :id, documentation: { type: Integer, desc: 'Rate ID' }
            expose :provider, documentation: { type: String, desc: 'Provider name' }
            expose :rate, documentation: { type: Float, desc: 'Exchange rate' }
            expose :currency, documentation: { type: String, desc: 'Target currency' }
            expose :rate_display, documentation: { type: String, desc: 'Formatted rate display' }
            expose :created_at, documentation: { type: DateTime, desc: 'Creation timestamp' }
            expose :updated_at, documentation: { type: DateTime, desc: 'Last update timestamp' }
            expose :rate_formatted do |rate, options|
                rate.rate_display
            end
        end
    end
end