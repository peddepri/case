/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_BACKEND_URL: string
  readonly VITE_OTLP_ENDPOINT: string
  readonly MODE: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
