import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Enable static export for S3 deployment
  output: 'export',
  
  // Disable image optimization (required for static export)
  images: {
    unoptimized: true
  },
  
  // Add trailing slash for S3 compatibility
  trailingSlash: true,
};

export default nextConfig;
