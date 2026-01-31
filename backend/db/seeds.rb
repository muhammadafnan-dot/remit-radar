# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

RemitRate.destroy_all
puts "Seeding RemitRates..."

providers = [
  { name: 'Wise', rates: { 'PKR' => 280.50, 'INR' => 83.25, 'BDT' => 110.50 } },
  { name: 'Remitly', rates: { 'PKR' => 279.75, 'INR' => 83.00, 'BDT' => 109.75 } },
  { name: 'Western Union', rates: { 'PKR' => 278.25, 'INR' => 82.50, 'BDT' => 108.25 } },
  { name: 'MoneyGram', rates: { 'PKR' => 277.50, 'INR' => 82.25, 'BDT' => 107.50 } },
  { name: 'Xoom', rates: { 'PKR' => 279.00, 'INR' => 82.75, 'BDT' => 109.00 } }
]

providers.each do |provider|
  provider[:rates].each do |currency, rate|
    RemitRate.create!(
      provider: provider[:name],
      rate: rate,
      currency: currency
    )
  end
end

puts "Created #{RemitRate.count} rates for #{providers.length} providers"