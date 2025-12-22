/**
 * @typedef {import('./types.js').TLog} TLog
 * @typedef {import('./types.js').ElectronRendererProcessInfo} ElectronRendererProcessInfo
 * @typedef {import('./types.js').Webview} Webview
 * @typedef {import('./types.js').HtmlTag} HtmlTag
 * @typedef {import('./types.js').TString} TString
 */

/** @type {Webview} */
const webviewTag = document.getElementById('myWebview');
/** @type {HtmlTag} */
const goBackBtn = document.getElementById('goBack');
/** @type {HtmlTag} */
const goForwardBtn = document.getElementById('goForward');
/** @type {HtmlTag} */
const reloadBtn = document.getElementById('reload');
/** @type {Window} */
const WINDOW = window;

console.log('[Renderer] - script loaded');

document.addEventListener('click', () => {
  WINDOW.api.log('log', 'CLICKEDDDDDDDD');
  WINDOW.api.openDevTools();
});

webviewTag.addEventListener('did-finish-load', () => {
  WINDOW.api.log('log', `✅ Webview loaded: webview.getURL()`);
});

webviewTag.addEventListener('did-fail-load', (e) => {
  WINDOW.api.log('error', `❌ Webview failed to load ${e}`);
});

document.addEventListener('DOMContentLoaded', () => {
  /** @type {ElectronRendererProcessInfo} */
  const parsedArgs = WINDOW.api.args;
  const url = JSON.parse(parsedArgs.args).url;
  if (url.length) {
    console.log('Launched with URL:', url);
    webviewTag.src = url;
  }
});

goBackBtn.addEventListener('click', () => {
  if (webviewTag.canGoBack()) {
    webviewTag.goBack(); // Go back in the webview history
  } else {
    alert('No more history to go back to.');
  }
});

goForwardBtn.addEventListener('click', () => {
  webviewTag.goForward();
});

reloadBtn.addEventListener('click', () => {
  webviewTag.reload();
});
