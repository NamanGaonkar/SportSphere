import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// Load env vars from the repo-root .env so one file configures web + mobile + CLI.
export default defineConfig({
  plugins: [react()],
  envDir: '..',
})
