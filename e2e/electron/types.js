/**
 * @typedef {'log' | 'warn' | 'error' | 'info'} TLog
 */

/**
 * @typedef {Object} ElectronRendererProcessInfo
 * @property {string} type - Process type, e.g. "renderer"
 * @property {string} user-data-dir - Path to the user data directory
 * @property {string} app-path - Path to the application
 * @property {string} lang - Language code, e.g. "en-US"
 * @property {string} num-raster-threads - Number of raster threads
 * @property {string} renderer-client-id - Renderer client ID
 * @property {string} time-ticks-at-unix-epoch - Ticks at Unix epoch
 * @property {string} launch-time-ticks - Launch time in ticks
 * @property {string} field-trial-handle - Field trial handle string
 * @property {string} enable-features - Comma-separated enabled features
 * @property {string} disable-features - Comma-separated disabled features
 * @property {string} args - Arguments passed (in your case, it's actually just "[object Object]", so still a string)
 */

/** @typedef {Electron.WebviewTag} Webview */
/** @typedef {HTMLElement | null} HtmlTag */
/** @typedef {string} TString */
/** @typedef {number} TNumber */
/** @typedef {boolean} TBool */
/** @typedef {Object<string, any>} TRecord */
/** @typedef {string[]} TStringList */
/** @typedef {number[]} TNumberList */
/** @typedef {TRecord[]} TRecordList[] */

/** @type {TLog} */
export const TLogNames = 'log';

export {};
