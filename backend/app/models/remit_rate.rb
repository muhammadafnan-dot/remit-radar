class RemitRate < ApplicationRecord

    SUPPORTED_CURRENCIES = %w[PKR INR BDT PHP NPR LKR].freeze
    validates :provider, presence: true, length: { minimum: 2, maximum: 100 }
    validates :rate, presence: true, numericality: { greater_than: 0 }
    validates :currency, presence: true, inclusion: { in: SUPPORTED_CURRENCIES, message: "%{value} is not a supported currency" }
    validates :provider, uniqueness: { scope: :currency, case_sensitive: false, message: "already has a rate for this currency" }

    scope :by_currency, ->(currency) { where(currency: currency.upcase) }
    scope :by_provider, ->(provider) { where(provider: provider) }
    scope :best_rates, -> { order(rate: :desc) }
    scope :recent, -> { where("created_at > ?", 24.hours.ago) }
    scope :active, -> { where("updated_at > ?", 7.days.ago) }

    before_validation :normalize_provider_name
    before_save :round_rate

    def self.best_rate_for(currency)
        by_currency(currency).best_rates.first
    end
    def self.average_rate_for(currency)
        by_currency(currency).average(:rate)&.round(4)
    end

    def rate_display
        "#{format('%.4f', rate)} #{currency}"
    end
    private
    def normalize_provider_name
        self.provider = provider.strip.titleize if provider.present?
        self.currency = currency.upcase if currency.present?
    end
    def round_rate
        self.rate = rate.round(4) if rate.present?
    end
end
