import { Rate } from '@/types/rate';

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3000';

export interface RateFilters {
  currency?: string;
  provider?: string;
}

export async function fetchRates(filters?: RateFilters): Promise<Rate[]> {
  try {
    const params = new URLSearchParams();
    if (filters?.currency) {
      params.append('currency', filters.currency);
    }
    if (filters?.provider) {
      params.append('provider', filters.provider);
    }

    const url = `${API_BASE_URL}/api/v1/rates${params.toString() ? `?${params.toString()}` : ''}`;
    
    const response = await fetch(url, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
      },
    });

    if (!response.ok) {
      throw new Error(`Failed to fetch rates: ${response.statusText}`);
    }

    const data = await response.json();
    return data;
  } catch (error) {
    console.error('Error fetching rates:', error);
    throw error;
  }
}
