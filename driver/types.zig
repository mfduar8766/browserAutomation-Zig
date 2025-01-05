pub const Options = struct {
    chromeDriverExecPath: ?[]const u8 = undefined,
    chromeDriverPort: ?i32 = undefined,
    chromeDriverVersion: ?[]const u8 = undefined,
    args: ?[][]const u8 = undefined,
};

pub const ChromeDriverSessionResponse = struct {
    value: Value,
};

const Value = struct {
    capabilities: Capabilities,
    sessionId: []u8,
};

const Capabilities = struct {
    acceptInsecureCerts: bool,
    browserName: []u8,
    browserVersion: []u8,
    chrome: Chrome,
    // fedcm:accounts: bool,
    // goog:chromeOptions: GoogChromeOptions,
    networkConnectionEnabled: bool,
    pageLoadStrategy: []u8,
    platformName: []u8,
    proxy: Proxy,
    setWindowRect: bool,
    strictFileInteractability: bool,
    timeouts: Timeouts,
    unhandledPromptBehavior: []u8,
    // webauthn:extension:credBlob: bool,
    // webauthn:extension:largeBlob: bool,
    // webauthn:extension:minPinLength: bool,
    // webauthn:extension:prf: bool,
    // webauthn:virtualAuthenticators: bool,
};

const Chrome = struct {
    chromedriverVersion: []u8,
    userDataDir: []u8,
};

// const GoogChromeOptions = struct {
// 	debuggerAddress: []u8,
// };

const Proxy = struct {};

const Timeouts = struct {
    implicit: i32,
    pageLoad: i32,
    script: i32,
};
