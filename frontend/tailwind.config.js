/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx}"],
  theme: {
    extend: {
      colors: {
        snowflake: {
          50: '#eff6ff',
          100: '#dbeafe',
          500: '#29B5E8',
          600: '#1a9fd4',
          700: '#0f8fc0',
        }
      }
    },
  },
  plugins: [],
}
