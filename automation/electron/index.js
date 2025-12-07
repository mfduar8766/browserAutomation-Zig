import { app, BrowserWindow, ipcMain } from 'electron';
import path from 'node:path';
import fs from 'fs';
import os from 'os';
import { processArgs } from './utils.js';

app.commandLine.appendSwitch('enable-logging');
const __dirname = path.dirname(new URL(import.meta.url).pathname);
const preloadPath = path.join(__dirname, 'preload.js');
if (!fs.existsSync(preloadPath)) {
  os.exit(1);
}
console.log('🧪 Preload path:', preloadPath);
console.log('🧪 Preload file exists:', fs.existsSync(preloadPath));

function createWindow() {
  const mainWindow = new BrowserWindow({
    width: 800,
    height: 800,
    webPreferences: {
      preload: preloadPath,
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: false,
      webviewTag: true,
      additionalArguments: [`--args=${JSON.stringify(processArgs())}`],
    },
  });

  mainWindow
    .loadFile('index.html')
    .then(() => {
      // Listen for messages from renderer
      ipcMain.on('log-to-main', (_, type, msg) => {
        const matches = {
          log: () => console.log('[Renderer Log]:', msg),
          warn: () => console.warn('[Renderer Warn]:', msg),
          error: () => console.error('[Renderer Error]:', msg),
          info: () => console.info('[Renderer Info]:', msg),
        };
        matches[type];
      });

      ipcMain.on('open-dev-tools', () => {
        mainWindow.webContents.openDevTools({ mode: 'right' });
      });
    })
    .catch((err) => console.error(err));
}

app
  .whenReady()
  .then(createWindow)
  .catch((err) => console.error(err));

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  } else {
    app.quit();
  }
});
