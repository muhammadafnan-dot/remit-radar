'use client';

import { useEffect, useState, useMemo, useRef } from 'react';
import { Rate } from '@/types/rate';
import { fetchRates, RateFilters } from '@/lib/api';

const SUPPORTED_CURRENCIES = ['PKR', 'INR', 'BDT', 'PHP', 'NPR', 'LKR'];

export default function Home() {
  const [rates, setRates] = useState<Rate[]>([]);
  const [allRates, setAllRates] = useState<Rate[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [filters, setFilters] = useState<RateFilters>({});
  const [currencyInput, setCurrencyInput] = useState('');
  const [providerInput, setProviderInput] = useState('');
  const [showCurrencyDropdown, setShowCurrencyDropdown] = useState(false);
  const [showProviderDropdown, setShowProviderDropdown] = useState(false);
  
  const currencyRef = useRef<HTMLDivElement>(null);
  const providerRef = useRef<HTMLDivElement>(null);

  // Extract unique providers from all rates
  const uniqueProviders = useMemo(() => {
    const providers = new Set<string>();
    allRates.forEach(rate => providers.add(rate.provider));
    return Array.from(providers).sort();
  }, [allRates]);

  // Filter currencies and providers based on input
  const filteredCurrencies = useMemo(() => {
    if (!currencyInput) return SUPPORTED_CURRENCIES;
    return SUPPORTED_CURRENCIES.filter(currency =>
      currency.toLowerCase().includes(currencyInput.toLowerCase())
    );
  }, [currencyInput]);

  const filteredProviders = useMemo(() => {
    if (!providerInput) return uniqueProviders;
    return uniqueProviders.filter(provider =>
      provider.toLowerCase().includes(providerInput.toLowerCase())
    );
  }, [providerInput, uniqueProviders]);

  // Click outside handler
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (currencyRef.current && !currencyRef.current.contains(event.target as Node)) {
        setShowCurrencyDropdown(false);
      }
      if (providerRef.current && !providerRef.current.contains(event.target as Node)) {
        setShowProviderDropdown(false);
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, []);

  useEffect(() => {
    loadAllRates();
  }, []);

  useEffect(() => {
    loadRates(filters);
  }, [filters]);

  const loadAllRates = async () => {
    try {
      const data = await fetchRates();
      setAllRates(data);
    } catch (err) {
      // Silently fail for initial load, will show error when filters are applied
    }
  };

  const loadRates = async (currentFilters?: RateFilters) => {
    try {
      setLoading(true);
      setError(null);
      const data = await fetchRates(currentFilters || filters);
      setRates(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load rates');
    } finally {
      setLoading(false);
    }
  };

  const handleCurrencySelect = (currency: string) => {
    setCurrencyInput(currency);
    setShowCurrencyDropdown(false);
    setFilters(prev => ({ ...prev, currency }));
  };

  const handleProviderSelect = (provider: string) => {
    setProviderInput(provider);
    setShowProviderDropdown(false);
    setFilters(prev => ({ ...prev, provider }));
  };

  const clearFilters = () => {
    setFilters({});
    setCurrencyInput('');
    setProviderInput('');
  };

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  const hasActiveFilters = filters.currency || filters.provider;

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 py-8 px-4">
      <div className="max-w-7xl mx-auto">
        <div className="bg-white rounded-lg shadow-xl p-8">
          <div className="mb-8">
            <h1 className="text-4xl font-bold text-gray-900 mb-2">
              Remit Rates
            </h1>
            <p className="text-gray-600">
              Current exchange rates from various providers
            </p>
          </div>

          {/* Filters Section */}
          <div className="mb-6 grid grid-cols-1 md:grid-cols-2 gap-4">
            {/* Currency Filter */}
            <div className="relative" ref={currencyRef}>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Currency
              </label>
              <div className="relative">
                <input
                  type="text"
                  value={currencyInput}
                  onChange={(e) => {
                    setCurrencyInput(e.target.value);
                    setShowCurrencyDropdown(true);
                  }}
                  onFocus={() => setShowCurrencyDropdown(true)}
                  placeholder="Search currency..."
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                />
                {filters.currency && (
                  <button
                    onClick={() => {
                      setCurrencyInput('');
                      setFilters(prev => {
                        const newFilters = { ...prev };
                        delete newFilters.currency;
                        return newFilters;
                      });
                    }}
                    className="absolute right-2 top-2 text-gray-400 hover:text-gray-600"
                    aria-label="Clear currency filter"
                  >
                    ✕
                  </button>
                )}
                {showCurrencyDropdown && filteredCurrencies.length > 0 && (
                  <div className="absolute z-10 w-full mt-1 bg-white border border-gray-300 rounded-lg shadow-lg max-h-60 overflow-auto">
                    {filteredCurrencies.map((currency) => (
                      <button
                        key={currency}
                        onClick={() => handleCurrencySelect(currency)}
                        className="w-full text-left px-4 py-2 hover:bg-indigo-50 focus:bg-indigo-50 focus:outline-none"
                      >
                        {currency}
                      </button>
                    ))}
                  </div>
                )}
              </div>
            </div>

            {/* Provider Filter */}
            <div className="relative" ref={providerRef}>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Provider
              </label>
              <div className="relative">
                <input
                  type="text"
                  value={providerInput}
                  onChange={(e) => {
                    setProviderInput(e.target.value);
                    setShowProviderDropdown(true);
                  }}
                  onFocus={() => setShowProviderDropdown(true)}
                  placeholder="Search provider..."
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                />
                {filters.provider && (
                  <button
                    onClick={() => {
                      setProviderInput('');
                      setFilters(prev => {
                        const newFilters = { ...prev };
                        delete newFilters.provider;
                        return newFilters;
                      });
                    }}
                    className="absolute right-2 top-2 text-gray-400 hover:text-gray-600"
                    aria-label="Clear provider filter"
                  >
                    ✕
                  </button>
                )}
                {showProviderDropdown && filteredProviders.length > 0 && (
                  <div className="absolute z-10 w-full mt-1 bg-white border border-gray-300 rounded-lg shadow-lg max-h-60 overflow-auto">
                    {filteredProviders.map((provider) => (
                      <button
                        key={provider}
                        onClick={() => handleProviderSelect(provider)}
                        className="w-full text-left px-4 py-2 hover:bg-indigo-50 focus:bg-indigo-50 focus:outline-none"
                      >
                        {provider}
                      </button>
                    ))}
                  </div>
                )}
              </div>
            </div>
          </div>

          {/* Clear Filters Button */}
          {hasActiveFilters && (
            <div className="mb-4">
              <button
                onClick={clearFilters}
                className="text-sm text-indigo-600 hover:text-indigo-800 underline"
              >
                Clear all filters
              </button>
            </div>
          )}

          {loading && (
            <div className="flex items-center justify-center py-12">
              <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600"></div>
            </div>
          )}

          {error && (
            <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded mb-6">
              <p className="font-semibold">Error loading rates</p>
              <p className="text-sm">{error}</p>
              <button
                onClick={() => loadRates()}
                className="mt-2 px-4 py-2 bg-red-600 text-white rounded hover:bg-red-700 transition-colors"
              >
                Retry
              </button>
            </div>
          )}

          {!loading && !error && rates.length === 0 && (
            <div className="text-center py-12 text-gray-500">
              <p className="text-lg">No rates found</p>
              {hasActiveFilters && (
                <p className="text-sm mt-2">Try adjusting your filters</p>
              )}
            </div>
          )}

          {!loading && !error && rates.length > 0 && (
            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-gray-200">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Provider
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Currency
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Formatted Rate
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Updated
                    </th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-200">
                  {rates.map((rate) => (
                    <tr
                      key={rate.id}
                      className="hover:bg-gray-50 transition-colors"
                    >
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="text-sm font-medium text-gray-900">
                          {rate.provider}
                        </div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <span className="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-indigo-100 text-indigo-800">
                          {rate.currency}
                        </span>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="text-sm font-semibold text-indigo-600">
                          {rate.rate_formatted}
                        </div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                        {formatDate(rate.updated_at)}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}

          {!loading && !error && rates.length > 0 && (
            <div className="mt-6 flex justify-between items-center text-sm text-gray-500">
              <p>Total rates: {rates.length}</p>
              <button
                onClick={() => loadRates()}
                className="px-4 py-2 bg-indigo-600 text-white rounded hover:bg-indigo-700 transition-colors"
              >
                Refresh
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
