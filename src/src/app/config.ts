// Versión de la aplicación y hotfixes aplicados
export const APP_CONFIG = {
  version: '1.0.0',
  environment: process.env.NODE_ENV || 'development',
  hotfixes: [
    // Los hotfixes se agregarán aquí durante el proceso de cascade
  ],
} as const;

export type AppConfig = typeof APP_CONFIG;
