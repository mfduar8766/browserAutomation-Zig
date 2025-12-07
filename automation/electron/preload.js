import { contextBridge, ipcRenderer } from 'electron';
import { processArgs } from './utils.js';

/**
 * @typedef {import('./types.js').TLog} TLog
 */

console.log('[Preload Log]: script loaded');

contextBridge.exposeInMainWorld('api', {
  openDevTools: () => ipcRenderer.send('open-dev-tools'),
  /**
   * @param {TLog} type
   * @param {any} msg
   * @returns {void}
   */
  log: (type, msg) => {
    // Optionally validate msg is string
    if (typeof msg === 'string') {
      ipcRenderer.send('log-to-main', type, msg);
    } else {
      ipcRenderer.send('log-to-main', type, JSON.stringify(msg));
    }
  },
  args: processArgs(),
});
