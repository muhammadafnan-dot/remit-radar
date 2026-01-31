FactoryBot.define do
  factory :remit_rate do
    provider { Faker::Company.name }
    rate { Faker::Number.decimal(l_digits: 3, r_digits: 4) }
    currency { "PKR" }

    # Named variants (traits)
    trait :wise do
      provider { "Wise" }
      rate { 280.50 }
    end

    trait :remitly do
      provider { "Remitly" }
      rate { 279.75 }
    end

    trait :usd do
      currency { "USD" }
      rate { 1.0 }
    end
  end
end
  