import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { defineConfig } from 'vite';

const workspaceRoot = dirname(fileURLToPath(import.meta.url));
const applicationRoot = resolve(workspaceRoot, 'Website');

export default defineConfig({
  root: applicationRoot,
  envDir: workspaceRoot,
  server: {
    host: '127.0.0.1'
  },
  build: {
    outDir: resolve(workspaceRoot, 'dist'),
    emptyOutDir: true,
    rollupOptions: {
      input: {
        root: resolve(applicationRoot, 'index.html'),
        homepage: resolve(applicationRoot, 'Homepage/index.html'),
        login: resolve(applicationRoot, 'Login/Login.html'),
        dashboard: resolve(applicationRoot, 'Dashboard/Dashboard.html')
      }
    }
  }
});
