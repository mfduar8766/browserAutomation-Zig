pub const Options = struct {
    chromeDriverExecPath: ?[]const u8 = undefined,
    chromeDriverPort: ?i32 = undefined,
    chromeDriverVersion: ?[]const u8 = undefined,
    args: ?[][]const u8 = undefined,
};

/// ChromeDriver response to /sessions API request
pub const Session = struct {
    value: struct {
        capabilities: Capabilities,
        sessionId: []const u8,
    },
};

/// ChromeDriver response to /sessions API call
const Capabilities = struct {
    acceptInsecureCerts: bool,
    browserName: []const u8,
    browserVersion: []const u8,
    chrome: Chrome,
    @"fedcm:accounts": bool,
    @"goog:chromeOptions": GooglChromeOptions,
    networkConnectionEnabled: bool,
    pageLoadStrategy: []const u8,
    platformName: []const u8,
    proxy: Proxy,
    setWindowRect: bool,
    strictFileInteractability: bool,
    timeouts: Timeouts,
    unhandledPromptBehavior: []const u8,
    @"webauthn:extension:credBlob": bool,
    @"webauthn:extension:largeBlob": bool,
    @"webauthn:extension:minPinLength": bool,
    @"webauthn:extension:prf": bool,
    @"webauthn:virtualAuthenticators": bool,
};

/// ChromeDriver response to /sessions API call
const Chrome = struct {
    chromedriverVersion: []const u8,
    userDataDir: []const u8,
};

/// ChromeDriver response to /sessions API call
const GooglChromeOptions = struct {
    debuggerAddress: []const u8,
};

/// ChromeDriver response to /sessions API call
const Proxy = struct {
    // Add fields if needed for proxy
};

/// ChromeDriver response to /sessions API call
const Timeouts = struct {
    implicit: u32,
    pageLoad: u32,
    script: u32,
};

/// ChromeDriver response from /session API request
pub const ChromeDriverSessionResponse = struct {
    value: struct {
        capabilities: struct {
            acceptInsecureCerts: bool,
            browserName: []const u8,
            browserVersion: []const u8,
            chrome: struct {
                chromedriverVersion: []const u8,
                userDataDir: []const u8,
            },
            @"fedcm:accounts": bool,
            @"goog:chromeOptions": struct {
                debuggerAddress: []const u8,
            },
            networkConnectionEnabled: bool,
            pageLoadStrategy: bool,
            platformName: []const u8,
            proxy: struct {},
            setWindowRect: bool,
            strictFileInteractability: bool,
            timeouts: struct {
                implicit: u32,
                pageLoad: u32,
                script: u32,
            },
            unhandledPromptBehavior: []const u8,
            @"webauthn:extension:credBlob": bool,
            @"webauthn:extension:largeBlob": bool,
            @"webauthn:extension:minPinLength": bool,
            @"webauthn:extension:prf": bool,
            @"webauthn:virtualAuthenticators": bool,
        },
    },
    sessionId: []const u8,
};
