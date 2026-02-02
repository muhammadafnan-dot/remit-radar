class RatesService
  def initialize(currency)
    @currency = currency.upcase
  end

  def call
    rates = RemitRate.by_currency(@currency).best_rates
    return { error: "No rates found for #{@currency}" } if rates.empty?
    {
      success: true,
      data: build_response(rates)
    }
  end

  private
  def build_response(rates)
    {
      currency: @currency,
      timestamp: Time.current.iso8601,
      summary: {
        total_providers: rates.count,
        average_rate: rates.average(:rate).round(4),
        median_rate: calculate_median(rates)
      },
      best_rate: rate_details(rates.first),
      worst_rate: rate_details(rates.last),
      all_rates: rates.map { |r| rate_details(r) }
    }
  end
  def calculate_median(rates)
    sorted = rates.pluck(:rate).sort
    mid = sorted.length / 2
    sorted.length.odd? ? sorted[mid] : ((sorted[mid - 1] + sorted[mid]) / 2.0).round(4)
  end
  def rate_details(rate)
    {
      provider: rate.provider,
      rate: rate.rate,
      display: rate.rate_display,
    }
  end
end