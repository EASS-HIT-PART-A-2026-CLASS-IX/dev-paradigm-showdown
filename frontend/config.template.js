window.APP_CONFIG = Object.freeze({
  apiBaseUrl: "${FRONTEND_API_BASE_URL}",
  backendLabel: "${FRONTEND_BACKEND_LABEL}",
  defaultBackendKey: "${FRONTEND_DEFAULT_BACKEND_KEY}",
  backendTargets: [
    {
      key: "local",
      label: "${FRONTEND_LOCAL_BACKEND_LABEL}",
      apiBaseUrl: "${FRONTEND_LOCAL_API_BASE_URL}",
    },
    {
      key: "remote",
      label: "${FRONTEND_REMOTE_BACKEND_LABEL}",
      apiBaseUrl: "${FRONTEND_REMOTE_API_BASE_URL}",
    },
  ],
});
