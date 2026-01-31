require 'rails_helper'

RSpec.describe RemitRate, type: :model do
    subject { create(:remit_rate, provider: 'Wise', currency: 'USD', rate: 280.0) }
    describe 'validations' do
        it { should validate_presence_of(:provider) }
        it { should validate_presence_of(:rate) }
        it { should validate_presence_of(:currency) }
        it { should validate_numericality_of(:rate).is_greater_than(0) }
        it { should validate_uniqueness_of(:provider).scoped_to(:currency).with_message("already has a rate for this currency") }
    end

    describe 'scopes' do
      let!(:rate1) { create(:remit_rate, provider: 'Wise', currency: 'USD', rate: 280.0) }
      let!(:rate2) { create(:remit_rate, provider: 'Remitly', currency: 'USD', rate: 285.0) }
      let!(:rate3) { create(:remit_rate, provider: 'Wise', currency: 'PKR', rate: 290.0) }
    
      it 'has scope :by_currency that filters by currency' do
        expect(RemitRate.by_currency('USD')).to contain_exactly(rate1, rate2)
      end
    
      it 'has scope :by_provider that filters by provider' do
        expect(RemitRate.by_provider('Wise')).to contain_exactly(rate1, rate3)
      end
    
      it 'has scope :best_rates that orders by rate descending' do
        expect(RemitRate.best_rates.to_a).to eq([rate3, rate2, rate1])
      end
    end

    describe 'instance methods' do
        it { should respond_to(:rate_display) }
    end
    describe 'creation' do
        it 'creates a valid rate with all attributes' do
            rate = create(:remit_rate, provider: 'Wise', rate: 280.50, currency: 'PKR')
            expect(rate).to be_valid
            expect(rate.save).to be true
        end
        it 'fails without provider' do
            rate = build(:remit_rate, provider: nil)
            expect(rate).not_to be_valid
        end
    end
end