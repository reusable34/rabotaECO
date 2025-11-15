/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  env: {
    NEXT_PUBLIC_API_URL: process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080',
  },
  async headers() {
    return [
      {
        source: '/:path*',
        headers: [
          {
            key: 'Content-Security-Policy',
            value: "script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval' 'inline-speculation-rules' chrome-extension://*; object-src 'none'; base-uri 'self';",
          },
        ],
      },
    ];
  },
}

module.exports = nextConfig

