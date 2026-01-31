# Remit Radar Frontend

A Next.js single-page application that displays remittance exchange rates from the Rails API backend.

## Features

- 📊 Display exchange rates in a clean, modern table
- 🔄 Refresh rates on demand
- ⚡ Real-time data fetching from Rails API
- 🎨 Beautiful UI with Tailwind CSS
- 📱 Responsive design

## Getting Started

### Prerequisites

- Node.js 18+ installed
- Rails backend running on `http://localhost:3000` (or configure via environment variable)

### Installation

1. Install dependencies:
```bash
npm install
```

2. Configure API URL (optional):
   - Create a `.env.local` file in the frontend directory
   - Add: `NEXT_PUBLIC_API_URL=http://localhost:3000`
   - Default is `http://localhost:3000` if not set

3. Run the development server:
```bash
npm run dev
```

4. Open [http://localhost:6001](http://localhost:6001) in your browser

## Backend Setup

Make sure your Rails backend:
1. Has CORS enabled (already configured in `config/initializers/cors.rb`)
2. Has `rack-cors` gem installed (run `bundle install` in the backend directory)
3. Is running on port 3000 (or update `NEXT_PUBLIC_API_URL` accordingly)

## Project Structure

```
frontend/
├── app/
│   ├── layout.tsx      # Root layout
│   ├── page.tsx         # Main page component (rates list)
│   └── globals.css     # Global styles
├── lib/
│   └── api.ts          # API utility functions
├── types/
│   └── rate.ts         # TypeScript types for Rate
└── package.json
```

## API Endpoint

The frontend fetches rates from:
- `GET /api/v1/rates`

This endpoint returns an array of rate objects with the following structure:
```typescript
{
  id: number;
  provider: string;
  rate: number;
  currency: string;
  rate_display: string;
  rate_formatted: string;
  created_at: string;
  updated_at: string;
}
```

## Build for Production

```bash
npm run build
npm start
```

## Technologies Used

- **Next.js 16** - React framework
- **TypeScript** - Type safety
- **Tailwind CSS** - Styling
- **React 19** - UI library
