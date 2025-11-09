/* Optional AppDynamics init. Safe no-op if not enabled or package missing.
   To enable, set APPD_ENABLED=true and define standard AppDynamics vars:
   - APPD_APP_NAME, APPD_TIER_NAME, APPD_NODE_NAME
   - APPD_CONTROLLER_HOST, APPD_CONTROLLER_PORT, APPD_ACCOUNT_NAME, APPD_ACCESS_KEY, APPD_SSL_ENABLED (true/false)
*/
/* global require */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
declare const process: any;
// eslint-disable-next-line @typescript-eslint/no-explicit-any
declare const require: any;

function tryInitAppD() {
  if (process.env.APPD_ENABLED !== 'true') return;
  try {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const appd = require('appdynamics');
    appd.profile({
      controllerHostName: process.env.APPD_CONTROLLER_HOST,
      controllerPort: Number(process.env.APPD_CONTROLLER_PORT || 443),
      controllerSslEnabled: String(process.env.APPD_SSL_ENABLED || 'true') === 'true',
      accountName: process.env.APPD_ACCOUNT_NAME,
      accountAccessKey: process.env.APPD_ACCESS_KEY,
      applicationName: process.env.APPD_APP_NAME || 'case-app',
      tierName: process.env.APPD_TIER_NAME || 'backend',
      nodeName: process.env.APPD_NODE_NAME || `node-${Math.random().toString(16).slice(2)}`,
    });
    // Optionally add custom match rules here
    // console.log('AppDynamics initialized');
  } catch (_e) {
    // Package not installed or misconfigured; ignore silently to not break runtime
  }
}

tryInitAppD();
export {};
