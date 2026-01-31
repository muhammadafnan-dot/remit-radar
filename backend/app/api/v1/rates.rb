module V1
    class Rates < Grape::API

        helpers do
            def validate_currency!(currency)
                unless RemitRate::SUPPORTED_CURRENCIES.include?(currency.upcase)
                    error!({ error: 'Invalid currency', supported: RemitRate::SUPPORTED_CURRENCIES }, 400)
                end
            end
        end
        resource :rates do
            desc 'Get all rates'
            params do
                optional :currency, type: String, desc: 'Filter by currency'
                optional :provider, type: String, desc: 'Filter by provider'
            end
            get do
                rates = RemitRate.all
                rates = rates.by_currency(params[:currency]) if params[:currency].present?
                rates = rates.by_provider(params[:provider]) if params[:provider].present?
                
                present rates.best_rates, with: V1::Entities::Rate
              end
            desc 'Get a specific rate' do
                
            end
            params do
                requires :id, type: Integer, desc: 'Rate ID'
            end
            get ':id' do
                rate = RemitRate.find(params[:id])
                present rate, with: V1::Entities::Rate
            end

            desc 'Create a new rate' do
                
            end
            params do
                requires :provider, type: String, desc: 'Provider name', regexp: /\A[a-zA-Z\s]+\z/, documentation: { example: 'Wise' }
                requires :rate, type: Float, desc: 'Exchange rate', values: ->(v) { v.positive? }, documentation: { example: 280.50 }
                requires :currency, type: String, desc: 'Target currency', values: RemitRate::SUPPORTED_CURRENCIES, documentation: { example: 'PKR' }
            end
            post do
                rate = RemitRate.new(
                    provider: params[:provider],
                    rate: params[:rate],
                    currency: params[:currency]
                )
                if rate.save
                    present rate, with: V1::Entities::Rate
                else
                    error!({ errors: rate.errors.full_messages }, 422)
                end
            end
            desc 'Update a rate' do
                
            end
            params do
                requires :id, type: Integer, desc: 'Rate ID'
                optional :provider, type: String, desc: 'Provider name'
                optional :rate, type: Float, desc: 'Exchange rate'
                optional :currency, type: String, desc: 'Target currency'
            end
            put ':id' do
                rate = RemitRate.find(params[:id])
                update_params = declared(params, include_missing: false).except(:id)
                if rate.update(update_params)
                    present rate, with: V1::Entities::Rate
                else
                    error!({ errors: rate.errors.full_messages }, 422)
                end
            end
            desc 'Delete a rate' do
                
            end
            params do
                requires :id, type: Integer, desc: 'Rate ID'
            end
            delete ':id' do
                rate = RemitRate.find(params[:id])
                rate.destroy
                { message: 'Rate deleted successfully' }
            rescue ActiveRecord::RecordNotFound
                error!({ error: 'Rate not found' }, 404)
            end
            desc 'compare rates for a specific currency'
            params do
                requires :currency, type: String, desc: 'Currency code to compare', values: RemitRate::SUPPORTED_CURRENCIES, documentation: { example: 'PKR' }
            end
            get 'compare/:currency' do
                service = RatesService.new(params[:currency])
                result = service.call
                if result[:success]
                    present result[:data], with: V1::Entities::Rate
                else
                    error!({ error: result[:error] }, 404)
                end
            end
        end
    end
end