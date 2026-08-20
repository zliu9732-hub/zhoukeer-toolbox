const manifest = {"name":"沉浸式翻译"};
const API_VERSION = 2;
const internalAPIConnection = window.__DECKY_SECRET_INTERNALS_DO_NOT_USE_OR_YOU_WILL_BE_FIRED_deckyLoaderAPIInit;
if (!internalAPIConnection) {
    throw new Error('[@decky/api]: Failed to connect to the loader as as the loader API was not initialized. This is likely a bug in Decky Loader.');
}
let api;
try {
    api = internalAPIConnection.connect(API_VERSION, manifest.name);
}
catch {
    api = internalAPIConnection.connect(1, manifest.name);
    console.warn(`[@decky/api] Requested API version ${API_VERSION} but the running loader only supports version 1. Some features may not work.`);
}
if (api._version != API_VERSION) {
    console.warn(`[@decky/api] Requested API version ${API_VERSION} but the running loader only supports version ${api._version}. Some features may not work.`);
}
const call = api.call;
const routerHook = api.routerHook;
const toaster = api.toaster;
const definePlugin = (fn) => {
    return (...args) => {
        return fn(...args);
    };
};

var DefaultContext = {
  color: undefined,
  size: undefined,
  className: undefined,
  style: undefined,
  attr: undefined
};
var IconContext = SP_REACT.createContext && SP_REACT.createContext(DefaultContext);

var __assign = window && window.__assign || function () {
  __assign = Object.assign || function (t) {
    for (var s, i = 1, n = arguments.length; i < n; i++) {
      s = arguments[i];
      for (var p in s) if (Object.prototype.hasOwnProperty.call(s, p)) t[p] = s[p];
    }
    return t;
  };
  return __assign.apply(this, arguments);
};
var __rest = window && window.__rest || function (s, e) {
  var t = {};
  for (var p in s) if (Object.prototype.hasOwnProperty.call(s, p) && e.indexOf(p) < 0) t[p] = s[p];
  if (s != null && typeof Object.getOwnPropertySymbols === "function") for (var i = 0, p = Object.getOwnPropertySymbols(s); i < p.length; i++) {
    if (e.indexOf(p[i]) < 0 && Object.prototype.propertyIsEnumerable.call(s, p[i])) t[p[i]] = s[p[i]];
  }
  return t;
};
function Tree2Element(tree) {
  return tree && tree.map(function (node, i) {
    return SP_REACT.createElement(node.tag, __assign({
      key: i
    }, node.attr), Tree2Element(node.child));
  });
}
function GenIcon(data) {
  // eslint-disable-next-line react/display-name
  return function (props) {
    return SP_REACT.createElement(IconBase, __assign({
      attr: __assign({}, data.attr)
    }, props), Tree2Element(data.child));
  };
}
function IconBase(props) {
  var elem = function (conf) {
    var attr = props.attr,
      size = props.size,
      title = props.title,
      svgProps = __rest(props, ["attr", "size", "title"]);
    var computedSize = size || conf.size || "1em";
    var className;
    if (conf.className) className = conf.className;
    if (props.className) className = (className ? className + " " : "") + props.className;
    return SP_REACT.createElement("svg", __assign({
      stroke: "currentColor",
      fill: "currentColor",
      strokeWidth: "0"
    }, conf.attr, attr, svgProps, {
      className: className,
      style: __assign(__assign({
        color: props.color || conf.color
      }, conf.style), props.style),
      height: computedSize,
      width: computedSize,
      xmlns: "http://www.w3.org/2000/svg"
    }), title && SP_REACT.createElement("title", null, title), props.children);
  };
  return IconContext !== undefined ? SP_REACT.createElement(IconContext.Consumer, null, function (conf) {
    return elem(conf);
  }) : elem(DefaultContext);
}

// THIS FILE IS AUTO GENERATED
function BsArrowRepeat (props) {
  return GenIcon({"attr":{"fill":"currentColor","viewBox":"0 0 16 16"},"child":[{"tag":"path","attr":{"d":"M11.534 7h3.932a.25.25 0 0 1 .192.41l-1.966 2.36a.25.25 0 0 1-.384 0l-1.966-2.36a.25.25 0 0 1 .192-.41zm-11 2h3.932a.25.25 0 0 0 .192-.41L2.692 6.23a.25.25 0 0 0-.384 0L.342 8.59A.25.25 0 0 0 .534 9z"}},{"tag":"path","attr":{"fillRule":"evenodd","d":"M8 3c-1.552 0-2.94.707-3.857 1.818a.5.5 0 1 1-.771-.636A6.002 6.002 0 0 1 13.917 7H12.9A5.002 5.002 0 0 0 8 3zM3.1 9a5.002 5.002 0 0 0 8.757 2.182.5.5 0 1 1 .771.636A6.002 6.002 0 0 1 2.083 9H3.1z"}}]})(props);
}function BsEye (props) {
  return GenIcon({"attr":{"fill":"currentColor","viewBox":"0 0 16 16"},"child":[{"tag":"path","attr":{"d":"M16 8s-3-5.5-8-5.5S0 8 0 8s3 5.5 8 5.5S16 8 16 8zM1.173 8a13.133 13.133 0 0 1 1.66-2.043C4.12 4.668 5.88 3.5 8 3.5c2.12 0 3.879 1.168 5.168 2.457A13.133 13.133 0 0 1 14.828 8c-.058.087-.122.183-.195.288-.335.48-.83 1.12-1.465 1.755C11.879 11.332 10.119 12.5 8 12.5c-2.12 0-3.879-1.168-5.168-2.457A13.134 13.134 0 0 1 1.172 8z"}},{"tag":"path","attr":{"d":"M8 5.5a2.5 2.5 0 1 0 0 5 2.5 2.5 0 0 0 0-5zM4.5 8a3.5 3.5 0 1 1 7 0 3.5 3.5 0 0 1-7 0z"}}]})(props);
}function BsStars (props) {
  return GenIcon({"attr":{"fill":"currentColor","viewBox":"0 0 16 16"},"child":[{"tag":"path","attr":{"d":"M7.657 6.247c.11-.33.576-.33.686 0l.645 1.937a2.89 2.89 0 0 0 1.829 1.828l1.936.645c.33.11.33.576 0 .686l-1.937.645a2.89 2.89 0 0 0-1.828 1.829l-.645 1.936a.361.361 0 0 1-.686 0l-.645-1.937a2.89 2.89 0 0 0-1.828-1.828l-1.937-.645a.361.361 0 0 1 0-.686l1.937-.645a2.89 2.89 0 0 0 1.828-1.828l.645-1.937zM3.794 1.148a.217.217 0 0 1 .412 0l.387 1.162c.173.518.579.924 1.097 1.097l1.162.387a.217.217 0 0 1 0 .412l-1.162.387A1.734 1.734 0 0 0 4.593 5.69l-.387 1.162a.217.217 0 0 1-.412 0L3.407 5.69A1.734 1.734 0 0 0 2.31 4.593l-1.162-.387a.217.217 0 0 1 0-.412l1.162-.387A1.734 1.734 0 0 0 3.407 2.31l.387-1.162zM10.863.099a.145.145 0 0 1 .274 0l.258.774c.115.346.386.617.732.732l.774.258a.145.145 0 0 1 0 .274l-.774.258a1.156 1.156 0 0 0-.732.732l-.258.774a.145.145 0 0 1-.274 0l-.258-.774a1.156 1.156 0 0 0-.732-.732L9.1 2.137a.145.145 0 0 1 0-.274l.774-.258c.346-.115.617-.386.732-.732L10.863.1z"}}]})(props);
}function BsTranslate (props) {
  return GenIcon({"attr":{"fill":"currentColor","viewBox":"0 0 16 16"},"child":[{"tag":"path","attr":{"d":"M4.545 6.714 4.11 8H3l1.862-5h1.284L8 8H6.833l-.435-1.286H4.545zm1.634-.736L5.5 3.956h-.049l-.679 2.022H6.18z"}},{"tag":"path","attr":{"d":"M0 2a2 2 0 0 1 2-2h7a2 2 0 0 1 2 2v3h3a2 2 0 0 1 2 2v7a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2v-3H2a2 2 0 0 1-2-2V2zm2-1a1 1 0 0 0-1 1v7a1 1 0 0 0 1 1h7a1 1 0 0 0 1-1V2a1 1 0 0 0-1-1H2zm7.138 9.995c.193.301.402.583.63.846-.748.575-1.673 1.001-2.768 1.292.178.217.451.635.555.867 1.125-.359 2.08-.844 2.886-1.494.777.665 1.739 1.165 2.93 1.472.133-.254.414-.673.629-.89-1.125-.253-2.057-.694-2.82-1.284.681-.747 1.222-1.651 1.621-2.757H14V8h-3v1.047h.765c-.318.844-.74 1.546-1.272 2.13a6.066 6.066 0 0 1-.415-.492 1.988 1.988 0 0 1-.94.31z"}}]})(props);
}function BsXLg (props) {
  return GenIcon({"attr":{"fill":"currentColor","viewBox":"0 0 16 16"},"child":[{"tag":"path","attr":{"d":"M2.146 2.854a.5.5 0 1 1 .708-.708L8 7.293l5.146-5.147a.5.5 0 0 1 .708.708L8.707 8l5.147 5.146a.5.5 0 0 1-.708.708L8 8.707l-5.146 5.147a.5.5 0 0 1-.708-.708L7.293 8 2.146 2.854Z"}}]})(props);
}

/**
 * Styled logger for DeckyTranslator
 * Provides colored console logging with consistent formatting
 * Logging can be enabled/disabled via debug mode
 */
var LogLevel;
(function (LogLevel) {
    LogLevel["DEBUG"] = "DEBUG";
    LogLevel["INFO"] = "INFO";
    LogLevel["WARN"] = "WARN";
    LogLevel["ERROR"] = "ERROR";
})(LogLevel || (LogLevel = {}));
class Logger {
    constructor() {
        this.appName = 'DeckyTranslator';
        this._enabled = false; // Debug mode off by default
        // Color styles for console
        this.styles = {
            appName: 'color: #ff69b4; font-weight: bold;', // Pink for app name
            debug: 'color: #00bfff;', // Deep sky blue
            info: 'color: #00ff00;', // Lime green
            warn: 'color: #ffa500;', // Orange
            error: 'color: #ff0000; font-weight: bold;', // Red
            reset: 'color: inherit;'
        };
    }
    /**
     * Enable or disable debug logging
     * When disabled, only errors are logged
     */
    setEnabled(enabled) {
        this._enabled = enabled;
        if (enabled) {
            console.log(`%c${this.appName}%c | %cINFO%c | Logger | Debug logging enabled`, this.styles.appName, this.styles.reset, this.styles.info, this.styles.reset);
        }
    }
    /**
     * Check if debug logging is enabled
     */
    isEnabled() {
        return this._enabled;
    }
    log(level, component, message, ...args) {
        // Always log errors, otherwise check if enabled
        if (!this._enabled && level !== LogLevel.ERROR) {
            return;
        }
        const levelStyle = this.styles[level.toLowerCase()] || this.styles.info;
        console.log(`%c${this.appName}%c | %c${level}%c | ${component} | ${message}`, this.styles.appName, this.styles.reset, levelStyle, this.styles.reset, ...args);
    }
    debug(component, message, ...args) {
        this.log(LogLevel.DEBUG, component, message, ...args);
    }
    info(component, message, ...args) {
        this.log(LogLevel.INFO, component, message, ...args);
    }
    warn(component, message, ...args) {
        this.log(LogLevel.WARN, component, message, ...args);
    }
    error(component, message, ...args) {
        this.log(LogLevel.ERROR, component, message, ...args);
    }
    // For objects/data inspection
    logObject(component, label, obj) {
        if (!this._enabled) {
            return;
        }
        console.log(`%c${this.appName}%c | %cDEBUG%c | ${component} | ${label}:`, this.styles.appName, this.styles.reset, this.styles.debug, this.styles.reset, obj);
    }
}
const logger = new Logger();

// Curated list of Google Fonts with Cyrillic + Latin-ext support.
const WEB_FONTS = [
    'Open Sans',
    'Montserrat',
    'Nunito',
    'Raleway',
    'Exo 2',
    'Roboto Slab',
    'Merriweather',
    'Lora',
    'Russo One',
    'Press Start 2P',
    'Caveat',
    'Shantell Sans',
];
// Language-specific web font lists for scripts that need dedicated fonts.
const LANGUAGE_WEB_FONTS = {
    ja: ['Potta One', 'Hachi Maru Pop', 'Yuji Mai', 'DotGothic16', 'Zen Antique'], // Japanese
    ko: ['Gamja Flower', 'Jua', 'Song Myung'], // Korean
    'zh-CN': ['Noto Serif Simplified Chinese', 'ZCOOL QingKe HuangYou', 'Long Cang'], // Chinese Simplified
    'zh-TW': ['Noto Serif Traditional Chinese', 'Potta One', 'DotGothic16'], // Chinese Traditional
    th: ['Noto Serif Thai', 'Playpen Sans Thai', 'Itim'], // Thai
    hi: ['Noto Serif Devanagari', 'Kalam', 'Kurale'], // Hindi
    ar: ['Noto Nastaliq Urdu', 'Changa', 'Rakkas'], // Arabic
    el: ['Open Sans', 'Roboto Slab', 'Press Start 2P', 'Playpen Sans'], // Greek
};
function getWebFontsForLanguage(targetLanguage) {
    return LANGUAGE_WEB_FONTS[targetLanguage] ?? WEB_FONTS;
}
const allWebFontSet = new Set([...WEB_FONTS, ...Object.values(LANGUAGE_WEB_FONTS).flat()]);
function isWebFont(fontName) {
    return allWebFontSet.has(fontName);
}
const GFONTS_LINK_PREFIX = 'decky-translator-gfont-';
const GOOGLE_FONT_TIMEOUT_MS = 6000;
const loadedWebFonts = new Set();
function injectStylesheetLink(id, href, timeoutMs) {
    if (document.getElementById(id))
        return Promise.resolve(true);
    const link = document.createElement('link');
    link.id = id;
    link.rel = 'stylesheet';
    link.href = href;
    document.head.appendChild(link);
    return new Promise((resolve) => {
        let settled = false;
        const finish = (ok) => {
            if (settled)
                return;
            settled = true;
            if (!ok)
                link.remove();
            resolve(ok);
        };
        link.onload = () => {
            if (document.fonts?.ready) {
                document.fonts.ready.then(() => finish(true));
            }
            else {
                setTimeout(() => finish(true), 500);
            }
        };
        link.onerror = () => finish(false);
        setTimeout(() => finish(false), timeoutMs);
    });
}
function loadGoogleFont(fontName) {
    if (loadedWebFonts.has(fontName))
        return Promise.resolve(true);
    const id = GFONTS_LINK_PREFIX + fontName.replace(/\s+/g, '-');
    const familyParam = fontName.replace(/\s+/g, '+');
    const href = `https://fonts.googleapis.com/css2?family=${familyParam}:wght@400;700&display=swap`;
    return injectStylesheetLink(id, href, GOOGLE_FONT_TIMEOUT_MS).then(ok => {
        if (ok)
            loadedWebFonts.add(fontName);
        return ok;
    });
}
function preloadWebFontList(fonts) {
    for (const f of fonts) {
        loadGoogleFont(f).catch(() => { });
    }
}
function cleanupWebFonts() {
    document.querySelectorAll(`[id^="${GFONTS_LINK_PREFIX}"]`).forEach(el => el.remove());
    loadedWebFonts.clear();
}

const DYSLEXIA_FONT_DEFS = [
    // Latin / Cyrillic / Greek
    {
        name: 'OpenDyslexic',
        source: 'cdn',
        cdnCssUrls: [
            'https://cdn.jsdelivr.net/npm/@fontsource/opendyslexic@5.2.5/400.css',
            'https://cdn.jsdelivr.net/npm/@fontsource/opendyslexic@5.2.5/700.css',
        ],
        availableFor: 'Latin languages',
    },
    { name: 'Lexend', source: 'google', availableFor: 'Latin/Greek languages' },
    { name: 'Atkinson Hyperlegible Next', source: 'google', availableFor: 'Latin/Greek languages' },
    { name: 'Andika', source: 'google', availableFor: 'Latin/Cyrillic languages' },
    // Japanese
    { name: 'BIZ UDGothic', source: 'google', availableFor: 'Japanese' },
    { name: 'BIZ UDMincho', source: 'google', availableFor: 'Japanese' },
    { name: 'BIZ UDPGothic', source: 'google', availableFor: 'Japanese' },
    // Korean
    { name: 'Nanum Gothic', source: 'google', availableFor: 'Korean' },
    // Chinese
    { name: 'Noto Sans SC', source: 'google', availableFor: 'Simplified Chinese' },
    { name: 'Noto Sans TC', source: 'google', availableFor: 'Traditional Chinese' },
    // Thai
    { name: 'Noto Sans Thai Looped', source: 'google', availableFor: 'Thai' },
    // Hindi / Devanagari
    { name: 'Noto Sans Devanagari', source: 'google', availableFor: 'Hindi' },
    // Arabic
    { name: 'Noto Sans Arabic', source: 'google', availableFor: 'Arabic' },
];
/**
 * Mapping from target language code to dyslexia-friendly font names.
 * Languages not listed here fall back to the default Latin set.
 */
// Cyrillic languages – only Andika has Cyrillic support among dyslexia fonts
const CYRILLIC_DYSLEXIA_FONTS = ['Andika'];
const CYRILLIC_LANGS = ['ru', 'uk', 'bg', 'be', 'mk', 'sr', 'kk', 'ky', 'mn', 'tg', 'ba', 'cv', 'tt', 'os'];
const LANGUAGE_DYSLEXIA_FONTS = {
    ...Object.fromEntries(CYRILLIC_LANGS.map(lang => [lang, CYRILLIC_DYSLEXIA_FONTS])),
    // Japanese
    ja: ['BIZ UDGothic', 'BIZ UDMincho', 'BIZ UDPGothic'],
    // Korean
    ko: ['Nanum Gothic'],
    // Chinese
    'zh-CN': ['Noto Sans SC'],
    'zh-TW': ['Noto Sans TC'],
    // Thai
    th: ['Noto Sans Thai Looped'],
    // Hindi
    hi: ['Noto Sans Devanagari'],
    // Arabic
    ar: ['Noto Sans Arabic'],
    // Greek – Atkinson Hyperlegible Next & Lexend cover Greek glyphs
    el: ['Atkinson Hyperlegible Next', 'Lexend'],
};
const DEFAULT_DYSLEXIA_FONTS = ['OpenDyslexic', 'Lexend', 'Atkinson Hyperlegible Next', 'Andika'];
const dyslexiaFontSet = new Set(DYSLEXIA_FONT_DEFS.map(f => f.name));
const dyslexiaFontMap = new Map(DYSLEXIA_FONT_DEFS.map(f => [f.name, f]));
const ALL_DYSLEXIA_FONT_NAMES = DYSLEXIA_FONT_DEFS.map(f => f.name);
function isDyslexiaFont(fontName) {
    return dyslexiaFontSet.has(fontName);
}
function getDyslexiaFontsForLanguage(targetLanguage) {
    return LANGUAGE_DYSLEXIA_FONTS[targetLanguage] ?? DEFAULT_DYSLEXIA_FONTS;
}
function getAllDyslexiaFontNames() {
    return ALL_DYSLEXIA_FONT_NAMES;
}
function getDyslexiaFontAvailableFor(fontName) {
    return dyslexiaFontMap.get(fontName)?.availableFor ?? '';
}
// Higher than Google Fonts timeout because CDN fonts may load multiple stylesheets sequentially.
const CDN_FONT_TIMEOUT_MS = GOOGLE_FONT_TIMEOUT_MS + 2000;
const loadedCDNFonts = new Set();
function loadCDNFont(fontName) {
    if (loadedCDNFonts.has(fontName))
        return Promise.resolve(true);
    const def = dyslexiaFontMap.get(fontName);
    if (!def || def.source !== 'cdn' || !def.cdnCssUrls?.length)
        return Promise.resolve(false);
    const promises = def.cdnCssUrls.map((cssUrl, i) => {
        const id = `decky-translator-cdnfont-${fontName.replace(/\s+/g, '-')}-${i}`;
        return injectStylesheetLink(id, cssUrl, CDN_FONT_TIMEOUT_MS);
    });
    return Promise.allSettled(promises).then(results => {
        const ok = results.every(r => r.status === 'fulfilled' && r.value);
        if (ok)
            loadedCDNFonts.add(fontName);
        return ok;
    });
}
function loadDyslexiaFont(fontName) {
    const def = dyslexiaFontMap.get(fontName);
    if (!def)
        return Promise.resolve(false);
    return def.source === 'google' ? loadGoogleFont(fontName) : loadCDNFont(fontName);
}
function preloadDyslexiaFonts(targetLanguage) {
    for (const f of getDyslexiaFontsForLanguage(targetLanguage)) {
        loadDyslexiaFont(f).catch(() => { });
    }
}
function cleanupDyslexiaFonts() {
    document.querySelectorAll('[id^="decky-translator-cdnfont-"]').forEach(el => el.remove());
    loadedCDNFonts.clear();
}

// THIS FILE IS AUTO GENERATED
function HiExclamationTriangle (props) {
  return GenIcon({"attr":{"viewBox":"0 0 24 24","fill":"currentColor","aria-hidden":"true"},"child":[{"tag":"path","attr":{"fillRule":"evenodd","d":"M9.401 3.003c1.155-2 4.043-2 5.197 0l7.355 12.748c1.154 2-.29 4.5-2.599 4.5H4.645c-2.309 0-3.752-2.5-2.598-4.5L9.4 3.003zM12 8.25a.75.75 0 01.75.75v3.75a.75.75 0 01-1.5 0V9a.75.75 0 01.75-.75zm0 8.25a.75.75 0 100-1.5.75.75 0 000 1.5z","clipRule":"evenodd"}}]})(props);
}function HiInboxArrowDown (props) {
  return GenIcon({"attr":{"viewBox":"0 0 24 24","fill":"currentColor","aria-hidden":"true"},"child":[{"tag":"path","attr":{"fillRule":"evenodd","d":"M5.478 5.559A1.5 1.5 0 016.912 4.5H9A.75.75 0 009 3H6.912a3 3 0 00-2.868 2.118l-2.411 7.838a3 3 0 00-.133.882V18a3 3 0 003 3h15a3 3 0 003-3v-4.162c0-.299-.045-.596-.133-.882l-2.412-7.838A3 3 0 0017.088 3H15a.75.75 0 000 1.5h2.088a1.5 1.5 0 011.434 1.059l2.213 7.191H17.89a3 3 0 00-2.684 1.658l-.256.513a1.5 1.5 0 01-1.342.829h-3.218a1.5 1.5 0 01-1.342-.83l-.256-.512a3 3 0 00-2.684-1.658H3.265l2.213-7.191z","clipRule":"evenodd"}},{"tag":"path","attr":{"fillRule":"evenodd","d":"M12 2.25a.75.75 0 01.75.75v6.44l1.72-1.72a.75.75 0 111.06 1.06l-3 3a.75.75 0 01-1.06 0l-3-3a.75.75 0 011.06-1.06l1.72 1.72V3a.75.75 0 01.75-.75z","clipRule":"evenodd"}}]})(props);
}function HiInformationCircle (props) {
  return GenIcon({"attr":{"viewBox":"0 0 24 24","fill":"currentColor","aria-hidden":"true"},"child":[{"tag":"path","attr":{"fillRule":"evenodd","d":"M2.25 12c0-5.385 4.365-9.75 9.75-9.75s9.75 4.365 9.75 9.75-4.365 9.75-9.75 9.75S2.25 17.385 2.25 12zm8.706-1.442c1.146-.573 2.437.463 2.126 1.706l-.709 2.836.042-.02a.75.75 0 01.67 1.34l-.04.022c-1.147.573-2.438-.463-2.127-1.706l.71-2.836-.042.02a.75.75 0 11-.671-1.34l.041-.022zM12 9a.75.75 0 100-1.5.75.75 0 000 1.5z","clipRule":"evenodd"}}]})(props);
}function HiKey (props) {
  return GenIcon({"attr":{"viewBox":"0 0 24 24","fill":"currentColor","aria-hidden":"true"},"child":[{"tag":"path","attr":{"fillRule":"evenodd","d":"M15.75 1.5a6.75 6.75 0 00-6.651 7.906c.067.39-.032.717-.221.906l-6.5 6.499a3 3 0 00-.878 2.121v2.818c0 .414.336.75.75.75H6a.75.75 0 00.75-.75v-1.5h1.5A.75.75 0 009 19.5V18h1.5a.75.75 0 00.53-.22l2.658-2.658c.19-.189.517-.288.906-.22A6.75 6.75 0 1015.75 1.5zm0 3a.75.75 0 000 1.5A2.25 2.25 0 0118 8.25a.75.75 0 001.5 0 3.75 3.75 0 00-3.75-3.75z","clipRule":"evenodd"}}]})(props);
}function HiLockClosed (props) {
  return GenIcon({"attr":{"viewBox":"0 0 24 24","fill":"currentColor","aria-hidden":"true"},"child":[{"tag":"path","attr":{"fillRule":"evenodd","d":"M12 1.5a5.25 5.25 0 00-5.25 5.25v3a3 3 0 00-3 3v6.75a3 3 0 003 3h10.5a3 3 0 003-3v-6.75a3 3 0 00-3-3v-3c0-2.9-2.35-5.25-5.25-5.25zm3.75 8.25v-3a3.75 3.75 0 10-7.5 0v3h7.5z","clipRule":"evenodd"}}]})(props);
}function HiQrCode (props) {
  return GenIcon({"attr":{"viewBox":"0 0 24 24","fill":"currentColor","aria-hidden":"true"},"child":[{"tag":"path","attr":{"fillRule":"evenodd","d":"M3 4.875C3 3.839 3.84 3 4.875 3h4.5c1.036 0 1.875.84 1.875 1.875v4.5c0 1.036-.84 1.875-1.875 1.875h-4.5A1.875 1.875 0 013 9.375v-4.5zM4.875 4.5a.375.375 0 00-.375.375v4.5c0 .207.168.375.375.375h4.5a.375.375 0 00.375-.375v-4.5a.375.375 0 00-.375-.375h-4.5zm7.875.375c0-1.036.84-1.875 1.875-1.875h4.5C20.16 3 21 3.84 21 4.875v4.5c0 1.036-.84 1.875-1.875 1.875h-4.5a1.875 1.875 0 01-1.875-1.875v-4.5zm1.875-.375a.375.375 0 00-.375.375v4.5c0 .207.168.375.375.375h4.5a.375.375 0 00.375-.375v-4.5a.375.375 0 00-.375-.375h-4.5zM6 6.75A.75.75 0 016.75 6h.75a.75.75 0 01.75.75v.75a.75.75 0 01-.75.75h-.75A.75.75 0 016 7.5v-.75zm9.75 0A.75.75 0 0116.5 6h.75a.75.75 0 01.75.75v.75a.75.75 0 01-.75.75h-.75a.75.75 0 01-.75-.75v-.75zM3 14.625c0-1.036.84-1.875 1.875-1.875h4.5c1.036 0 1.875.84 1.875 1.875v4.5c0 1.035-.84 1.875-1.875 1.875h-4.5A1.875 1.875 0 013 19.125v-4.5zm1.875-.375a.375.375 0 00-.375.375v4.5c0 .207.168.375.375.375h4.5a.375.375 0 00.375-.375v-4.5a.375.375 0 00-.375-.375h-4.5zm7.875-.75a.75.75 0 01.75-.75h.75a.75.75 0 01.75.75v.75a.75.75 0 01-.75.75h-.75a.75.75 0 01-.75-.75v-.75zm6 0a.75.75 0 01.75-.75h.75a.75.75 0 01.75.75v.75a.75.75 0 01-.75.75h-.75a.75.75 0 01-.75-.75v-.75zM6 16.5a.75.75 0 01.75-.75h.75a.75.75 0 01.75.75v.75a.75.75 0 01-.75.75h-.75a.75.75 0 01-.75-.75v-.75zm9.75 0a.75.75 0 01.75-.75h.75a.75.75 0 01.75.75v.75a.75.75 0 01-.75.75h-.75a.75.75 0 01-.75-.75v-.75zm-3 3a.75.75 0 01.75-.75h.75a.75.75 0 01.75.75v.75a.75.75 0 01-.75.75h-.75a.75.75 0 01-.75-.75v-.75zm6 0a.75.75 0 01.75-.75h.75a.75.75 0 01.75.75v.75a.75.75 0 01-.75.75h-.75a.75.75 0 01-.75-.75v-.75z","clipRule":"evenodd"}}]})(props);
}function HiTrash (props) {
  return GenIcon({"attr":{"viewBox":"0 0 24 24","fill":"currentColor","aria-hidden":"true"},"child":[{"tag":"path","attr":{"fillRule":"evenodd","d":"M16.5 4.478v.227a48.816 48.816 0 013.878.512.75.75 0 11-.256 1.478l-.209-.035-1.005 13.07a3 3 0 01-2.991 2.77H8.084a3 3 0 01-2.991-2.77L4.087 6.66l-.209.035a.75.75 0 01-.256-1.478A48.567 48.567 0 017.5 4.705v-.227c0-1.564 1.213-2.9 2.816-2.951a52.662 52.662 0 013.369 0c1.603.051 2.815 1.387 2.815 2.951zm-6.136-1.452a51.196 51.196 0 013.273 0C14.39 3.05 15 3.684 15 4.478v.113a49.488 49.488 0 00-6 0v-.113c0-.794.609-1.428 1.364-1.452zm-.355 5.945a.75.75 0 10-1.5.058l.347 9a.75.75 0 101.499-.058l-.346-9zm5.48.058a.75.75 0 10-1.498-.058l-.347 9a.75.75 0 001.5.058l.345-9z","clipRule":"evenodd"}}]})(props);
}function HiXCircle (props) {
  return GenIcon({"attr":{"viewBox":"0 0 24 24","fill":"currentColor","aria-hidden":"true"},"child":[{"tag":"path","attr":{"fillRule":"evenodd","d":"M12 2.25c-5.385 0-9.75 4.365-9.75 9.75s4.365 9.75 9.75 9.75 9.75-4.365 9.75-9.75S17.385 2.25 12 2.25zm-1.72 6.97a.75.75 0 10-1.06 1.06L10.94 12l-1.72 1.72a.75.75 0 101.06 1.06L12 13.06l1.72 1.72a.75.75 0 101.06-1.06L13.06 12l1.72-1.72a.75.75 0 10-1.06-1.06L12 10.94l-1.72-1.72z","clipRule":"evenodd"}}]})(props);
}function HiXMark (props) {
  return GenIcon({"attr":{"viewBox":"0 0 24 24","fill":"currentColor","aria-hidden":"true"},"child":[{"tag":"path","attr":{"fillRule":"evenodd","d":"M5.47 5.47a.75.75 0 011.06 0L12 10.94l5.47-5.47a.75.75 0 111.06 1.06L13.06 12l5.47 5.47a.75.75 0 11-1.06 1.06L12 13.06l-5.47 5.47a.75.75 0 01-1.06-1.06L10.94 12 5.47 6.53a.75.75 0 010-1.06z","clipRule":"evenodd"}}]})(props);
}

const DEFAULT_TRANSLATED_FONT_FAMILY = "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif";
const FONT_STYLE_CSS = {
    normal: { fontWeight: '400', fontStyle: 'normal' },
    bold: { fontWeight: '700', fontStyle: 'normal' },
    italic: { fontWeight: '400', fontStyle: 'italic' },
    bolditalic: { fontWeight: '700', fontStyle: 'italic' },
};
function resolveFontStyleCSS(style) {
    return FONT_STYLE_CSS[style] || FONT_STYLE_CSS.normal;
}
function quoteFontName(fontName) {
    return `'${fontName.replace(/'/g, "\\'")}'`;
}
const LOCAL_FONT_CANDIDATES = [
    'DejaVu Serif',
    'DejaVu Sans',
    'DejaVu Sans Mono',
    'Noto Serif',
    'Noto Sans',
    'Noto Sans Mono',
];
/** Canvas-based font detection: compares pixel widths with a known fallback. */
function isFontAvailableCanvas(fontName) {
    try {
        const canvas = document.createElement('canvas');
        const ctx = canvas.getContext('2d');
        if (!ctx)
            return false;
        const testString = 'mmmmmmmmmmlli1|WMwij#@';
        const size = '72px';
        const baseFonts = ['monospace', 'sans-serif', 'serif'];
        const quoted = quoteFontName(fontName);
        for (const base of baseFonts) {
            ctx.font = `${size} ${base}`;
            const baseWidth = ctx.measureText(testString).width;
            ctx.font = `${size} ${quoted}, ${base}`;
            const testWidth = ctx.measureText(testString).width;
            if (Math.abs(baseWidth - testWidth) > 0.1)
                return true;
        }
        return false;
    }
    catch {
        return false;
    }
}
function detectAvailableFonts(fontCandidates) {
    const detected = new Set();
    for (const fontName of fontCandidates) {
        if (isFontAvailableCanvas(fontName)) {
            detected.add(fontName);
        }
    }
    return detected;
}
// Steam's CEF may not expose system fonts unless they are explicitly
// declared through @font-face with a local() src.
const STYLE_ID = 'decky-translator-font-faces';
function getOrCreateStyleSheet() {
    let el = document.getElementById(STYLE_ID);
    if (!el) {
        el = document.createElement('style');
        el.id = STYLE_ID;
        document.head.appendChild(el);
    }
    return el;
}
const injectedFonts = new Set();
/** Inject a @font-face local() rule so CEF can resolve the font. No-op if already injected. */
function ensureFontFaceRegistered(fontName) {
    if (!fontName || injectedFonts.has(fontName))
        return;
    const style = getOrCreateStyleSheet();
    const escaped = fontName.replace(/'/g, "\\'");
    style.textContent += `\n@font-face { font-family: '${escaped}'; src: local('${escaped}'); }`;
    injectedFonts.add(fontName);
}
function ensureAllFontFaces(fonts) {
    for (const f of fonts)
        ensureFontFaceRegistered(f);
}
function cleanupFontFaces() {
    document.getElementById(STYLE_ID)?.remove();
    injectedFonts.clear();
}
/** Build the CSS font-family string. Pure — no side-effects. */
function buildTranslatedFontFamily(selectedFontFamily) {
    const normalizedSelection = selectedFontFamily?.trim();
    if (!normalizedSelection)
        return DEFAULT_TRANSLATED_FONT_FAMILY;
    return `${quoteFontName(normalizedSelection)}, ${DEFAULT_TRANSLATED_FONT_FAMILY}`;
}
/** Ensure the selected font is loaded (network / DOM injection). Fire-and-forget. */
function ensureFontLoaded(selectedFontFamily) {
    const normalizedSelection = selectedFontFamily?.trim();
    if (!normalizedSelection)
        return;
    if (isDyslexiaFont(normalizedSelection)) {
        loadDyslexiaFont(normalizedSelection).catch(() => { });
    }
    else if (isWebFont(normalizedSelection)) {
        loadGoogleFont(normalizedSelection).catch(() => { });
    }
    else {
        ensureFontFaceRegistered(normalizedSelection);
    }
}
function useFontOptions(selectedFontFamily, targetLanguage, onFontReset) {
    const [availableFonts, setAvailableFonts] = SP_REACT.useState([]);
    SP_REACT.useEffect(() => {
        const detected = detectAvailableFonts(LOCAL_FONT_CANDIDATES);
        ensureAllFontFaces(detected);
        setAvailableFonts(Array.from(detected).sort((a, b) => a.localeCompare(b)));
    }, []);
    const webFonts = SP_REACT.useMemo(() => getWebFontsForLanguage(targetLanguage), [targetLanguage]);
    const dyslexiaFonts = SP_REACT.useMemo(() => getDyslexiaFontsForLanguage(targetLanguage), [targetLanguage]);
    const allDyslexiaFonts = SP_REACT.useMemo(() => getAllDyslexiaFontNames(), []);
    const unavailableDyslexiaFonts = SP_REACT.useMemo(() => {
        const supported = new Set(dyslexiaFonts);
        return new Set(allDyslexiaFonts.filter(f => !supported.has(f)));
    }, [allDyslexiaFonts, dyslexiaFonts]);
    const fontOptions = SP_REACT.useMemo(() => {
        const localSet = new Set(availableFonts);
        const allDyslexiaSet = new Set(allDyslexiaFonts);
        const webOnly = webFonts.filter(f => !localSet.has(f) && !allDyslexiaSet.has(f)).sort((a, b) => a.localeCompare(b));
        const supportedDyslexiaSet = new Set(dyslexiaFonts);
        const orderedDyslexiaFonts = [
            ...dyslexiaFonts,
            ...allDyslexiaFonts.filter(f => !supportedDyslexiaSet.has(f)),
        ];
        const styledLabel = (text, fontFamily) => SP_REACT.createElement('span', { style: { fontFamily: `${quoteFontName(fontFamily)}, sans-serif` } }, text);
        const unavailableLabel = (fontFamily) => SP_REACT.createElement('span', { style: { opacity: 0.45, fontSize: '0.85em', fontFamily: `${quoteFontName(fontFamily)}, sans-serif` } }, SP_REACT.createElement(HiLockClosed, { style: { marginRight: 6, verticalAlign: '-0.125em' } }), fontFamily, SP_REACT.createElement('span', { style: { marginLeft: 8, fontStyle: 'italic', fontFamily: 'inherit' } }, `(${getDyslexiaFontAvailableFor(fontFamily)})`));
        const options = [
            { label: "Auto (System Default)", data: "" },
        ];
        if (selectedFontFamily && !localSet.has(selectedFontFamily) && !webOnly.includes(selectedFontFamily) && !allDyslexiaSet.has(selectedFontFamily)) {
            options.push({ label: styledLabel(selectedFontFamily, selectedFontFamily), data: selectedFontFamily });
        }
        if (availableFonts.length > 0) {
            options.push({
                label: "Local Fonts",
                options: availableFonts.map(f => ({ label: styledLabel(f, f), data: f })),
            });
        }
        options.push({
            label: "Dyslexia-Friendly",
            options: orderedDyslexiaFonts.map(f => ({
                label: unavailableDyslexiaFonts.has(f) ? unavailableLabel(f) : styledLabel(f, f),
                data: f,
            })),
        });
        if (webOnly.length > 0) {
            options.push({
                label: "Web Fonts",
                options: webOnly.map(f => ({ label: styledLabel(f, f), data: f })),
            });
        }
        return options;
    }, [availableFonts, selectedFontFamily, webFonts, dyslexiaFonts, allDyslexiaFonts, unavailableDyslexiaFonts]);
    // Reset font to Auto when target language changes and current font is not in the new list
    const prevLangRef = SP_REACT.useRef(targetLanguage);
    SP_REACT.useEffect(() => {
        if (prevLangRef.current === targetLanguage)
            return;
        prevLangRef.current = targetLanguage;
        if (selectedFontFamily && !webFonts.includes(selectedFontFamily) && !availableFonts.includes(selectedFontFamily) && !dyslexiaFonts.includes(selectedFontFamily)) {
            onFontReset?.();
        }
        // eslint-disable-next-line react-hooks/exhaustive-deps -- intentionally runs only on language change
    }, [targetLanguage]);
    const preloadedLangRef = SP_REACT.useRef('');
    const preloadWebFonts = SP_REACT.useCallback(() => {
        if (preloadedLangRef.current !== targetLanguage) {
            preloadedLangRef.current = targetLanguage;
            preloadWebFontList(getWebFontsForLanguage(targetLanguage));
            preloadDyslexiaFonts(targetLanguage);
        }
    }, [targetLanguage]);
    const fontDescription = SP_REACT.useMemo(() => {
        const webCount = webFonts.filter(f => !availableFonts.includes(f)).length;
        return `${availableFonts.length} local + ${webCount} web`
            + (dyslexiaFonts.length > 0 ? ` + ${dyslexiaFonts.length} dyslexia` : '')
            + ' fonts';
    }, [availableFonts, webFonts, dyslexiaFonts]);
    return { availableFonts, webFonts, dyslexiaFonts, unavailableDyslexiaFonts, fontOptions, fontDescription, preloadWebFonts };
}
function isRemoteFont(fontName) {
    return isWebFont(fontName) || isDyslexiaFont(fontName);
}
function loadRemoteFont(fontName) {
    if (isDyslexiaFont(fontName))
        return loadDyslexiaFont(fontName);
    if (isWebFont(fontName))
        return loadGoogleFont(fontName);
    return Promise.resolve(false);
}

// fonts/index.ts - Barrel export for font modules
/** Remove all font-related <style> and <link> elements injected by the plugin. */
function cleanupAllFontDOM() {
    cleanupFontFaces();
    cleanupWebFonts();
    cleanupDyslexiaFonts();
}

// Overlay.tsx - Handles overlay components and UI

// UI Composition for overlay
var UIComposition$1;
(function (UIComposition) {
    UIComposition[UIComposition["Hidden"] = 0] = "Hidden";
    UIComposition[UIComposition["Notification"] = 1] = "Notification";
    UIComposition[UIComposition["Overlay"] = 2] = "Overlay";
    UIComposition[UIComposition["Opaque"] = 3] = "Opaque";
    UIComposition[UIComposition["OverlayKeyboard"] = 4] = "OverlayKeyboard";
})(UIComposition$1 || (UIComposition$1 = {}));
const useUIComposition$1 = DFL.findModuleChild((m) => {
    if (typeof m !== "object")
        return undefined;
    for (let prop in m) {
        if (typeof m[prop] === "function" &&
            m[prop].toString().includes("AddMinimumCompositionStateRequest") &&
            m[prop].toString().includes("ChangeMinimumCompositionStateRequest") &&
            m[prop].toString().includes("RemoveMinimumCompositionStateRequest") &&
            !m[prop].toString().includes("m_mapCompositionStateRequests")) {
            return m[prop];
        }
    }
});
// Mountable component that holds a composition state request.
// When unmounted, the hook cleanup calls RemoveMinimumCompositionStateRequest,
// fully releasing the request so Steam's own UI sections can get input focus.
const CompositionRequest$1 = ({ level }) => {
    useUIComposition$1(level);
    return null;
};
// Enhanced ImageState to handle translated text regions
class ImageState {
    constructor() {
        this.visible = false;
        this.imageData = "";
        this.translatedRegions = [];
        this.loading = false;
        this.processingStep = ""; // Added to track current processing step
        this.processingDetail = "";
        this.processingIsError = false;
        this.loadingIndicatorTimer = null; // Timer for delayed indicator
        this.translationsVisible = true; // New property to track translation visibility
        this.fontScale = 1.0;
        this.allowLabelGrowth = false;
        this.translatedTextAlignment = 'center';
        this.translatedTextFontFamily = "";
        this.translatedTextFontStyle = 'normal';
        this.onStateChangedListeners = [];
    }
    onStateChanged(callback) {
        this.onStateChangedListeners.push(callback);
    }
    offStateChanged(callback) {
        const index = this.onStateChangedListeners.indexOf(callback);
        if (index !== -1) {
            this.onStateChangedListeners.splice(index, 1);
        }
    }
    // Show the overlay with loading indicator immediately
    startLoading(step = "Capturing") {
        // Set internal state immediately
        this.visible = true;
        this.loading = true;
        this.processingStep = step;
        this.processingDetail = "";
        this.processingIsError = false;
        this.translationsVisible = true; // Reset to visible when starting new translation
        // Clear any existing timer
        if (this.loadingIndicatorTimer) {
            clearTimeout(this.loadingIndicatorTimer);
            this.loadingIndicatorTimer = null;
        }
        // Show loading indicator immediately - no stealth mode
        // This ensures the overlay has visible content which properly maintains UI composition
        this.notifyListeners();
    }
    // Toggle translation visibility
    toggleTranslationsVisibility() {
        this.translationsVisible = !this.translationsVisible;
        logger.debug('ImageState', `Translations visibility toggled to: ${this.translationsVisible}`);
        this.notifyListeners();
    }
    // Getter for translation visibility state
    areTranslationsVisible() {
        return this.translationsVisible;
    }
    setFontScale(scale) {
        this.fontScale = scale;
        this.notifyListeners();
    }
    getFontScale() {
        return this.fontScale;
    }
    setAllowLabelGrowth(allow) {
        this.allowLabelGrowth = allow;
        this.notifyListeners();
    }
    getAllowLabelGrowth() {
        return this.allowLabelGrowth;
    }
    setTranslatedTextAlignment(alignment) {
        this.translatedTextAlignment = alignment;
        this.notifyListeners();
    }
    getTranslatedTextAlignment() {
        return this.translatedTextAlignment;
    }
    setTranslatedTextFontFamily(fontFamily) {
        this.translatedTextFontFamily = fontFamily;
        this.notifyListeners();
    }
    getTranslatedTextFontFamily() {
        return this.translatedTextFontFamily;
    }
    setTranslatedTextFontStyle(style) {
        this.translatedTextFontStyle = style;
        this.notifyListeners();
    }
    getTranslatedTextFontStyle() {
        return this.translatedTextFontStyle;
    }
    // Update the current processing step
    updateProcessingStep(step, isError = false, detail = "") {
        this.processingStep = step;
        this.processingDetail = detail;
        this.processingIsError = isError;
        // Update the loading state and keep the current image displayed
        this.loading = true;
        // Force immediate update
        this.notifyListeners();
    }
    showImage(imageData) {
        // Clear any pending timer
        if (this.loadingIndicatorTimer) {
            clearTimeout(this.loadingIndicatorTimer);
            this.loadingIndicatorTimer = null;
        }
        // Always set a fresh image data - don't reuse old data
        this.imageData = imageData;
        // Clear any previous translations
        this.translatedRegions = [];
        // Ensure the overlay is visible
        this.visible = true;
        // Reset translations visibility to true for new image
        this.translationsVisible = true;
        // Set loading state based on whether we're in the middle of processing
        this.loading = this.processingStep !== "";
        logger.debug('ImageState', `Showing new image, length: ${imageData.length}, loading: ${this.loading}, step: ${this.processingStep}`);
        // Notify all listeners about the state change
        this.notifyListeners();
    }
    showTranslatedImage(imageData, regions) {
        // Clear any pending timer
        if (this.loadingIndicatorTimer) {
            clearTimeout(this.loadingIndicatorTimer);
            this.loadingIndicatorTimer = null;
        }
        // Always set fresh image data
        this.imageData = imageData;
        // Set the translated regions
        this.translatedRegions = regions;
        // Ensure the overlay is visible
        this.visible = true;
        // Make sure translations are visible when first showing them
        this.translationsVisible = true;
        // Turn off loading state and clear processing step
        this.loading = false;
        this.processingStep = "";
        this.processingDetail = "";
        this.processingIsError = false;
        logger.info('ImageState', `Showing translated image with ${regions.length} text regions`);
        this.notifyListeners();
    }
    hideImage() {
        // Clear any pending timer
        if (this.loadingIndicatorTimer) {
            clearTimeout(this.loadingIndicatorTimer);
            this.loadingIndicatorTimer = null;
        }
        // Reset all state properties
        this.visible = false;
        this.loading = false;
        this.processingStep = "";
        this.processingDetail = "";
        this.processingIsError = false;
        this.translationsVisible = true; // Reset to default when hiding
        // Important: Clear the image data and regions to prevent reuse
        this.imageData = "";
        this.translatedRegions = [];
        logger.debug('ImageState', 'Hiding image and clearing all state');
        this.notifyListeners();
    }
    notifyListeners() {
        for (const callback of this.onStateChangedListeners) {
            callback(this.visible, this.imageData, this.translatedRegions, this.loading, this.processingStep, this.processingDetail, this.processingIsError, this.translationsVisible, this.fontScale, this.allowLabelGrowth, this.translatedTextAlignment, this.translatedTextFontFamily, this.translatedTextFontStyle);
        }
    }
    isVisible() {
        return this.visible;
    }
    isLoading() {
        return this.loading;
    }
    getCurrentStep() {
        return this.processingStep;
    }
}
// Redistribute text evenly across maxLines via binary search for minimum line width.
// CJK (no spaces): splits by character count.
function redistributeText(flat, maxLines) {
    if (maxLines <= 1 || flat.length === 0)
        return flat;
    const hasSpaces = flat.includes(' ');
    if (hasSpaces) {
        const words = flat.split(/\s+/);
        if (words.length <= maxLines)
            return words.join('\n');
        // Binary search: find minimum max-line-width that fits in maxLines
        const longestWord = Math.max(...words.map(w => w.length));
        let lo = longestWord;
        let hi = flat.length;
        const canFit = (maxWidth) => {
            let lines = 1;
            let lineLen = 0;
            for (const word of words) {
                if (lineLen === 0) {
                    lineLen = word.length;
                }
                else if (lineLen + 1 + word.length <= maxWidth) {
                    lineLen += 1 + word.length;
                }
                else {
                    lines++;
                    lineLen = word.length;
                    if (lines > maxLines)
                        return false;
                }
            }
            return lines <= maxLines;
        };
        while (lo < hi) {
            const mid = Math.floor((lo + hi) / 2);
            if (canFit(mid)) {
                hi = mid;
            }
            else {
                lo = mid + 1;
            }
        }
        const optimalWidth = lo;
        const lines = [];
        let currentLine = '';
        for (const word of words) {
            if (currentLine.length === 0) {
                currentLine = word;
            }
            else if (currentLine.length + 1 + word.length <= optimalWidth) {
                currentLine += ' ' + word;
            }
            else {
                lines.push(currentLine);
                currentLine = word;
            }
        }
        if (currentLine)
            lines.push(currentLine);
        return lines.join('\n');
    }
    else {
        const charsPerLine = Math.ceil(flat.length / maxLines);
        const lines = [];
        for (let i = 0; i < flat.length; i += charsPerLine) {
            lines.push(flat.slice(i, i + charsPerLine));
        }
        return lines.join('\n');
    }
}
// Area-based font sizing: picks a font size so the text fills the region
function calculateFontSize(region, scalingFactor, fontScale) {
    const regionWidth = (region.rect.right - region.rect.left) * scalingFactor;
    const regionHeight = (region.rect.bottom - region.rect.top) * scalingFactor;
    const text = region.translatedText || region.text;
    const charCount = text.length;
    if (charCount === 0)
        return 12;
    const fillFactor = 0.7;
    const charArea = (regionWidth * regionHeight) / charCount * fillFactor;
    let fontSize = Math.sqrt(charArea);
    const availableWidth = regionWidth - 4;
    const availableHeight = regionHeight - 2;
    if (availableWidth <= 0 || availableHeight <= 0)
        return 7;
    const charsPerLine = Math.max(1, Math.floor(availableWidth / (fontSize * 0.6)));
    const explicitLines = text.split('\n');
    const lines = explicitLines.reduce((total, line) => total + Math.max(1, Math.ceil(line.length / charsPerLine)), 0);
    const neededHeight = lines * fontSize * 1.15;
    if (neededHeight > availableHeight) {
        fontSize *= availableHeight / neededHeight;
    }
    fontSize *= fontScale;
    return Math.max(7, Math.min(fontSize, 48));
}
// Overlay component to display translated text
const TranslatedTextOverlay = ({ visible, imageData, regions, loading, processingStep, processingDetail, processingIsError, translationsVisible, fontScale, allowLabelGrowth, translatedTextAlignment, translatedTextFontFamily, translatedTextFontStyle }) => {
    // Composition layer is handled by CompositionRequest below -- only mounted when visible
    // Ref to the screenshot image element
    const imgRef = SP_REACT.useRef(null);
    // State to track actual rendered image dimensions
    const [imageDimensions, setImageDimensions] = SP_REACT.useState({ width: 0, height: 0 });
    // State to track the natural (original) image dimensions from the screenshot
    const [naturalDimensions, setNaturalDimensions] = SP_REACT.useState({ width: 1280, height: 800 });
    // Load font as a side-effect (network request / DOM injection)
    SP_REACT.useEffect(() => {
        ensureFontLoaded(translatedTextFontFamily);
    }, [translatedTextFontFamily]);
    // Pure computation — no side-effects
    const translatedOverlayFontFamily = SP_REACT.useMemo(() => {
        const resolved = buildTranslatedFontFamily(translatedTextFontFamily);
        logger.debug('Overlay', `Font resolved: "${translatedTextFontFamily}" → "${resolved}"`);
        return resolved;
    }, [translatedTextFontFamily]);
    const formattedImageData = imageData && imageData.startsWith('data:')
        ? imageData
        : imageData ? `data:image/png;base64,${imageData}` : "";
    // Update image dimensions when the image loads or window resizes
    const updateImageDimensions = SP_REACT.useCallback(() => {
        if (imgRef.current) {
            const rect = imgRef.current.getBoundingClientRect();
            setImageDimensions(prev => {
                if (prev.width === rect.width && prev.height === rect.height)
                    return prev;
                logger.debug('Overlay', `Rendered image dimensions: ${rect.width}x${rect.height}`);
                return { width: rect.width, height: rect.height };
            });
            const natWidth = imgRef.current.naturalWidth;
            const natHeight = imgRef.current.naturalHeight;
            if (natWidth > 0 && natHeight > 0) {
                setNaturalDimensions(prev => {
                    if (prev.width === natWidth && prev.height === natHeight)
                        return prev;
                    logger.debug('Overlay', `Natural image dimensions: ${natWidth}x${natHeight}`);
                    return { width: natWidth, height: natHeight };
                });
            }
        }
    }, []);
    // Listen for window resize to update image dimensions
    SP_REACT.useEffect(() => {
        window.addEventListener('resize', updateImageDimensions);
        return () => {
            window.removeEventListener('resize', updateImageDimensions);
        };
    }, [updateImageDimensions]);
    // Function to calculate the scaling factor based on actual rendered image size
    function getScalingFactor() {
        // Use natural image dimensions as base (the actual screenshot resolution)
        // OCR coordinates are based on these dimensions
        const baseWidth = naturalDimensions.width;
        const baseHeight = naturalDimensions.height;
        // Use actual rendered image dimensions if available
        let renderedWidth = imageDimensions.width;
        let renderedHeight = imageDimensions.height;
        // Fallback: try to get dimensions from the img element directly
        if ((renderedWidth === 0 || renderedHeight === 0) && imgRef.current) {
            const rect = imgRef.current.getBoundingClientRect();
            renderedWidth = rect.width;
            renderedHeight = rect.height;
        }
        // Final fallback: use viewport dimensions if image not yet loaded
        if (renderedWidth === 0 || renderedHeight === 0) {
            // Calculate based on viewport while maintaining aspect ratio
            const viewportWidth = window.innerWidth;
            const viewportHeight = window.innerHeight;
            const aspectRatio = baseWidth / baseHeight;
            if (viewportWidth / viewportHeight > aspectRatio) {
                // Viewport is wider - height is the constraint
                renderedHeight = viewportHeight;
                renderedWidth = viewportHeight * aspectRatio;
            }
            else {
                // Viewport is taller - width is the constraint
                renderedWidth = viewportWidth;
                renderedHeight = viewportWidth / aspectRatio;
            }
        }
        return {
            widthFactor: renderedWidth / baseWidth,
            heightFactor: renderedHeight / baseHeight,
            generalFactor: ((renderedWidth / baseWidth) + (renderedHeight / baseHeight)) / 2
        };
    }
    return (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
        visible && window.SP_REACT.createElement(CompositionRequest$1, { level: UIComposition$1.Notification }),
        window.SP_REACT.createElement("div", { id: 'translation-overlay', style: {
                height: "100vh",
                width: "100vw",
                display: "flex",
                justifyContent: "center",
                alignItems: "center",
                zIndex: 7002,
                position: "fixed",
                top: 0,
                left: 0,
                backgroundColor: "transparent",
                opacity: visible ? 1 : 0,
                pointerEvents: visible ? "auto" : "none",
            } },
            imageData && (window.SP_REACT.createElement("div", { style: {
                    position: "relative",
                    maxHeight: "100vh",
                    maxWidth: "100vw",
                } },
                window.SP_REACT.createElement("img", { ref: imgRef, src: formattedImageData, onLoad: updateImageDimensions, style: {
                        maxHeight: "calc(100vh - 2px)",
                        maxWidth: "calc(100vw - 2px)",
                        objectFit: "contain",
                        backgroundColor: "rgba(0, 0, 0, 0.15)",
                        border: translationsVisible ? "1px solid #f44336" : "1px solid #ffc107",
                        imageRendering: "pixelated"
                    }, alt: "Screenshot" }),
                translationsVisible && (() => {
                    const { widthFactor, heightFactor, generalFactor } = getScalingFactor();
                    const pad = 4;
                    const gap = 2;
                    const imgWidth = imageDimensions.width || window.innerWidth;
                    // Pre-compute scaled rects for collision detection
                    const scaled = regions.map(region => ({
                        left: Math.round(region.rect.left * widthFactor - pad),
                        top: Math.round(region.rect.top * heightFactor - pad),
                        width: Math.round((region.rect.right - region.rect.left) * widthFactor + pad * 2),
                        height: Math.round((region.rect.bottom - region.rect.top) * heightFactor + pad * 2),
                    }));
                    // For each label, find how far it can grow in both directions
                    const expansionLimits = scaled.map((rect, i) => {
                        let maxRight = imgWidth;
                        let minLeft = 0;
                        const rectBottom = rect.top + rect.height;
                        for (let j = 0; j < scaled.length; j++) {
                            if (i === j)
                                continue;
                            const other = scaled[j];
                            // Check vertical overlap
                            if (rect.top < other.top + other.height && rectBottom > other.top) {
                                // Neighbor to the right
                                if (other.left > rect.left) {
                                    maxRight = Math.min(maxRight, other.left - gap);
                                }
                                // Neighbor to the left
                                if (other.left < rect.left) {
                                    minLeft = Math.max(minLeft, other.left + other.width + gap);
                                }
                            }
                        }
                        const maxExpandRight = Math.max(0, maxRight - (rect.left + rect.width));
                        const maxExpandLeft = Math.max(0, rect.left - minLeft);
                        return { maxExpandRight, maxExpandLeft };
                    });
                    return regions.map((region, index) => {
                        const fontSize = calculateFontSize(region, generalFactor, fontScale);
                        let displayText = region.translatedText || region.text;
                        // Redistribute text to fill original block height, minimising width
                        if (allowLabelGrowth) {
                            const lineHeight = fontSize * 1.15;
                            const availableHeight = scaled[index].height - 4;
                            const maxLines = Math.max(1, Math.floor(availableHeight / lineHeight));
                            const flatText = displayText.replace(/\n/g, ' ').trim();
                            if (maxLines > 1 && flatText.length > 0) {
                                displayText = redistributeText(flatText, maxLines);
                                logger.debug('Overlay', `[Redistribute] blockH=${scaled[index].height}px fontSize=${Math.round(fontSize)}px ` +
                                    `maxLines=${maxLines} → ${displayText.split('\n').length} lines: "${displayText}"`);
                            }
                        }
                        const alignmentStyles = translatedTextAlignment === 'right'
                            ? { textAlign: 'right', justifyContent: 'flex-end' }
                            : translatedTextAlignment === 'center'
                                ? { textAlign: 'center', justifyContent: 'center' }
                                : translatedTextAlignment === 'justify'
                                    ? { textAlign: 'justify', justifyContent: 'flex-start' }
                                    : { textAlign: 'left', justifyContent: 'flex-start' };
                        // Compute label position and size based on alignment and expansion
                        let labelMaxWidth = scaled[index].width;
                        // Use max-content width for right/center/justify so single-line
                        // blocks don't over-stretch while multi-line blocks still expand
                        let useMaxContentWidth = false;
                        // Position styles differ per alignment direction
                        let positionStyles = {
                            left: `${scaled[index].left}px`,
                        };
                        if (allowLabelGrowth) {
                            const { maxExpandRight, maxExpandLeft } = expansionLimits[index];
                            if (translatedTextAlignment === 'left') {
                                // Expand to the right — anchor left edge, auto-size width
                                labelMaxWidth = scaled[index].width + maxExpandRight;
                                positionStyles = { left: `${scaled[index].left}px` };
                            }
                            else if (translatedTextAlignment === 'right') {
                                // Expand to the left — anchor right edge
                                labelMaxWidth = scaled[index].width + maxExpandLeft;
                                useMaxContentWidth = true;
                                positionStyles = { right: `${imgWidth - (scaled[index].left + scaled[index].width)}px` };
                            }
                            else {
                                // Center or Justify — expand equally from center
                                const expandEach = Math.min(maxExpandLeft, maxExpandRight);
                                labelMaxWidth = scaled[index].width + expandEach * 2;
                                useMaxContentWidth = true;
                                const centerX = scaled[index].left + scaled[index].width / 2;
                                positionStyles = { left: `${centerX}px`, transform: 'translateX(-50%)' };
                            }
                        }
                        return (window.SP_REACT.createElement("div", { key: index, style: {
                                position: "absolute",
                                display: 'flex',
                                justifyContent: alignmentStyles.justifyContent,
                                alignItems: 'center',
                                ...positionStyles,
                                top: `${scaled[index].top}px`,
                                minWidth: `${scaled[index].width}px`,
                                ...(useMaxContentWidth
                                    ? { width: 'max-content', maxWidth: `${labelMaxWidth}px` }
                                    : { maxWidth: `${labelMaxWidth}px` }),
                                minHeight: `${scaled[index].height}px`,
                                boxSizing: 'border-box',
                                backgroundColor: "rgba(0, 0, 0, 0.8)",
                                color: "#FFFFFF",
                                padding: '1px 2px',
                                borderRadius: `${Math.round(6 * generalFactor)}px`,
                                fontSize: `${Math.round(fontSize)}px`,
                                lineHeight: '1.15',
                                ...resolveFontStyleCSS(translatedTextFontStyle),
                                fontFamily: translatedOverlayFontFamily,
                                wordWrap: "break-word",
                                whiteSpace: "pre-wrap",
                                animation: "fadeInTranslation 0.2s ease-out forwards"
                            } },
                            window.SP_REACT.createElement("div", { style: {
                                    width: '100%',
                                    textAlign: alignmentStyles.textAlign,
                                    textAlignLast: translatedTextAlignment === 'justify' ? 'justify' : alignmentStyles.textAlign,
                                } }, displayText)));
                    });
                })(),
                !translationsVisible && !loading && (window.SP_REACT.createElement("div", { style: {
                        position: "absolute",
                        bottom: "20px",
                        left: "20px",
                        background: "rgba(0, 0, 0, 0.7)",
                        padding: '10px',
                        borderRadius: '50%',
                        zIndex: 7003,
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                    } },
                    window.SP_REACT.createElement("svg", { width: "24", height: "24", viewBox: "0 0 24 24", fill: "none", stroke: "#ffc107", strokeWidth: "2", strokeLinecap: "round", strokeLinejoin: "round" },
                        window.SP_REACT.createElement("path", { d: "M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94" }),
                        window.SP_REACT.createElement("path", { d: "M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19" }),
                        window.SP_REACT.createElement("path", { d: "M1 1l22 22" }),
                        window.SP_REACT.createElement("path", { d: "M8.71 8.71a4 4 0 1 0 5.66 5.66" })))))),
            loading && processingStep && (window.SP_REACT.createElement("div", { style: {
                    display: "flex",
                    flexDirection: "row",
                    alignItems: "center",
                    position: "absolute",
                    bottom: "20px",
                    left: "20px",
                    color: "#ffffff",
                    background: "rgba(0, 0, 0, 0.7)",
                    padding: '8px 12px',
                    borderRadius: '20px',
                    maxWidth: "420px",
                    boxShadow: "0 2px 8px rgba(0,0,0,0.2)",
                    zIndex: 7003, // Higher than the image
                } },
                processingIsError ? (window.SP_REACT.createElement("svg", { width: "18", height: "18", viewBox: "0 0 24 24", fill: "#ff6b6b", style: { flexShrink: 0, marginRight: "10px" } },
                    window.SP_REACT.createElement("path", { d: "M1 21h22L12 2 1 21zm12-3h-2v-2h2v2zm0-4h-2v-4h2v4z" }))) : (window.SP_REACT.createElement("div", { className: "loader", style: {
                        border: "3px solid #f3f3f3",
                        borderTop: "3px solid #3498db",
                        borderRadius: "50%",
                        width: "16px",
                        height: "16px",
                        flexShrink: 0,
                        animation: "spin 1.5s linear infinite",
                        marginRight: "10px",
                    } })),
                window.SP_REACT.createElement("style", null, `
                        @keyframes spin {
                            0% { transform: rotate(0deg); }
                            100% { transform: rotate(360deg); }
                        }
                        @keyframes fadeInTranslation {
                            0% { opacity: 0; transform: translateY(10px); }
                            100% { opacity: 1; transform: translateY(0); }
                        }
                    `),
                window.SP_REACT.createElement("div", { style: { fontSize: "14px", whiteSpace: "pre-line", lineHeight: "1.3" } },
                    processingIsError ? processingStep : `${processingStep}...`,
                    !processingIsError && processingDetail && (window.SP_REACT.createElement("div", { style: { fontSize: "10px", opacity: 0.7 } }, processingDetail))))))));
};
// Main image overlay component
const ImageOverlay = ({ state, onDismiss }) => {
    const [visible, setVisible] = SP_REACT.useState(false);
    const [imageData, setImageData] = SP_REACT.useState("");
    const [regions, setRegions] = SP_REACT.useState([]);
    const [loading, setLoading] = SP_REACT.useState(false);
    const [processingStep, setProcessingStep] = SP_REACT.useState("");
    const [processingDetail, setProcessingDetail] = SP_REACT.useState("");
    const [processingIsError, setProcessingIsError] = SP_REACT.useState(false);
    const [translationsVisible, setTranslationsVisible] = SP_REACT.useState(true);
    const [fontScale, setFontScale] = SP_REACT.useState(1.0);
    const [allowLabelGrowth, setAllowLabelGrowth] = SP_REACT.useState(false);
    const [translatedTextAlignment, setTranslatedTextAlignment] = SP_REACT.useState('center');
    const [translatedTextFontFamily, setTranslatedTextFontFamily] = SP_REACT.useState("");
    const [translatedTextFontStyle, setTranslatedTextFontStyle] = SP_REACT.useState('normal');
    SP_REACT.useEffect(() => {
        logger.debug('ImageOverlay', 'useEffect mounting, registering state listener');
        const handleStateChanged = (isVisible, imgData, textRegions, isLoading, currProcessingStep, currProcessingDetail, currProcessingIsError, areTranslationsVisible, currentFontScale, currentAllowLabelGrowth, currentTranslatedTextAlignment, currentTranslatedTextFontFamily, currentTranslatedTextFontStyle) => {
            logger.debug('ImageOverlay', `State changed - visible=${isVisible}, imgData.length=${imgData?.length || 0}, regions=${textRegions?.length || 0}`);
            setVisible(isVisible);
            setImageData(imgData);
            setRegions(textRegions);
            setLoading(isLoading);
            setProcessingStep(currProcessingStep);
            setProcessingDetail(currProcessingDetail);
            setProcessingIsError(currProcessingIsError);
            setTranslationsVisible(areTranslationsVisible);
            setFontScale(currentFontScale);
            setAllowLabelGrowth(currentAllowLabelGrowth);
            setTranslatedTextAlignment(currentTranslatedTextAlignment);
            setTranslatedTextFontFamily(currentTranslatedTextFontFamily);
            setTranslatedTextFontStyle(currentTranslatedTextFontStyle);
        };
        state.onStateChanged(handleStateChanged);
        const suspend_register = SteamClient.User.RegisterForPrepareForSystemSuspendProgress(() => {
            onDismiss();
        });
        return () => {
            state.offStateChanged(handleStateChanged);
            suspend_register.unregister();
        };
    }, [state, onDismiss]);
    return (window.SP_REACT.createElement(TranslatedTextOverlay, { visible: visible, imageData: imageData, regions: regions, loading: loading, processingStep: processingStep, processingDetail: processingDetail, processingIsError: processingIsError, translationsVisible: translationsVisible, fontScale: fontScale, allowLabelGrowth: allowLabelGrowth, translatedTextAlignment: translatedTextAlignment, translatedTextFontFamily: translatedTextFontFamily, translatedTextFontStyle: translatedTextFontStyle }));
};

class NetworkError extends Error {
    constructor(message) {
        super(message);
        this.name = 'NetworkError';
    }
}
class ApiKeyError extends Error {
    constructor(message) {
        super(message);
        this.name = 'ApiKeyError';
    }
}
class RateLimitError extends Error {
    constructor(message) {
        super(message);
        this.name = 'RateLimitError';
    }
}
class ModelNotAvailableError extends Error {
    constructor(message) {
        super(message);
        this.name = 'ModelNotAvailableError';
    }
}
function isErrorResponse$1(value) {
    return typeof value === 'object' && value !== null && 'error' in value && 'message' in value;
}
// Union-Find with path compression and union by rank.
// Enables transitive merging: if A merges with B and B with C,
// all three end up in the same group regardless of check order.
class UnionFind {
    constructor(n) {
        this.parent = Array.from({ length: n }, (_, i) => i);
        this.rank = new Array(n).fill(0);
    }
    find(x) {
        while (this.parent[x] !== x) {
            this.parent[x] = this.parent[this.parent[x]];
            x = this.parent[x];
        }
        return x;
    }
    union(x, y) {
        const px = this.find(x), py = this.find(y);
        if (px === py)
            return;
        if (this.rank[px] < this.rank[py]) {
            this.parent[px] = py;
        }
        else if (this.rank[px] > this.rank[py]) {
            this.parent[py] = px;
        }
        else {
            this.parent[py] = px;
            this.rank[px]++;
        }
    }
    getGroups() {
        const groups = new Map();
        for (let i = 0; i < this.parent.length; i++) {
            const root = this.find(i);
            if (!groups.has(root))
                groups.set(root, []);
            groups.get(root).push(i);
        }
        return groups;
    }
}
function computeMedianHeight(regions) {
    const heights = regions
        .map(r => r.rect.bottom - r.rect.top)
        .filter(h => h > 0)
        .sort((a, b) => a - b);
    if (heights.length === 0)
        return 20;
    return heights[Math.floor(heights.length / 2)];
}
class TextRecognizer {
    constructor() {
        this.confidenceThreshold = 0.6;
        this.groupingPower = 0.25;
        logger.info('TextRecognizer', 'TextRecognizer initialized');
    }
    setConfidenceThreshold(threshold) {
        this.confidenceThreshold = threshold;
    }
    getConfidenceThreshold() {
        return this.confidenceThreshold;
    }
    setGroupingPower(power) {
        this.groupingPower = Math.max(0.25, Math.min(1.0, power));
        logger.debug('TextRecognizer', `Grouping power set to ${this.groupingPower}`);
    }
    getGroupingPower() {
        return this.groupingPower;
    }
    // Phase 1: group OCR boxes that sit on the same horizontal line.
    // Checks: Y-center alignment, height compatibility, horizontal gap.
    // All thresholds relative to median line height -- never absolute pixels.
    assembleLines(regions, medianH) {
        const n = regions.length;
        if (n <= 1)
            return [...regions];
        const uf = new UnionFind(n);
        // Sort by top edge so we can break early on large vertical gaps
        const indexed = regions.map((r, i) => ({ r, i }));
        indexed.sort((a, b) => a.r.rect.top - b.r.rect.top);
        for (let a = 0; a < n; a++) {
            for (let b = a + 1; b < n; b++) {
                const ra = indexed[a].r, rb = indexed[b].r;
                // If the top of b is way past the bottom of a, everything
                // further is even lower -- stop checking
                if (rb.rect.top - ra.rect.bottom > medianH)
                    break;
                const yCenterA = (ra.rect.top + ra.rect.bottom) / 2;
                const yCenterB = (rb.rect.top + rb.rect.bottom) / 2;
                if (Math.abs(yCenterA - yCenterB) > 0.5 * medianH)
                    continue;
                const hA = ra.rect.bottom - ra.rect.top;
                const hB = rb.rect.bottom - rb.rect.top;
                if (hA > 0 && hB > 0 && Math.max(hA, hB) / Math.min(hA, hB) > 1.5)
                    continue;
                // Horizontal gap: positive means space between boxes, negative means overlap
                const gap = Math.max(ra.rect.left, rb.rect.left) - Math.min(ra.rect.right, rb.rect.right);
                if (gap > 1.0 * medianH)
                    continue;
                uf.union(indexed[a].i, indexed[b].i);
            }
        }
        const groups = Array.from(uf.getGroups().values());
        return this.extractMergedRegions(groups, regions, "horizontal", medianH);
    }
    // Phase 2: group text lines into paragraphs.
    // Checks: vertical gap, horizontal overlap ratio, height compatibility.
    // groupingPower scales the vertical gap threshold.
    assembleParagraphs(lines, medianH) {
        const n = lines.length;
        if (n <= 1)
            return [...lines];
        const power = this.groupingPower;
        const uf = new UnionFind(n);
        const indexed = lines.map((l, i) => ({ l, i }));
        indexed.sort((a, b) => a.l.rect.top - b.l.rect.top);
        for (let a = 0; a < n; a++) {
            for (let b = a + 1; b < n; b++) {
                const la = indexed[a].l, lb = indexed[b].l;
                // Early exit on large vertical distance
                if (lb.rect.top - la.rect.bottom > 3.0 * medianH * power)
                    break;
                // Vertical gap
                const vertGap = Math.max(0, lb.rect.top - la.rect.bottom);
                if (vertGap > 1.5 * medianH * power)
                    continue;
                // Horizontal overlap ratio -- how much do the two lines share horizontally?
                const overlapLeft = Math.max(la.rect.left, lb.rect.left);
                const overlapRight = Math.min(la.rect.right, lb.rect.right);
                const overlapWidth = Math.max(0, overlapRight - overlapLeft);
                const widthA = la.rect.right - la.rect.left;
                const widthB = lb.rect.right - lb.rect.left;
                const minWidth = Math.min(widthA, widthB);
                if (minWidth > 0 && overlapWidth / minWidth < 0.3)
                    continue;
                // Height ratio (font size similarity).
                // For multi-line regions (e.g. OCR returned a block spanning
                // multiple visual lines), normalize by estimated line count
                // so the comparison reflects per-line font size, not total height.
                const hA = la.rect.bottom - la.rect.top;
                const hB = lb.rect.bottom - lb.rect.top;
                const estLinesA = Math.max(1, Math.round(hA / medianH));
                const estLinesB = Math.max(1, Math.round(hB / medianH));
                const lineHA = hA / estLinesA;
                const lineHB = hB / estLinesB;
                if (lineHA > 0 && lineHB > 0 && Math.max(lineHA, lineHB) / Math.min(lineHA, lineHB) > 1.4)
                    continue;
                // Alignment check: reject pairs whose left edges, right edges,
                // AND horizontal centers are all far apart.  This allows
                // left-aligned, right-aligned, and center-aligned text to merge
                // while still separating unrelated UI elements.
                const leftEdgeDist = Math.abs(la.rect.left - lb.rect.left);
                const rightEdgeDist = Math.abs(la.rect.right - lb.rect.right);
                const centerA = (la.rect.left + la.rect.right) / 2;
                const centerB = (lb.rect.left + lb.rect.right) / 2;
                const centerDist = Math.abs(centerA - centerB);
                const edgeThresh = 2.0 * medianH;
                const centerThresh = 1.0 * medianH;
                if (leftEdgeDist > edgeThresh && rightEdgeDist > edgeThresh && centerDist > centerThresh)
                    continue;
                // Width ratio: a very narrow line next to a wide one is probably
                // a stray label, not a continuation. Skip this check for the
                // shorter of two lines when it could be a paragraph's last line
                // (i.e. when it's the lower one)
                const maxWidth = Math.max(widthA, widthB);
                if (maxWidth > 0) {
                    const widthRatio = minWidth / maxWidth;
                    // If the narrow line is the upper one, it's unlikely a paragraph tail
                    const narrowIsUpper = (widthA < widthB && la.rect.top < lb.rect.top) ||
                        (widthB < widthA && lb.rect.top < la.rect.top);
                    if (widthRatio < 0.15 && narrowIsUpper)
                        continue;
                }
                // Background color: different background = different UI element.
                // Uses simple RGB distance. Threshold of 60 catches obvious
                // differences (dark vs light, blue vs gray) while allowing
                // minor shading variation within the same panel.
                if (la.bgColor && lb.bgColor) {
                    const dr = la.bgColor[0] - lb.bgColor[0];
                    const dg = la.bgColor[1] - lb.bgColor[1];
                    const db = la.bgColor[2] - lb.bgColor[2];
                    const colorDist = Math.sqrt(dr * dr + dg * dg + db * db);
                    if (colorDist > 60)
                        continue;
                }
                uf.union(indexed[a].i, indexed[b].i);
            }
        }
        const groups = Array.from(uf.getGroups().values());
        const refined = this.splitOvermerged(groups, lines, medianH);
        logger.debug('TextRecognizer', `Auto-glue: Split pass refined ${groups.length} groups into ${refined.length} groups`);
        return this.extractMergedRegions(refined, lines, "vertical", medianH);
    }
    // Post-merge split pass: break apart over-merged groups by checking
    // for internal gap inconsistencies and separator lines.
    splitOvermerged(groups, lines, medianH) {
        const result = [];
        for (const group of groups) {
            // Groups of 1-2 lines can't have internal inconsistencies
            if (group.length <= 2) {
                result.push(group);
                continue;
            }
            // Sort constituent lines top-to-bottom
            const sorted = [...group].sort((a, b) => {
                const yA = (lines[a].rect.top + lines[a].rect.bottom) / 2;
                const yB = (lines[b].rect.top + lines[b].rect.bottom) / 2;
                return yA - yB;
            });
            // Compute vertical gaps between consecutive lines
            const gaps = [];
            for (let i = 0; i < sorted.length - 1; i++) {
                gaps.push(Math.max(0, lines[sorted[i + 1]].rect.top - lines[sorted[i]].rect.bottom));
            }
            const sortedGaps = [...gaps].sort((a, b) => a - b);
            const medianGap = sortedGaps[Math.floor(sortedGaps.length / 2)];
            // Find indices after which to split (between sorted[i] and sorted[i+1])
            const splitAfter = new Set();
            for (let i = 0; i < gaps.length; i++) {
                // Gap inconsistency: this gap is much larger than the group's typical gap,
                // and large enough to not just be bounding box jitter
                if (medianGap > 0 && gaps[i] > 2.5 * medianGap && gaps[i] > 0.8 * medianH) {
                    splitAfter.add(i);
                }
                // When lines nearly overlap (medianGap ~ 0), any real gap stands out
                if (medianGap <= 1 && gaps[i] > 1.2 * medianH) {
                    splitAfter.add(i);
                }
                // Separator line: text is just dashes, equals, underscores, etc.
                const text = lines[sorted[i]].text.trim();
                if (/^[-=_*~.]{3,}$/.test(text)) {
                    if (i > 0)
                        splitAfter.add(i - 1);
                    splitAfter.add(i);
                }
                if (i + 1 < sorted.length) {
                    const nextText = lines[sorted[i + 1]].text.trim();
                    if (/^[-=_*~.]{3,}$/.test(nextText)) {
                        splitAfter.add(i);
                    }
                }
            }
            if (splitAfter.size === 0) {
                result.push(sorted);
                continue;
            }
            // Build sub-groups at split points
            let subGroup = [];
            for (let i = 0; i < sorted.length; i++) {
                subGroup.push(sorted[i]);
                if (splitAfter.has(i)) {
                    if (subGroup.length > 0)
                        result.push(subGroup);
                    subGroup = [];
                }
            }
            if (subGroup.length > 0)
                result.push(subGroup);
        }
        return result;
    }
    // Extract connected components from Union-Find, merge text and bounding boxes.
    extractMergedRegions(groups, regions, direction, medianH) {
        const merged = [];
        for (const indices of groups) {
            if (indices.length === 1) {
                merged.push({ ...regions[indices[0]] });
                continue;
            }
            // Sort: left-to-right for horizontal, top-to-bottom for vertical
            const sorted = indices
                .map(i => regions[i])
                .sort((a, b) => {
                if (direction === "horizontal")
                    return a.rect.left - b.rect.left;
                const yCenterA = (a.rect.top + a.rect.bottom) / 2;
                const yCenterB = (b.rect.top + b.rect.bottom) / 2;
                return yCenterA - yCenterB;
            });
            let combinedText = sorted[0].text;
            let combinedTranslatedText = sorted[0].translatedText ?? null;
            let combinedRect = { ...sorted[0].rect };
            let isDialog = sorted[0].isDialog;
            let confidenceSum = sorted[0].confidence ?? 0;
            let confidenceCount = sorted[0].confidence !== undefined ? 1 : 0;
            // Accumulate bgColor for averaging
            let colorR = 0, colorG = 0, colorB = 0, colorCount = 0;
            if (sorted[0].bgColor) {
                colorR += sorted[0].bgColor[0];
                colorG += sorted[0].bgColor[1];
                colorB += sorted[0].bgColor[2];
                colorCount++;
            }
            for (let i = 1; i < sorted.length; i++) {
                const region = sorted[i];
                const separator = direction === "horizontal"
                    ? this.getHorizontalSpacing(sorted[i - 1], region, medianH)
                    : "\n";
                combinedText += separator + region.text;
                if (combinedTranslatedText !== null && region.translatedText) {
                    combinedTranslatedText += separator + region.translatedText;
                }
                combinedRect = {
                    left: Math.min(combinedRect.left, region.rect.left),
                    top: Math.min(combinedRect.top, region.rect.top),
                    right: Math.max(combinedRect.right, region.rect.right),
                    bottom: Math.max(combinedRect.bottom, region.rect.bottom),
                };
                isDialog = isDialog || region.isDialog;
                if (region.confidence !== undefined) {
                    confidenceSum += region.confidence;
                    confidenceCount++;
                }
                if (region.bgColor) {
                    colorR += region.bgColor[0];
                    colorG += region.bgColor[1];
                    colorB += region.bgColor[2];
                    colorCount++;
                }
            }
            const result = {
                text: combinedText,
                rect: combinedRect,
                isDialog,
            };
            if (combinedTranslatedText !== null) {
                result.translatedText = combinedTranslatedText;
            }
            if (confidenceCount > 0) {
                result.confidence = confidenceSum / confidenceCount;
            }
            if (colorCount > 0) {
                result.bgColor = [
                    Math.round(colorR / colorCount),
                    Math.round(colorG / colorCount),
                    Math.round(colorB / colorCount)
                ];
            }
            merged.push(result);
        }
        return merged;
    }
    // Spacing for horizontal (same-line) merging
    getHorizontalSpacing(a, b, medianH) {
        // No space before closing punctuation
        if (/^[.,!?:;)\]"'\u3002\u3001\uFF09\u300D\u300F\u3011\u3009\u300B)]/.test(b.text)) {
            return "";
        }
        // No space after opening punctuation
        if (/[(\["'\uFF08\u300C\u300E\u3010\u3008\u300A(]\s*$/.test(a.text)) {
            return "";
        }
        const cjkPattern = /[\u3000-\u9FFF\uAC00-\uD7AF\uF900-\uFAFF\uFF00-\uFFEF]/;
        if (cjkPattern.test(a.text.slice(-1)) || cjkPattern.test(b.text.charAt(0))) {
            return "";
        }
        return " ";
    }
    // Post-merge dialog detection on complete text blocks
    detectDialog(region) {
        if (region.isDialog)
            return true;
        const text = region.text;
        let score = 0;
        if (/"[^"]+"/g.test(text) || /[\u00AB\u00BB]/g.test(text))
            score += 2;
        const excl = (text.match(/!/g) || []).length;
        const quest = (text.match(/\?/g) || []).length;
        score += (excl + quest) * 0.5;
        if (/[A-Z][^.!?]+[.!?]\s*"/.test(text) || /"[^"]+"\s*[A-Z][^.!?]+[.!?]/.test(text)) {
            score += 2;
        }
        score += Math.min(2, text.length / 50);
        if (text.includes('\n'))
            score += 1.5;
        return score >= 3;
    }
    // Resolve overlapping rects in the final region list.
    // Merged paragraphs can have union rects that extend into neighbors.
    // For each overlapping pair: absorb the smaller if mostly contained,
    // otherwise trim the smaller region's rect at the overlapping edge.
    resolveOverlaps(regions) {
        if (regions.length <= 1)
            return regions;
        // Work on copies so we can mutate rects
        const result = regions.map(r => ({ ...r, rect: { ...r.rect } }));
        // Sort by area descending so larger (merged) regions take priority
        const byArea = result
            .map((r, i) => ({ i, area: (r.rect.right - r.rect.left) * (r.rect.bottom - r.rect.top) }))
            .sort((a, b) => b.area - a.area);
        const removed = new Set();
        for (let ai = 0; ai < byArea.length; ai++) {
            const idxA = byArea[ai].i;
            if (removed.has(idxA))
                continue;
            const a = result[idxA].rect;
            for (let bi = ai + 1; bi < byArea.length; bi++) {
                const idxB = byArea[bi].i;
                if (removed.has(idxB))
                    continue;
                const b = result[idxB].rect;
                // Check overlap
                const oLeft = Math.max(a.left, b.left);
                const oTop = Math.max(a.top, b.top);
                const oRight = Math.min(a.right, b.right);
                const oBottom = Math.min(a.bottom, b.bottom);
                if (oLeft >= oRight || oTop >= oBottom)
                    continue;
                const overlapArea = (oRight - oLeft) * (oBottom - oTop);
                const bArea = (b.right - b.left) * (b.bottom - b.top);
                // If b is mostly inside a, absorb it
                if (bArea > 0 && overlapArea / bArea > 0.5) {
                    removed.add(idxB);
                    continue;
                }
                // Partial overlap: trim b at the edge that loses the least area
                const bW = b.right - b.left;
                const bH = b.bottom - b.top;
                const oW = oRight - oLeft;
                const oH = oBottom - oTop;
                // For each possible trim, how much of b's area is lost?
                // Only consider trims where the overlap is actually on that edge
                const candidates = [];
                // Trim b's left edge rightward (overlap is on b's left side)
                if (oLeft === b.left || oLeft - b.left < oW) {
                    candidates.push({ edge: 'left', loss: oW * bH });
                }
                // Trim b's right edge leftward (overlap is on b's right side)
                if (oRight === b.right || b.right - oRight < oW) {
                    candidates.push({ edge: 'right', loss: oW * bH });
                }
                // Trim b's top edge downward
                if (oTop === b.top || oTop - b.top < oH) {
                    candidates.push({ edge: 'top', loss: bW * oH });
                }
                // Trim b's bottom edge upward
                if (oBottom === b.bottom || b.bottom - oBottom < oH) {
                    candidates.push({ edge: 'bottom', loss: bW * oH });
                }
                if (candidates.length === 0) {
                    removed.add(idxB);
                    continue;
                }
                // Pick the trim with least area loss
                candidates.sort((x, y) => x.loss - y.loss);
                switch (candidates[0].edge) {
                    case 'left':
                        b.left = oRight;
                        break;
                    case 'right':
                        b.right = oLeft;
                        break;
                    case 'top':
                        b.top = oBottom;
                        break;
                    case 'bottom':
                        b.bottom = oTop;
                        break;
                }
                // If trimmed to nothing useful, remove it
                if (b.right - b.left < 5 || b.bottom - b.top < 5) {
                    removed.add(idxB);
                }
            }
        }
        return result.filter((_, i) => !removed.has(i));
    }
    applyAutoGlue(regions) {
        if (!regions || regions.length <= 1)
            return regions;
        logger.debug('TextRecognizer', `Auto-glue: Processing ${regions.length} regions`);
        const medianH = computeMedianHeight(regions);
        logger.debug('TextRecognizer', `Auto-glue: Median line height = ${medianH}px, grouping power = ${this.groupingPower}`);
        // Phase 1: assemble word-level boxes into lines
        const lines = this.assembleLines(regions, medianH);
        logger.debug('TextRecognizer', `Auto-glue: Phase 1 produced ${lines.length} lines from ${regions.length} boxes`);
        // Phase 2: assemble lines into paragraphs
        const paragraphs = this.assembleParagraphs(lines, medianH);
        logger.debug('TextRecognizer', `Auto-glue: Phase 2 produced ${paragraphs.length} paragraphs from ${lines.length} lines`);
        // Sort into reading order: top-to-bottom, left-to-right with tolerance
        paragraphs.sort((a, b) => {
            const yCenterA = (a.rect.top + a.rect.bottom) / 2;
            const yCenterB = (b.rect.top + b.rect.bottom) / 2;
            if (Math.abs(yCenterA - yCenterB) < 0.3 * medianH) {
                return a.rect.left - b.rect.left;
            }
            return yCenterA - yCenterB;
        });
        // Post-merge: dialog detection on complete blocks
        const annotated = paragraphs.map(p => ({
            ...p,
            isDialog: this.detectDialog(p),
        }));
        // Final pass: resolve any overlapping rects caused by merge union rects
        const resolved = this.resolveOverlaps(annotated);
        if (resolved.length !== annotated.length) {
            logger.debug('TextRecognizer', `Auto-glue: Overlap resolution reduced ${annotated.length} to ${resolved.length} regions`);
        }
        return resolved;
    }
    filterUntranslatableText(regions) {
        if (!regions || regions.length === 0)
            return regions;
        logger.debug('TextRecognizer', `Filtering untranslatable text from ${regions.length} regions`);
        return regions.filter(region => {
            const text = region.text.trim();
            if (!text)
                return false;
            if (region.confidence !== undefined && region.confidence < this.confidenceThreshold) {
                return false;
            }
            if (text.length === 1)
                return false;
            // Numeric patterns
            if (/^\d+$/.test(text) ||
                /^[\d\/]+$/.test(text) ||
                /^[\d\s]+$/.test(text) ||
                /^[\d\s\+\-\*\/\=\(\)]+$/.test(text) ||
                /^[\d\s,\.:\/\-]+$/.test(text) ||
                /^[+-]?\s*\d+\s*%$/.test(text) ||
                /^\d{1,2}:\d{1,2}(:\d{1,2})?\s*(AM|PM|am|pm|a\.m\.|p\.m\.)?$/.test(text) ||
                /^([WDL]\d+\s*)+$|^\d+[\-:]\d+$/.test(text)) {
                return false;
            }
            // Punctuation-only
            if (/^[^\p{L}\p{N}\s]+$/u.test(text) || /^[_\-\+\*\/\=\.,;:!?@#$%^&*()[\]{}|<>~`"']+$/.test(text)) {
                return false;
            }
            // Decorative separators
            if (/^[-=_*]{3,}$/.test(text) || /^[~\u2022]{3,}$/.test(text)) {
                return false;
            }
            // Very short non-words (Latin only -- CJK carries more meaning per character)
            const hasNonLatinLetter = /[^\x00-\x7F]/.test(text) && /\p{L}/u.test(text);
            if (text.length <= 3 && !hasNonLatinLetter && !/^(OK|GO|NO|YES|ON|OFF|NEW|ADD|ALL|BUY|THE|AND|FOR|TO|IN|IS|IT|BE|BY)$/i.test(text)) {
                return false;
            }
            // File extensions
            if (/^\.[a-zA-Z0-9]{2,4}$/.test(text))
                return false;
            // Social media tags
            if (/^[@#][a-zA-Z0-9_]+$/.test(text))
                return false;
            // URLs and emails
            if (/^(https?:\/\/|www\.|[\w.-]+@)/.test(text))
                return false;
            // Game UI patterns
            if (/^[xX\u00D7]\d+$|^\d+[xX\u00D7]$/.test(text) ||
                /^\d+\s*\/\s*\d+$|^\d+\s+of\s+\d+$/i.test(text) ||
                /^(LVL|LEVEL)\s*\d+$/i.test(text) ||
                /^(HP|MP|SP|AP)\s*\d+$/i.test(text) ||
                /^(STR|DEX|INT|WIS|CHA|CON|AGI)\s*\d+$/i.test(text)) {
                return false;
            }
            return true;
        });
    }
    async recognizeText(imageData) {
        try {
            const response = await call('recognize_text', imageData);
            if (response) {
                const regions = response;
                logger.info('TextRecognizer', `Got ${regions.length} raw text regions from OCR`);
                const mergedRegions = this.applyAutoGlue(regions);
                const filteredRegions = this.filterUntranslatableText(mergedRegions);
                logger.info('TextRecognizer', `After filtering, ${filteredRegions.length} regions remain`);
                return filteredRegions;
            }
            logger.error('TextRecognizer', 'Failed to recognize text');
            return [];
        }
        catch (error) {
            logger.error('TextRecognizer', 'Text recognition error', error);
            return [];
        }
    }
    async recognizeTextFile(imagePath) {
        try {
            const response = await call('recognize_text_file', imagePath);
            if (response) {
                if (isErrorResponse$1(response)) {
                    const errorResponse = response;
                    if (errorResponse.error === 'network_error') {
                        throw new NetworkError(errorResponse.message);
                    }
                    if (errorResponse.error === 'api_key_error') {
                        throw new ApiKeyError(errorResponse.message);
                    }
                    if (errorResponse.error === 'rate_limit_error') {
                        throw new RateLimitError(errorResponse.message);
                    }
                    if (errorResponse.error === 'model_not_available') {
                        throw new ModelNotAvailableError(errorResponse.message);
                    }
                    logger.error('TextRecognizer', `Error from backend: ${errorResponse.error} - ${errorResponse.message}`);
                    return [];
                }
                const regions = response;
                logger.info('TextRecognizer', `Got ${regions.length} regions from file-based OCR`);
                const mergedRegions = this.applyAutoGlue(regions);
                const filteredRegions = this.filterUntranslatableText(mergedRegions);
                logger.info('TextRecognizer', `After filtering, ${filteredRegions.length} regions remain`);
                return filteredRegions;
            }
            logger.error('TextRecognizer', 'Failed to recognize text (file-based)');
            return [];
        }
        catch (error) {
            if (error instanceof NetworkError || error instanceof ApiKeyError || error instanceof RateLimitError || error instanceof ModelNotAvailableError) {
                throw error;
            }
            logger.error('TextRecognizer', 'Text recognition error (file-based)', error);
            return [];
        }
    }
}

// TextTranslator.tsx
// Type guard to check if response is an error
function isErrorResponse(value) {
    return typeof value === 'object' && value !== null && 'error' in value && 'message' in value;
}
class TextTranslator {
    constructor(initialLanguage = "en") {
        this.inputLanguage = "auto"; // Default to auto-detect
        this.targetLanguage = initialLanguage;
    }
    setTargetLanguage(language) {
        this.targetLanguage = language;
    }
    getTargetLanguage() {
        return this.targetLanguage;
    }
    // New methods for input language
    setInputLanguage(language) {
        this.inputLanguage = language;
    }
    getInputLanguage() {
        return this.inputLanguage;
    }
    async translateText(textRegions) {
        try {
            // Skip translation if there's nothing to translate
            if (!textRegions.length) {
                return [];
            }
            // Call the Python backend method for translation, now including input language
            const response = await call('translate_text', textRegions, this.targetLanguage, this.inputLanguage);
            if (response) {
                // Check for error response (network error, API key error)
                if (isErrorResponse(response)) {
                    const errorResponse = response;
                    if (errorResponse.error === 'network_error') {
                        logger.error('TextTranslator', `Network error: ${errorResponse.message}`);
                        throw new NetworkError(errorResponse.message);
                    }
                    if (errorResponse.error === 'api_key_error') {
                        logger.error('TextTranslator', `API key error: ${errorResponse.message}`);
                        throw new ApiKeyError(errorResponse.message);
                    }
                    if (errorResponse.error === 'model_not_available') {
                        logger.error('TextTranslator', `Model not available: ${errorResponse.message}`);
                        throw new ModelNotAvailableError(errorResponse.message);
                    }
                    if (errorResponse.error === 'rate_limit_error') {
                        logger.error('TextTranslator', `Rate limit error: ${errorResponse.message}`);
                        throw new RateLimitError(errorResponse.message);
                    }
                    logger.error('TextTranslator', `Error from backend: ${errorResponse.error} - ${errorResponse.message}`);
                    // Return original text on error
                    return textRegions.map(region => ({
                        ...region,
                        translatedText: region.text
                    }));
                }
                return response;
            }
            logger.error('TextTranslator', 'Failed to translate text');
            // If translation fails, at least return the original text
            return textRegions.map(region => ({
                ...region,
                translatedText: region.text
            }));
        }
        catch (error) {
            // Re-throw known errors to be handled by caller
            if (error instanceof NetworkError || error instanceof ApiKeyError || error instanceof RateLimitError || error instanceof ModelNotAvailableError) {
                throw error;
            }
            logger.error('TextTranslator', 'Text translation error', error);
            // Return the original text if translation fails
            return textRegions.map(region => ({
                ...region,
                translatedText: region.text
            }));
        }
    }
}

var InputMode;
(function (InputMode) {
    InputMode[InputMode["L4_BUTTON"] = 0] = "L4_BUTTON";
    InputMode[InputMode["R4_BUTTON"] = 1] = "R4_BUTTON";
    InputMode[InputMode["L5_BUTTON"] = 2] = "L5_BUTTON";
    InputMode[InputMode["R5_BUTTON"] = 3] = "R5_BUTTON";
    InputMode[InputMode["L4_R4_COMBO"] = 4] = "L4_R4_COMBO";
    InputMode[InputMode["L5_R5_COMBO"] = 5] = "L5_R5_COMBO";
    InputMode[InputMode["TOUCHPAD_COMBO"] = 6] = "TOUCHPAD_COMBO";
    InputMode[InputMode["L3_BUTTON"] = 7] = "L3_BUTTON";
    InputMode[InputMode["R3_BUTTON"] = 8] = "R3_BUTTON";
    InputMode[InputMode["L3_R3_COMBO"] = 9] = "L3_R3_COMBO"; // L3 + R3 combination
})(InputMode || (InputMode = {}));
var ActionType;
(function (ActionType) {
    ActionType[ActionType["TRANSLATE"] = 0] = "TRANSLATE";
    ActionType[ActionType["DISMISS"] = 1] = "DISMISS";
    ActionType[ActionType["TOGGLE_TRANSLATIONS"] = 2] = "TOGGLE_TRANSLATIONS";
})(ActionType || (ActionType = {}));
// Mapping from hidraw button names to Button enum
const HIDRAW_BUTTON_MAP = {
    'A': 7 /* Button.A */,
    'B': 5 /* Button.B */,
    'X': 6 /* Button.X */,
    'Y': 4 /* Button.Y */,
    'L1': 3 /* Button.L1 */,
    'R1': 2 /* Button.R1 */,
    'L2': 1 /* Button.L2 */,
    'R2': 0 /* Button.R2 */,
    'L3': 22 /* Button.L3 */,
    'R3': 26 /* Button.R3 */,
    'L4': 41 /* Button.L4 */,
    'R4': 42 /* Button.R4 */,
    'L5': 15 /* Button.L5 */,
    'R5': 16 /* Button.R5 */,
    'DPAD_UP': 8 /* Button.DPAD_UP */,
    'DPAD_DOWN': 11 /* Button.DPAD_DOWN */,
    'DPAD_LEFT': 10 /* Button.DPAD_LEFT */,
    'DPAD_RIGHT': 9 /* Button.DPAD_RIGHT */,
    'SELECT': 12 /* Button.SELECT */,
    'START': 14 /* Button.START */,
    'STEAM': 13 /* Button.STEAM */,
    'QAM': 50 /* Button.QUICK_ACCESS_MENU */,
    'LEFT_PAD_TOUCH': 19 /* Button.LEFT_TOUCHPAD_TOUCH */,
    'RIGHT_PAD_TOUCH': 20 /* Button.RIGHT_TOUCHPAD_TOUCH */,
    'LEFT_PAD_CLICK': 17 /* Button.LEFT_TOUCHPAD_CLICK */,
    'RIGHT_PAD_CLICK': 18 /* Button.RIGHT_TOUCHPAD_CLICK */,
};
class Input {
    constructor() {
        this.onButtonsPressedListeners = [];
        this.onProgressListeners = [];
        this.touchStartTime = null;
        this.pollingInterval = null;
        this.pollingRate = 100; // 10Hz polling
        // Health tracking
        this.lastInputTime = 0;
        this.healthCheckInterval = null;
        this.inputHealthy = true;
        this.healthCheckEnabled = true;
        // Button state tracking (reusing for compatibility)
        this.leftTouchpadTouched = false;
        this.rightTouchpadTouched = false;
        this.timeoutId = null;
        this.animationFrameId = null;
        this.inCooldown = false;
        this.lastActionTime = 0;
        this.clearCooldownTimeoutId = null;
        this.cooldownDuration = 150; // 0.15s cooldown
        this.inputMode = InputMode.L5_BUTTON;
        this.translateHoldTime = 1000;
        this.dismissHoldTime = 500;
        this.overlayVisible = false;
        this.waitingForRelease = false;
        // Track previous buttons state
        this.previousButtons = [];
        // Enabled state
        this.enabled = true;
        // Quick toggle setting - allows right button to toggle overlay in combo modes
        this.quickToggleEnabled = false;
        // Track currently pressed buttons (using Button enum values now)
        this.currentlyPressedButtons = new Set();
        logger.info('Input', 'Initializing with hidraw-based detection');
        this.startHidrawPolling();
        this.startHealthCheck();
    }
    // Start polling the backend for hidraw button state
    startHidrawPolling() {
        logger.info('Input', 'Starting hidraw button state polling');
        this.pollingInterval = setInterval(async () => {
            await this.pollButtonState();
        }, this.pollingRate);
        this.inputHealthy = true;
        logger.info('Input', 'Hidraw polling started');
    }
    // Poll the backend for complete button state (not individual events)
    // This is more reliable when multiple frontend instances are polling
    async pollButtonState() {
        if (!this.enabled)
            return;
        try {
            const result = await call('get_hidraw_button_state');
            if (result && result.success && result.buttons) {
                this.handleButtonState(result.buttons);
            }
        }
        catch (error) {
            // Silently handle polling errors to avoid log spam
            // Health check will handle reconnection if needed
        }
    }
    // Handle the complete button state from backend
    handleButtonState(buttonNames) {
        this.lastInputTime = Date.now();
        this.inputHealthy = true;
        // Convert button names to Button enum values
        const newPressedButtons = new Set();
        for (const name of buttonNames) {
            const button = HIDRAW_BUTTON_MAP[name];
            if (button !== undefined) {
                newPressedButtons.add(button);
            }
        }
        // Check if the button state actually changed
        const stateChanged = this.hasButtonSetChanged(newPressedButtons);
        if (stateChanged) {
            // Log the change
            const buttonList = Array.from(newPressedButtons).map(b => {
                const entry = Object.entries(HIDRAW_BUTTON_MAP).find(([_, v]) => v === b);
                return entry ? entry[0] : b.toString();
            }).join(',');
            logger.debug('Input', `Button state changed: [${buttonList}]`);
            // Update the current state
            this.currentlyPressedButtons = newPressedButtons;
            // Process the new state
            this.processButtonState();
        }
    }
    // Check if the button set has changed
    hasButtonSetChanged(newButtons) {
        if (newButtons.size !== this.currentlyPressedButtons.size) {
            return true;
        }
        for (const button of newButtons) {
            if (!this.currentlyPressedButtons.has(button)) {
                return true;
            }
        }
        return false;
    }
    // Process the current button state
    processButtonState() {
        const buttons = [];
        // Check for L4 button
        if (this.currentlyPressedButtons.has(41 /* Button.L4 */)) {
            buttons.push(41 /* Button.L4 */);
        }
        // Check for R4 button
        if (this.currentlyPressedButtons.has(42 /* Button.R4 */)) {
            buttons.push(42 /* Button.R4 */);
        }
        // Check for L5 button
        if (this.currentlyPressedButtons.has(15 /* Button.L5 */)) {
            buttons.push(15 /* Button.L5 */);
        }
        // Check for R5 button
        if (this.currentlyPressedButtons.has(16 /* Button.R5 */)) {
            buttons.push(16 /* Button.R5 */);
        }
        // Check for L3/R3 buttons (stick clicks, works on external gamepads)
        if (this.currentlyPressedButtons.has(22 /* Button.L3 */)) {
            buttons.push(22 /* Button.L3 */);
        }
        if (this.currentlyPressedButtons.has(26 /* Button.R3 */)) {
            buttons.push(26 /* Button.R3 */);
        }
        // Check for touchpad buttons (for TOUCHPAD_COMBO mode)
        if (this.currentlyPressedButtons.has(19 /* Button.LEFT_TOUCHPAD_TOUCH */)) {
            buttons.push(19 /* Button.LEFT_TOUCHPAD_TOUCH */);
        }
        if (this.currentlyPressedButtons.has(20 /* Button.RIGHT_TOUCHPAD_TOUCH */)) {
            buttons.push(20 /* Button.RIGHT_TOUCHPAD_TOUCH */);
        }
        // Only process if the button state actually changed
        if (this.hasButtonStateChanged(buttons)) {
            const buttonNames = buttons.map(b => {
                if (b === 41 /* Button.L4 */)
                    return 'L4';
                if (b === 42 /* Button.R4 */)
                    return 'R4';
                if (b === 15 /* Button.L5 */)
                    return 'L5';
                if (b === 16 /* Button.R5 */)
                    return 'R5';
                if (b === 22 /* Button.L3 */)
                    return 'L3';
                if (b === 26 /* Button.R3 */)
                    return 'R3';
                if (b === 19 /* Button.LEFT_TOUCHPAD_TOUCH */)
                    return 'LPAD';
                if (b === 20 /* Button.RIGHT_TOUCHPAD_TOUCH */)
                    return 'RPAD';
                return b.toString();
            }).join(',');
            logger.debug('Input', `Button state: buttons=[${buttonNames}]`);
            this.OnButtonsPressed(buttons);
            this.previousButtons = [...buttons];
        }
    }
    // Health check for input system
    startHealthCheck() {
        if (!this.healthCheckEnabled)
            return;
        this.healthCheckInterval = setInterval(() => {
            const now = Date.now();
            // If no input for a long time and we think buttons are pressed, mark as unhealthy
            if (now - this.lastInputTime > 30000 && this.enabled) {
                if ((this.leftTouchpadTouched || this.rightTouchpadTouched) &&
                    now - this.lastInputTime > 5000) {
                    logger.warn('Input', 'Health check: Input seems stuck, try toggling the plugin off/on');
                    this.inputHealthy = false;
                }
            }
        }, 5000);
    }
    // Set enabled state
    setEnabled(enabled) {
        this.enabled = enabled;
        logger.info('Input', `Setting enabled state to: ${enabled}`);
        if (enabled) {
            this.lastInputTime = Date.now();
        }
        if (!enabled) {
            this.stopProgressAnimation();
            this.inCooldown = false;
            this.waitingForRelease = false;
            this.touchStartTime = null;
            this.leftTouchpadTouched = false;
            this.rightTouchpadTouched = false;
            this.currentlyPressedButtons.clear();
        }
    }
    // Check if button state has changed
    hasButtonStateChanged(currentButtons) {
        if (currentButtons.length !== this.previousButtons.length) {
            return true;
        }
        if (currentButtons.length === 0 && this.previousButtons.length === 0) {
            return false;
        }
        const currentSet = new Set(currentButtons);
        const previousSet = new Set(this.previousButtons);
        if (currentSet.size !== previousSet.size) {
            return true;
        }
        for (const button of currentSet) {
            if (!previousSet.has(button)) {
                return true;
            }
        }
        return false;
    }
    // Unregister the input handler
    unregister() {
        logger.info('Input', 'Unregistering input, clearing timers and health check');
        // Stop health check
        if (this.healthCheckInterval) {
            clearInterval(this.healthCheckInterval);
            this.healthCheckInterval = null;
        }
        // Stop polling
        if (this.pollingInterval) {
            clearInterval(this.pollingInterval);
            this.pollingInterval = null;
        }
        if (this.timeoutId)
            clearTimeout(this.timeoutId);
        if (this.animationFrameId)
            cancelAnimationFrame(this.animationFrameId);
        if (this.clearCooldownTimeoutId)
            clearTimeout(this.clearCooldownTimeoutId);
    }
    setInputMode(mode) {
        logger.info('Input', `Setting input mode to ${InputMode[mode]}`);
        this.inputMode = mode;
        this.inCooldown = false;
        this.waitingForRelease = false;
        this.touchStartTime = null;
        this.leftTouchpadTouched = false;
        this.rightTouchpadTouched = false;
        if (this.timeoutId)
            clearTimeout(this.timeoutId);
        if (this.animationFrameId)
            cancelAnimationFrame(this.animationFrameId);
        if (this.clearCooldownTimeoutId)
            clearTimeout(this.clearCooldownTimeoutId);
        this.notifyProgressListeners({ active: false, progress: 0, forDismiss: this.overlayVisible });
    }
    getInputMode() {
        return this.inputMode;
    }
    setOverlayVisible(visible) {
        logger.info('Input', `Overlay visibility set to ${visible}`);
        this.overlayVisible = visible;
    }
    setTranslateHoldTime(ms) {
        logger.info('Input', `Setting translate hold time to: ${ms} ms`);
        this.translateHoldTime = ms;
    }
    getTranslateHoldTime() {
        return this.translateHoldTime;
    }
    setDismissHoldTime(ms) {
        logger.info('Input', `Setting dismiss hold time to: ${ms} ms`);
        this.dismissHoldTime = ms;
    }
    getDismissHoldTime() {
        return this.dismissHoldTime;
    }
    setQuickToggleEnabled(enabled) {
        logger.info('Input', `Setting quick toggle enabled to: ${enabled}`);
        this.quickToggleEnabled = enabled;
    }
    getQuickToggleEnabled() {
        return this.quickToggleEnabled;
    }
    checkHealth() {
        const now = Date.now();
        return this.inputHealthy && (now - this.lastInputTime < 60000 || !this.enabled);
    }
    getDiagnostics() {
        return {
            enabled: this.enabled,
            healthy: this.inputHealthy,
            leftTouchpadTouched: this.leftTouchpadTouched,
            rightTouchpadTouched: this.rightTouchpadTouched,
            inCooldown: this.inCooldown,
            waitingForRelease: this.waitingForRelease,
            overlayVisible: this.overlayVisible,
            inputMode: InputMode[this.inputMode],
            translateHoldTime: this.translateHoldTime,
            dismissHoldTime: this.dismissHoldTime,
            currentButtons: Array.from(this.currentlyPressedButtons),
            pollingActive: this.pollingInterval !== null
        };
    }
    updateProgressAnimation() {
        if (this.touchStartTime === null) {
            if (this.animationFrameId)
                cancelAnimationFrame(this.animationFrameId);
            this.animationFrameId = null;
            this.notifyProgressListeners({ active: false, progress: 0, forDismiss: this.overlayVisible });
            return;
        }
        const now = Date.now();
        const elapsed = now - this.touchStartTime;
        const required = this.overlayVisible ? this.dismissHoldTime : this.translateHoldTime;
        const progress = Math.min(elapsed / required, 1);
        this.notifyProgressListeners({ active: true, progress, forDismiss: this.overlayVisible });
        if (progress < 1) {
            this.animationFrameId = requestAnimationFrame(() => this.updateProgressAnimation());
        }
        else {
            this.notifyProgressListeners({ active: false, progress: 0, forDismiss: this.overlayVisible });
            if (this.animationFrameId)
                cancelAnimationFrame(this.animationFrameId);
            this.animationFrameId = null;
        }
    }
    stopProgressAnimation() {
        this.touchStartTime = null;
        if (this.timeoutId)
            clearTimeout(this.timeoutId);
        if (this.animationFrameId)
            cancelAnimationFrame(this.animationFrameId);
        this.timeoutId = null;
        this.animationFrameId = null;
        this.notifyProgressListeners({ active: false, progress: 0, forDismiss: this.overlayVisible });
    }
    OnButtonsPressed(buttons) {
        logger.debug('Input', `OnButtonsPressed: buttons=[${buttons.join(',')}], mode=${InputMode[this.inputMode]}, waiting=${this.waitingForRelease}, cooldown=${this.inCooldown}`);
        if (!this.enabled) {
            logger.debug('Input', 'Plugin is disabled, ignoring input');
            return;
        }
        // Enforce cooldown by timestamp
        if (this.inCooldown) {
            const since = Date.now() - this.lastActionTime;
            if (since < this.cooldownDuration) {
                logger.debug('Input', `In cooldown, skipping. since: ${since}`);
                return;
            }
            logger.debug('Input', 'Cooldown expired');
            this.inCooldown = false;
            if (this.clearCooldownTimeoutId) {
                clearTimeout(this.clearCooldownTimeoutId);
                this.clearCooldownTimeoutId = null;
            }
        }
        // Quick toggle: when overlay is visible and in combo mode, single right button toggles overlay
        if (this.quickToggleEnabled && this.overlayVisible && !this.waitingForRelease) {
            let rightOnlyPressed = false;
            let rightButtonName = '';
            switch (this.inputMode) {
                case InputMode.L4_R4_COMBO:
                    // R4 pressed but L4 not pressed
                    rightOnlyPressed = buttons.includes(42 /* Button.R4 */) && !buttons.includes(41 /* Button.L4 */);
                    rightButtonName = 'R4';
                    break;
                case InputMode.L5_R5_COMBO:
                    // R5 pressed but L5 not pressed
                    rightOnlyPressed = buttons.includes(16 /* Button.R5 */) && !buttons.includes(15 /* Button.L5 */);
                    rightButtonName = 'R5';
                    break;
                case InputMode.L3_R3_COMBO:
                    // R3 pressed but L3 not pressed
                    rightOnlyPressed = buttons.includes(26 /* Button.R3 */) && !buttons.includes(22 /* Button.L3 */);
                    rightButtonName = 'R3';
                    break;
                case InputMode.TOUCHPAD_COMBO:
                    rightOnlyPressed = buttons.includes(20 /* Button.RIGHT_TOUCHPAD_TOUCH */) && !buttons.includes(19 /* Button.LEFT_TOUCHPAD_TOUCH */);
                    rightButtonName = 'RPAD';
                    break;
            }
            if (rightOnlyPressed) {
                logger.info('Input', `Quick toggle triggered by ${rightButtonName}`);
                this.onButtonsPressedListeners.forEach(cb => cb(ActionType.TOGGLE_TRANSLATIONS));
                // Set a brief cooldown to prevent rapid toggling
                this.inCooldown = true;
                this.lastActionTime = Date.now();
                this.clearCooldownTimeoutId = setTimeout(() => {
                    this.inCooldown = false;
                    this.clearCooldownTimeoutId = null;
                }, this.cooldownDuration);
                return;
            }
        }
        // Determine button state based on input mode
        let buttonPressed = false;
        let buttonName = '';
        switch (this.inputMode) {
            case InputMode.L4_BUTTON:
                buttonPressed = buttons.includes(41 /* Button.L4 */);
                buttonName = 'L4';
                break;
            case InputMode.R4_BUTTON:
                buttonPressed = buttons.includes(42 /* Button.R4 */);
                buttonName = 'R4';
                break;
            case InputMode.L5_BUTTON:
                buttonPressed = buttons.includes(15 /* Button.L5 */);
                buttonName = 'L5';
                break;
            case InputMode.R5_BUTTON:
                buttonPressed = buttons.includes(16 /* Button.R5 */);
                buttonName = 'R5';
                break;
            case InputMode.L4_R4_COMBO:
                const l4Pressed = buttons.includes(41 /* Button.L4 */);
                const r4Pressed = buttons.includes(42 /* Button.R4 */);
                buttonPressed = l4Pressed && r4Pressed;
                buttonName = 'L4+R4';
                break;
            case InputMode.L5_R5_COMBO:
                const l5Pressed = buttons.includes(15 /* Button.L5 */);
                const r5Pressed = buttons.includes(16 /* Button.R5 */);
                buttonPressed = l5Pressed && r5Pressed;
                buttonName = 'L5+R5';
                break;
            case InputMode.L3_BUTTON:
                buttonPressed = buttons.includes(22 /* Button.L3 */);
                buttonName = 'L3';
                break;
            case InputMode.R3_BUTTON:
                buttonPressed = buttons.includes(26 /* Button.R3 */);
                buttonName = 'R3';
                break;
            case InputMode.L3_R3_COMBO:
                const l3Pressed = buttons.includes(22 /* Button.L3 */);
                const r3Pressed = buttons.includes(26 /* Button.R3 */);
                buttonPressed = l3Pressed && r3Pressed;
                buttonName = 'L3+R3';
                break;
            case InputMode.TOUCHPAD_COMBO:
                const leftTouchpadPressed = buttons.includes(19 /* Button.LEFT_TOUCHPAD_TOUCH */);
                const rightTouchpadPressed = buttons.includes(20 /* Button.RIGHT_TOUCHPAD_TOUCH */);
                buttonPressed = leftTouchpadPressed && rightTouchpadPressed;
                buttonName = 'LPAD+RPAD';
                break;
        }
        if (this.waitingForRelease) {
            logger.debug('Input', 'waitingForRelease, checking release');
            if (!buttonPressed) {
                logger.debug('Input', `${buttonName} released, clearing waitingForRelease`);
                this.waitingForRelease = false;
                // Without this, the next press is ignored
                this.leftTouchpadTouched = false;
                this.rightTouchpadTouched = false;
                this.stopProgressAnimation();
                return;
            }
            else {
                this.stopProgressAnimation();
                return;
            }
        }
        // Handle button press
        this.handleButtonCombination(buttonPressed);
    }
    // Handle button press (works for all input modes)
    handleButtonCombination(buttonPressed) {
        const wasButtonPressed = this.leftTouchpadTouched && this.rightTouchpadTouched;
        const modeName = InputMode[this.inputMode];
        logger.debug('Input', `handleButtonCombination: buttonPressed=${buttonPressed}, wasButtonPressed=${wasButtonPressed}, touchStartTime=${this.touchStartTime !== null}`);
        if (buttonPressed && !wasButtonPressed && !this.inCooldown && !this.waitingForRelease) {
            logger.info('Input', `${modeName} pressed, starting hold timer. overlayVisible=${this.overlayVisible}`);
            if (this.touchStartTime === null) {
                this.touchStartTime = Date.now();
                this.updateProgressAnimation();
                const holdTime = this.overlayVisible ? this.dismissHoldTime : this.translateHoldTime;
                logger.debug('Input', `Starting timeout for ${holdTime}ms`);
                this.timeoutId = setTimeout(() => {
                    logger.debug('Input', `${modeName} timeout fired, leftTouched=${this.leftTouchpadTouched}, rightTouched=${this.rightTouchpadTouched}`);
                    if (this.leftTouchpadTouched && this.rightTouchpadTouched) {
                        this.inCooldown = true;
                        this.lastActionTime = Date.now();
                        const actionType = this.overlayVisible ? ActionType.DISMISS : ActionType.TRANSLATE;
                        logger.info('Input', `Action triggered: ${ActionType[actionType]}`);
                        this.onButtonsPressedListeners.forEach(cb => cb(actionType));
                        this.stopProgressAnimation();
                        this.waitingForRelease = true;
                        if (this.clearCooldownTimeoutId)
                            clearTimeout(this.clearCooldownTimeoutId);
                        this.clearCooldownTimeoutId = setTimeout(() => {
                            logger.debug('Input', 'Cooldown and waiting ended');
                            this.inCooldown = false;
                            this.waitingForRelease = false;
                            this.clearCooldownTimeoutId = null;
                        }, this.cooldownDuration);
                    }
                    this.timeoutId = null;
                }, holdTime);
            }
        }
        else if (!buttonPressed && wasButtonPressed) {
            logger.debug('Input', `${modeName} released, stopping progress`);
            this.stopProgressAnimation();
        }
        else {
            logger.debug('Input', `${modeName} no action: buttonPressed=${buttonPressed}, wasButtonPressed=${wasButtonPressed}, inCooldown=${this.inCooldown}, waitingForRelease=${this.waitingForRelease}`);
        }
        // Update state (reusing touchpad vars for button state)
        this.leftTouchpadTouched = buttonPressed;
        this.rightTouchpadTouched = buttonPressed;
    }
    onShortcutPressed(callback) {
        logger.debug('Input', 'Adding shortcut listener');
        this.onButtonsPressedListeners.push(callback);
    }
    offShortcutPressed(callback) {
        logger.debug('Input', 'Removing shortcut listener');
        const idx = this.onButtonsPressedListeners.indexOf(callback);
        if (idx !== -1)
            this.onButtonsPressedListeners.splice(idx, 1);
    }
    onProgress(callback) {
        logger.debug('Input', 'Adding progress listener');
        this.onProgressListeners.push(callback);
    }
    offProgress(callback) {
        logger.debug('Input', 'Removing progress listener');
        const idx = this.onProgressListeners.indexOf(callback);
        if (idx !== -1)
            this.onProgressListeners.splice(idx, 1);
    }
    notifyProgressListeners(progressInfo) {
        for (const cb of this.onProgressListeners)
            cb(progressInfo);
    }
}

// Translator.tsx - Handles translator logic and API interactions
// Main app logic
class GameTranslatorLogic {
    isOverlayVisible() {
        return this.imageState.isVisible();
    }
    // Add public access to shortcutInput for diagnostics
    get shortcutInputHandler() {
        return this.shortcutInput;
    }
    constructor(imageState) {
        this.isProcessing = false;
        this.progressListeners = [];
        this.enabled = true; // Add enabled state
        this.confidenceThreshold = 0.6; // Default confidence threshold
        this.pauseGameOnOverlay = false;
        this.hideIdenticalTranslations = false;
        this.currentRunId = 0;
        // Provider settings for upfront validation
        this.ocrProvider = "rapidocr";
        this.translationProvider = "freegoogle";
        this.hasGoogleApiKey = false;
        this.hasGeminiApiKey = false;
        this.setGroupingPower = (power) => {
            this.textRecognizer.setGroupingPower(power);
        };
        this.setHideIdenticalTranslations = (enabled) => {
            this.hideIdenticalTranslations = enabled;
        };
        this.setPauseGameOnOverlay = (enabled) => {
            logger.debug('Translator', `Setting pauseGameOnOverlay to: ${enabled}`);
            this.pauseGameOnOverlay = enabled;
            // If overlay is currently visible and we're enabling this setting, pause the game
            if (enabled && this.imageState.isVisible()) {
                this.pauseCurrentGame();
            }
        };
        // Method to get pause game on overlay state
        this.getPauseGameOnOverlay = () => {
            return this.pauseGameOnOverlay;
        };
        this.notify = async (message, duration = 1000, body) => {
            toaster.toast({
                title: message,
                body: body || message,
                duration: duration,
                critical: true
            });
        };
        this.dismiss = () => {
            this.currentRunId++;
            this.isProcessing = false;
            if (this.imageState.isVisible()) {
                this.imageState.hideImage();
                this.shortcutInput.setOverlayVisible(false);
            }
        };
        this.takeScreenshotAndTranslate = async () => {
            // If already processing or disabled, return
            if (this.isProcessing || !this.enabled) {
                logger.debug('Translator', 'Already processing a screenshot or plugin disabled, skipping');
                return;
            }
            if (!this.canStartTranslation())
                return;
            const runId = ++this.currentRunId;
            const isCancelled = () => runId !== this.currentRunId;
            try {
                this.isProcessing = true;
                // Take screenshot FIRST while screen is clean (no overlay visible)
                const appName = DFL.Router.MainRunningApp?.display_name || "";
                logger.info('Translator', `Taking new screenshot for: ${appName}`);
                const result = await call('take_screenshot', appName);
                if (isCancelled()) {
                    logger.debug('Translator', 'Translation cancelled before screenshot processed');
                    return;
                }
                if (!result || !result.path || !result.base64) {
                    logger.warn('Translator', 'Screenshot capture failed, not opening overlay');
                    this.notify('Screen capture failed', 2500, 'Try pressing the shortcut again');
                    return;
                }
                logger.debug('Translator', `Screenshot captured, path: ${result.path}, base64 length: ${result.base64.length}`);
                this.imageState.startLoading("Processing");
                this.imageState.showImage(result.base64);
                const recognizingStep = this.ocrProvider === 'gemini_vision'
                    ? "Recognizing and Translating"
                    : "Recognizing";
                this.imageState.updateProcessingStep(recognizingStep, false, this.ocrMethodHint());
                const textRegions = await this.textRecognizer.recognizeTextFile(result.path);
                if (isCancelled()) {
                    logger.debug('Translator', 'Translation cancelled after OCR');
                    return;
                }
                logger.info('Translator', `Found ${textRegions.length} text regions`);
                if (textRegions.length > 0) {
                    const alreadyTranslated = textRegions.every(r => r.translatedText);
                    if (!alreadyTranslated) {
                        this.imageState.updateProcessingStep("Translating text", false, this.translationMethodHint());
                    }
                    // Translate text (skips backend call if already translated by OCR provider)
                    let translatedRegions = await this.textTranslator.translateText(textRegions);
                    if (isCancelled()) {
                        logger.debug('Translator', 'Translation cancelled after translation step');
                        return;
                    }
                    logger.info('Translator', `Translation complete: ${translatedRegions.length} regions`);
                    if (this.hideIdenticalTranslations) {
                        const before = translatedRegions.length;
                        translatedRegions = translatedRegions.filter(r => r.translatedText.trim().toLowerCase() !== r.text.trim().toLowerCase());
                        if (translatedRegions.length < before) {
                            logger.info('Translator', `Filtered ${before - translatedRegions.length} identical translations`);
                        }
                    }
                    this.imageState.showTranslatedImage(result.base64, translatedRegions);
                }
                else {
                    // No text found, show message
                    this.imageState.updateProcessingStep("No text found");
                    // Hide overlay after a short delay
                    setTimeout(() => {
                        this.imageState.hideImage();
                    }, 2000); // 2 seconds delay
                }
            }
            catch (error) {
                if (isCancelled()) {
                    logger.debug('Translator', 'Translation cancelled, suppressing error UI', error);
                    return;
                }
                logger.error('Translator', 'Screenshot and translation error', error);
                // Check if this is a network error
                if (error instanceof NetworkError) {
                    const msg = error.message || "No internet connection";
                    this.imageState.updateProcessingStep(msg, true);
                    // Hide overlay after showing the error message
                    setTimeout(() => {
                        this.imageState.hideImage();
                    }, 2500); // 2.5 seconds delay for network error
                }
                else if (error instanceof ApiKeyError) {
                    this.imageState.updateProcessingStep(error.message || "Invalid API key", true);
                    // Hide overlay after showing the error message
                    setTimeout(() => {
                        this.imageState.hideImage();
                    }, 2500); // 2.5 seconds delay for API key error
                }
                else if (error instanceof ModelNotAvailableError) {
                    this.imageState.updateProcessingStep(error.message, true);
                    setTimeout(() => {
                        this.imageState.hideImage();
                    }, 3000);
                }
                else if (error instanceof RateLimitError) {
                    this.imageState.updateProcessingStep(error.message, true);
                    // Hide overlay after showing the error message
                    setTimeout(() => {
                        this.imageState.hideImage();
                    }, 3000); // 3 seconds delay for rate limit error
                }
                else {
                    this.imageState.hideImage();
                }
            }
            finally {
                if (!isCancelled()) {
                    this.isProcessing = false;
                }
            }
        };
        this.setInputLanguage = (language) => {
            this.textTranslator.setInputLanguage(language);
        };
        this.getInputLanguage = () => {
            return this.textTranslator.getInputLanguage();
        };
        this.setTargetLanguage = (language) => {
            this.textTranslator.setTargetLanguage(language);
        };
        this.getTargetLanguage = () => {
            return this.textTranslator.getTargetLanguage();
        };
        // Method to set input mode
        this.setInputMode = (mode) => {
            this.shortcutInput.setInputMode(mode);
        };
        // Method to get current input mode
        this.getInputMode = () => {
            return this.shortcutInput.getInputMode();
        };
        // Method to set translation hold time
        this.setHoldTimeTranslate = (ms) => {
            if (this.shortcutInput) {
                this.shortcutInput.setTranslateHoldTime(ms);
            }
        };
        // Method to get translation hold time
        this.getHoldTimeTranslate = () => {
            return this.shortcutInput ? this.shortcutInput.getTranslateHoldTime() : 1000;
        };
        // Method to set dismiss hold time
        this.setHoldTimeDismiss = (ms) => {
            if (this.shortcutInput) {
                this.shortcutInput.setDismissHoldTime(ms);
            }
        };
        // Method to get dismiss hold time
        this.getHoldTimeDismiss = () => {
            return this.shortcutInput ? this.shortcutInput.getDismissHoldTime() : 500;
        };
        // Method to set quick toggle enabled
        this.setQuickToggleEnabled = (enabled) => {
            if (this.shortcutInput) {
                this.shortcutInput.setQuickToggleEnabled(enabled);
            }
        };
        // Method to get quick toggle enabled state
        this.getQuickToggleEnabled = () => {
            return this.shortcutInput ? this.shortcutInput.getQuickToggleEnabled() : false;
        };
        this.setFontScale = (scale) => {
            this.imageState.setFontScale(scale);
        };
        this.setAllowLabelGrowth = (allow) => {
            this.imageState.setAllowLabelGrowth(allow);
        };
        this.setTranslatedTextAlignment = (alignment) => {
            this.imageState.setTranslatedTextAlignment(alignment);
        };
        this.setTranslatedTextFontFamily = (fontFamily) => {
            this.imageState.setTranslatedTextFontFamily(fontFamily);
        };
        this.setTranslatedTextFontStyle = (style) => {
            this.imageState.setTranslatedTextFontStyle(style);
        };
        // Methods for provider settings (used for upfront API key validation)
        this.setOcrProvider = (provider) => {
            this.ocrProvider = provider;
            logger.debug('Translator', `OCR provider set to: ${provider}`);
        };
        this.setTranslationProvider = (provider) => {
            this.translationProvider = provider;
            logger.debug('Translator', `Translation provider set to: ${provider}`);
        };
        this.setHasGoogleApiKey = (hasKey) => {
            this.hasGoogleApiKey = hasKey;
            logger.debug('Translator', `Google API key available: ${hasKey}`);
        };
        this.setHasGeminiApiKey = (hasKey) => {
            this.hasGeminiApiKey = hasKey;
            logger.debug('Translator', `Gemini API key available: ${hasKey}`);
        };
        this.imageState = imageState;
        this.textRecognizer = new TextRecognizer();
        this.textTranslator = new TextTranslator();
        // Initialize for hidraw-based button detection
        this.shortcutInput = new Input();
        // Set up listener for translate, dismiss, and toggle actions
        this.shortcutInput.onShortcutPressed((actionType) => {
            // Only process inputs if the plugin is enabled
            if (!this.enabled)
                return;
            if (actionType === ActionType.DISMISS) {
                this.dismiss();
            }
            else if (actionType === ActionType.TOGGLE_TRANSLATIONS) {
                // Toggle translations action
                if (this.imageState.isVisible() && !this.imageState.isLoading()) {
                    logger.debug('Translator', 'Toggling translation visibility');
                    this.imageState.toggleTranslationsVisibility();
                }
            }
            else {
                // Translate action
                if (this.imageState.isVisible())
                    return;
                if (this.isProcessing)
                    return;
                if (!this.canStartTranslation())
                    return;
                // Pause first so the game freezes before the screenshot
                if (this.pauseGameOnOverlay) {
                    this.pauseCurrentGame().catch(err => logger.error('Translator', 'Pause failed', err));
                }
                this.takeScreenshotAndTranslate().catch(err => logger.error('Translator', 'Screenshot failed', err));
            }
        });
        imageState.onStateChanged((visible, _, __, ___, ____, _____, ______, _______, ________) => {
            this.shortcutInput.setOverlayVisible(visible);
            if (!this.enabled)
                return;
            if (this.pauseGameOnOverlay && !visible) {
                this.resumeCurrentGame();
            }
        });
        // Set up progress listener
        this.shortcutInput.onProgress((progressInfo) => {
            this.notifyProgressListeners(progressInfo);
        });
        // Load enabled state from server
        this.loadInitialState();
    }
    // Load initial state from server
    async loadInitialState() {
        try {
            const result = await call('get_enabled_state');
            this.enabled = !!result;
            logger.info('Translator', `Loaded initial enabled state: ${this.enabled}`);
            if (this.shortcutInput) {
                this.shortcutInput.setEnabled(this.enabled);
            }
            // If plugin starts disabled, stop the hidraw monitor that was auto-started
            if (!this.enabled) {
                logger.info('Translator', 'Plugin is disabled on startup, stopping hidraw monitor');
                call('stop_hidraw_monitor').catch(error => {
                    logger.error('Translator', 'Failed to stop hidraw monitor on startup', error);
                });
            }
        }
        catch (error) {
            logger.error('Translator', 'Failed to load initial state', error);
        }
    }
    // Add method to enable/disable the plugin
    setEnabled(enabled) {
        this.enabled = enabled;
        if (this.shortcutInput) {
            this.shortcutInput.setEnabled(enabled);
        }
        // Save to server settings file
        call('set_setting', 'enabled', enabled).catch(error => {
            logger.error('Translator', 'Failed to save enabled state to server', error);
        });
        if (!enabled) {
            this.dismiss();
        }
        // Stop or start the backend hidraw monitor based on enabled state
        if (enabled) {
            // Re-start hidraw monitor when re-enabling
            call('start_hidraw_monitor').then(result => {
                logger.info('Translator', `Hidraw monitor start result: ${JSON.stringify(result)}`);
            }).catch(error => {
                logger.error('Translator', 'Failed to start hidraw monitor', error);
            });
        }
        else {
            // Stop hidraw monitor when disabling to save resources
            call('stop_hidraw_monitor').then(result => {
                logger.info('Translator', `Hidraw monitor stop result: ${JSON.stringify(result)}`);
            }).catch(error => {
                logger.error('Translator', 'Failed to stop hidraw monitor', error);
            });
        }
    }
    // Add method to get enabled state
    isEnabled() {
        return this.enabled;
    }
    // Method to get full diagnostic information
    getInputDiagnostics() {
        if (!this.shortcutInput)
            return null;
        return this.shortcutInput.getDiagnostics();
    }
    // New methods for confidence threshold
    setConfidenceThreshold(threshold) {
        logger.debug('Translator', `Setting confidence threshold to: ${threshold}`);
        this.confidenceThreshold = threshold;
        // Update the textRecognizer with the new threshold
        this.textRecognizer.setConfidenceThreshold(threshold);
    }
    getConfidenceThreshold() {
        return this.confidenceThreshold;
    }
    // Method to pause the current game
    async pauseCurrentGame() {
        try {
            // Get the current running app ID
            const mainApp = DFL.Router.MainRunningApp;
            if (!mainApp || !mainApp.appid) {
                logger.debug('Translator', 'No game running to pause');
                return;
            }
            // Use the pid_from_appid function to get the process ID
            const pid = await call('pid_from_appid', Number(mainApp.appid));
            if (pid) {
                logger.info('Translator', `Pausing game with appid ${mainApp.appid}, pid ${pid}`);
                // Call the pause function in the backend
                const pauseResult = await call('pause', pid);
                if (pauseResult) {
                    logger.info('Translator', 'Game paused successfully');
                }
                else {
                    logger.error('Translator', 'Failed to pause game');
                }
            }
            else {
                logger.error('Translator', 'Failed to get PID for game');
            }
        }
        catch (error) {
            logger.error('Translator', 'Error pausing game', error);
        }
    }
    // Method to resume the current game
    async resumeCurrentGame() {
        try {
            // Get the current running app ID
            const mainApp = DFL.Router.MainRunningApp;
            if (!mainApp || !mainApp.appid) {
                logger.debug('Translator', 'No game running to resume');
                return;
            }
            // Use the pid_from_appid function to get the process ID
            const pid = await call('pid_from_appid', Number(mainApp.appid));
            if (pid) {
                logger.info('Translator', `Resuming game with appid ${mainApp.appid}, pid ${pid}`);
                // Call the resume function in the backend
                const resumeResult = await call('resume', pid);
                if (resumeResult) {
                    logger.info('Translator', 'Game resumed successfully');
                }
                else {
                    logger.error('Translator', 'Failed to resume game');
                }
            }
            else {
                logger.error('Translator', 'Failed to get PID for game');
            }
        }
        catch (error) {
            logger.error('Translator', 'Error resuming game', error);
        }
    }
    // Methods for progress indicator
    onProgress(callback) {
        this.progressListeners.push(callback);
    }
    offProgress(callback) {
        const index = this.progressListeners.indexOf(callback);
        if (index !== -1) {
            this.progressListeners.splice(index, 1);
        }
    }
    notifyProgressListeners(progressInfo) {
        for (const callback of this.progressListeners) {
            callback(progressInfo);
        }
    }
    // Clean up resources when plugin is unmounted
    cleanup() {
        if (this.shortcutInput) {
            this.shortcutInput.unregister();
        }
        // Stop backend hidraw monitor
        call('stop_hidraw_monitor').catch(error => {
            logger.error('Translator', 'Failed to stop hidraw monitor', error);
        });
    }
    translationMethodHint() {
        const labels = {
            ct2: "On-Device",
            freegoogle: "Google Translate",
            googlecloud: "Google Cloud",
        };
        return labels[this.translationProvider] || this.translationProvider;
    }
    ocrMethodHint() {
        const labels = {
            rapidocr: "On-Device",
            chromescreenai: "On-Device",
            ocrspace: "OCR.space",
            googlecloud: "Google Cloud",
            gemini_vision: "Gemini Vision",
        };
        return labels[this.ocrProvider] || this.ocrProvider;
    }
    // Runs all pre-checks that would prevent a translation from starting.
    // Returns false and shows a toast if any check fails.
    canStartTranslation() {
        const inputLang = this.getInputLanguage();
        const targetLang = this.getTargetLanguage();
        if (!inputLang && targetLang) {
            logger.warn('Translator', 'Cannot start translation: languages not configured');
            this.notify("Input language is not set", 3000, "Please select it in the plugin settings");
            return false;
        }
        if (!targetLang && inputLang) {
            logger.warn('Translator', 'Cannot start translation: languages not configured');
            this.notify("Output language is not set", 3000, "Please select it in the plugin settings");
            return false;
        }
        if (!inputLang && !targetLang) {
            logger.warn('Translator', 'Cannot start translation: languages not configured');
            this.notify("Output and Input languages are not set", 3000, "Please select them in the plugin settings");
            return false;
        }
        if (inputLang !== 'auto' && inputLang === targetLang) {
            logger.warn('Translator', `Cannot start translation: input and output language are both ${inputLang}`);
            this.notify("Input and output languages can not be the same", 3000, "Select change them in plugin settings");
            return false;
        }
        const apiKeyCheck = this.requiresApiKeyButMissing();
        if (apiKeyCheck.missing) {
            logger.warn('Translator', `Cannot start translation: ${apiKeyCheck.message}`);
            this.notify(apiKeyCheck.message, 3000, "Please configure your API key in the Translation settings tab.");
            return false;
        }
        return true;
    }
    // Check if the current provider configuration requires an API key that's missing
    requiresApiKeyButMissing() {
        if (this.ocrProvider === 'gemini_vision' && !this.hasGeminiApiKey) {
            return { missing: true, message: "Gemini API key required for Gemini Vision" };
        }
        const ocrNeedsKey = this.ocrProvider === 'googlecloud';
        const translationNeedsKey = this.translationProvider === 'googlecloud';
        if ((ocrNeedsKey || translationNeedsKey) && !this.hasGoogleApiKey) {
            if (ocrNeedsKey && translationNeedsKey) {
                return { missing: true, message: "API key required for OCR & Translation" };
            }
            else if (ocrNeedsKey) {
                return { missing: true, message: "API key required for OCR" };
            }
            else {
                return { missing: true, message: "API key required for Translation" };
            }
        }
        return { missing: false, message: "" };
    }
}

// UI Composition layers provided by Decky
var UIComposition;
(function (UIComposition) {
    UIComposition[UIComposition["Hidden"] = 0] = "Hidden";
    UIComposition[UIComposition["Notification"] = 1] = "Notification";
    UIComposition[UIComposition["Overlay"] = 2] = "Overlay";
    UIComposition[UIComposition["Opaque"] = 3] = "Opaque";
    UIComposition[UIComposition["OverlayKeyboard"] = 4] = "OverlayKeyboard";
})(UIComposition || (UIComposition = {}));
// Hook into Decky's UI composition to ensure our indicator renders above the game or overlay
const useUIComposition = DFL.findModuleChild((m) => {
    if (typeof m !== "object")
        return undefined;
    for (let prop in m) {
        const fn = m[prop];
        if (typeof fn === "function" &&
            fn.toString().includes("AddMinimumCompositionStateRequest") &&
            fn.toString().includes("ChangeMinimumCompositionStateRequest") &&
            fn.toString().includes("RemoveMinimumCompositionStateRequest") &&
            !fn.toString().includes("m_mapCompositionStateRequests")) {
            return fn;
        }
    }
});
// Mountable component that holds a composition state request.
// When unmounted, the hook cleanup removes the request entirely.
const CompositionRequest = ({ level }) => {
    useUIComposition(level);
    return null;
};
const ActivationIndicator = ({ visible, progress, text, forDismiss }) => {
    const layer = forDismiss ? UIComposition.Overlay : UIComposition.Notification;
    const size = 36;
    const strokeWidth = 3;
    const radius = (size - strokeWidth) / 2;
    const circumference = radius * 2 * Math.PI;
    const offset = circumference * (1 - progress);
    const strokeColor = forDismiss ? "#f44336" : "#3498db";
    return (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
        visible && window.SP_REACT.createElement(CompositionRequest, { level: layer }),
        window.SP_REACT.createElement("div", { style: {
                position: "fixed",
                bottom: "20px",
                left: "20px",
                zIndex: 8003,
                display: "flex",
                flexDirection: "row",
                alignItems: "center",
                background: "rgba(0, 0, 0, 0.7)",
                padding: '8px 12px',
                borderRadius: '20px',
                boxShadow: "0 2px 8px rgba(0,0,0,0.2)",
                opacity: visible ? 1 : 0,
                pointerEvents: visible ? "auto" : "none",
            } },
            window.SP_REACT.createElement("svg", { width: size, height: size, viewBox: `0 0 ${size} ${size}` },
                window.SP_REACT.createElement("circle", { cx: size / 2, cy: size / 2, r: radius, fill: "none", stroke: "#333333", strokeWidth: strokeWidth }),
                window.SP_REACT.createElement("circle", { cx: size / 2, cy: size / 2, r: radius, fill: "none", stroke: strokeColor, strokeWidth: strokeWidth, strokeLinecap: "round", strokeDasharray: circumference, strokeDashoffset: offset, transform: `rotate(-90 ${size / 2} ${size / 2})` })),
            text && (window.SP_REACT.createElement("div", { style: {
                    marginLeft: "10px",
                    color: "#ffffff",
                    fontSize: "14px",
                    whiteSpace: "nowrap"
                } }, text)))));
};

// src/SettingsContext.tsx

// Define the initial state
const initialSettings = {
    inputLanguage: "",
    targetLanguage: "",
    inputMode: InputMode.L5_BUTTON, // Default to L5 back button
    enabled: true,
    initialized: false,
    holdTimeTranslate: 1000, // Default to 1 second (1000ms)
    holdTimeDismiss: 500, // Default to 0.5 seconds (500ms)
    confidenceThreshold: 0.6, // Default confidence threshold
    rapidocrConfidence: 0.5, // Default RapidOCR confidence threshold (0.0-1.0)
    rapidocrBoxThresh: 0.5, // Default RapidOCR box detection threshold (0.0-1.0)
    rapidocrUnclipRatio: 1.6, // Default RapidOCR box expansion ratio (1.0-3.0)
    rapidocrPersistentMode: false,
    chromeScreenAiPersistentMode: false,
    ct2PersistentMode: false,
    pauseGameOnOverlay: false, // Default to not pausing game
    quickToggleEnabled: false, // Default to disabled
    useFreeProviders: true, // Default to free providers (no API key needed) - deprecated
    ocrProvider: "chromescreenai", // Default to chromescreenai (Chrome Screen AI) provider
    translationProvider: "freegoogle", // Default to free Google Translate
    googleApiKey: "", // Empty by default, only needed for Google Cloud
    geminiApiKey: "", // Empty by default, needed for Gemini Vision
    geminiModel: "gemini-2.5-flash", // Default Gemini model
    debugMode: false, // Debug mode off by default
    fontScale: 1.0,
    groupingPower: 0.25,
    translatedTextAlignment: 'center',
    translatedTextFontFamily: '',
    translatedTextFontStyle: 'normal',
    hideIdenticalTranslations: false,
    allowLabelGrowth: false,
    customRecognitionSettings: false,
    translationCacheEnabled: true,
};
// Create the reducer
function settingsReducer(state, action) {
    switch (action.type) {
        case 'INITIALIZE_SETTINGS':
            return { ...state, ...action.settings };
        case 'UPDATE_SETTING':
            return { ...state, [action.key]: action.value };
        case 'SET_INITIALIZED':
            return { ...state, initialized: action.initialized };
        default:
            return state;
    }
}
const SettingsContext = SP_REACT.createContext(undefined);
const SettingsProvider = ({ children, logic }) => {
    const [settings, dispatch] = SP_REACT.useReducer(settingsReducer, initialSettings);
    // Load all settings at once
    const loadAllSettings = async () => {
        try {
            const serverSettings = await call('get_all_settings');
            if (serverSettings) {
                // Map backend settings to frontend settings
                const mappedSettings = {
                    inputLanguage: serverSettings.input_language,
                    targetLanguage: serverSettings.target_language,
                    inputMode: serverSettings.input_mode,
                    enabled: serverSettings.enabled,
                    holdTimeTranslate: serverSettings.hold_time_translate,
                    holdTimeDismiss: serverSettings.hold_time_dismiss,
                    confidenceThreshold: serverSettings.confidence_threshold || 0.6, // Add default if not present
                    rapidocrConfidence: serverSettings.rapidocr_confidence ?? 0.5, // RapidOCR confidence (0.0-1.0)
                    rapidocrBoxThresh: serverSettings.rapidocr_box_thresh ?? 0.5, // RapidOCR box threshold (0.0-1.0)
                    rapidocrUnclipRatio: serverSettings.rapidocr_unclip_ratio ?? 1.6, // RapidOCR unclip ratio (1.0-3.0)
                    rapidocrPersistentMode: serverSettings.rapidocr_persistent_mode ?? false,
                    chromeScreenAiPersistentMode: serverSettings.chromescreenai_persistent_mode ?? false,
                    ct2PersistentMode: serverSettings.ct2_persistent_mode ?? false,
                    pauseGameOnOverlay: serverSettings.pause_game_on_overlay || false, // Add default if not present
                    quickToggleEnabled: serverSettings.quick_toggle_enabled || false, // Add default if not present
                    useFreeProviders: serverSettings.use_free_providers !== false, // Default to true (deprecated)
                    ocrProvider: serverSettings.ocr_provider || "chromescreenai", // OCR provider setting
                    translationProvider: serverSettings.translation_provider || "freegoogle", // Translation provider setting
                    googleApiKey: serverSettings.google_api_key || "", // Google API key
                    geminiApiKey: serverSettings.gemini_api_key || "", // Gemini API key
                    geminiModel: serverSettings.gemini_model || "gemini-2.5-flash",
                    debugMode: serverSettings.debug_mode || false,
                    fontScale: serverSettings.font_scale ?? 1.0,
                    groupingPower: serverSettings.grouping_power ?? 0.25,
                    translatedTextAlignment: serverSettings.translated_text_alignment ?? 'center',
                    translatedTextFontFamily: serverSettings.translated_text_font_family ?? '',
                    translatedTextFontStyle: serverSettings.translated_text_font_style ?? 'normal',
                    hideIdenticalTranslations: serverSettings.hide_identical_translations ?? false,
                    allowLabelGrowth: serverSettings.allow_label_growth ?? false,
                    customRecognitionSettings: serverSettings.custom_recognition_settings ?? false,
                    translationCacheEnabled: serverSettings.translation_cache_enabled ?? true,
                };
                // Update settings in context
                dispatch({ type: 'INITIALIZE_SETTINGS', settings: mappedSettings });
                // Update logic instance with settings
                logic.setInputLanguage(serverSettings.input_language);
                logic.setTargetLanguage(serverSettings.target_language);
                logic.setInputMode(serverSettings.input_mode);
                logic.setEnabled(serverSettings.enabled);
                logic.setHoldTimeTranslate(serverSettings.hold_time_translate);
                logic.setHoldTimeDismiss(serverSettings.hold_time_dismiss);
                logic.setConfidenceThreshold(serverSettings.confidence_threshold || 0.6); // Set in logic
                logic.setPauseGameOnOverlay(serverSettings.pause_game_on_overlay || false); // Set pause on overlay setting
                logic.setQuickToggleEnabled(serverSettings.quick_toggle_enabled || false); // Set quick toggle setting
                logger.setEnabled(serverSettings.debug_mode || false); // Set debug mode for logger
                // Set provider settings for upfront API key validation
                logic.setOcrProvider(serverSettings.ocr_provider || "chromescreenai");
                logic.setTranslationProvider(serverSettings.translation_provider || "freegoogle");
                logic.setHasGoogleApiKey(!!serverSettings.google_api_key);
                logic.setHasGeminiApiKey(!!serverSettings.gemini_api_key);
                logic.setFontScale(serverSettings.font_scale ?? 1.0);
                logic.setGroupingPower(serverSettings.grouping_power ?? 0.25);
                logic.setTranslatedTextAlignment(serverSettings.translated_text_alignment ?? 'center');
                logic.setTranslatedTextFontFamily(serverSettings.translated_text_font_family ?? '');
                logic.setTranslatedTextFontStyle(serverSettings.translated_text_font_style ?? 'normal');
                logic.setHideIdenticalTranslations(serverSettings.hide_identical_translations ?? false);
                logic.setAllowLabelGrowth(serverSettings.allow_label_growth ?? false);
                logger.info('SettingsContext', 'All settings loaded successfully');
                logger.logObject('SettingsContext', 'Settings', mappedSettings);
            }
            else {
                logger.error('SettingsContext', 'Failed to load settings');
            }
        }
        catch (error) {
            logger.error('SettingsContext', 'Error loading settings', error);
        }
        finally {
            dispatch({ type: 'SET_INITIALIZED', initialized: true });
        }
    };
    // Update a single setting
    const updateSetting = async (key, value, label) => {
        try {
            // Update local state
            dispatch({ type: 'UPDATE_SETTING', key, value });
            // Map frontend setting key to backend setting key
            const backendKeyMap = {
                inputLanguage: 'input_language',
                targetLanguage: 'target_language',
                inputMode: 'input_mode',
                enabled: 'enabled',
                initialized: 'initialized',
                holdTimeTranslate: 'hold_time_translate',
                holdTimeDismiss: 'hold_time_dismiss',
                confidenceThreshold: 'confidence_threshold',
                rapidocrConfidence: 'rapidocr_confidence',
                rapidocrBoxThresh: 'rapidocr_box_thresh',
                rapidocrUnclipRatio: 'rapidocr_unclip_ratio',
                rapidocrPersistentMode: 'rapidocr_persistent_mode',
                chromeScreenAiPersistentMode: 'chromescreenai_persistent_mode',
                ct2PersistentMode: 'ct2_persistent_mode',
                pauseGameOnOverlay: 'pause_game_on_overlay',
                quickToggleEnabled: 'quick_toggle_enabled',
                useFreeProviders: 'use_free_providers',
                ocrProvider: 'ocr_provider',
                translationProvider: 'translation_provider',
                googleApiKey: 'google_api_key',
                geminiApiKey: 'gemini_api_key',
                geminiModel: 'gemini_model',
                debugMode: 'debug_mode',
                fontScale: 'font_scale',
                groupingPower: 'grouping_power',
                translatedTextAlignment: 'translated_text_alignment',
                translatedTextFontFamily: 'translated_text_font_family',
                translatedTextFontStyle: 'translated_text_font_style',
                hideIdenticalTranslations: 'hide_identical_translations',
                allowLabelGrowth: 'allow_label_growth',
                customRecognitionSettings: 'custom_recognition_settings',
                translationCacheEnabled: 'translation_cache_enabled'
            };
            // Skip settings that don't need to be saved to backend
            if (key === 'initialized')
                return true;
            const backendKey = backendKeyMap[key];
            // Update logic based on setting type
            switch (key) {
                case 'inputLanguage':
                    logic.setInputLanguage(value);
                    break;
                case 'targetLanguage':
                    logic.setTargetLanguage(value);
                    break;
                case 'inputMode':
                    logic.setInputMode(value);
                    break;
                case 'enabled':
                    logic.setEnabled(value);
                    break;
                case 'holdTimeTranslate':
                    logic.setHoldTimeTranslate(value);
                    break;
                case 'holdTimeDismiss':
                    logic.setHoldTimeDismiss(value);
                    break;
                case 'confidenceThreshold':
                    logic.setConfidenceThreshold(value);
                    break;
                case 'pauseGameOnOverlay':
                    logic.setPauseGameOnOverlay(value);
                    break;
                case 'quickToggleEnabled':
                    logic.setQuickToggleEnabled(value);
                    break;
                case 'debugMode':
                    logger.setEnabled(value);
                    break;
                case 'fontScale':
                    logic.setFontScale(value);
                    break;
                case 'groupingPower':
                    logic.setGroupingPower(value);
                    break;
                case 'translatedTextAlignment':
                    logic.setTranslatedTextAlignment(value);
                    break;
                case 'translatedTextFontFamily':
                    logic.setTranslatedTextFontFamily(value);
                    break;
                case 'translatedTextFontStyle':
                    logic.setTranslatedTextFontStyle(value);
                    break;
                case 'hideIdenticalTranslations':
                    logic.setHideIdenticalTranslations(value);
                    break;
                case 'allowLabelGrowth':
                    logic.setAllowLabelGrowth(value);
                    break;
                case 'ocrProvider':
                    logic.setOcrProvider(value);
                    break;
                case 'translationProvider':
                    logic.setTranslationProvider(value);
                    break;
                case 'googleApiKey':
                    logic.setHasGoogleApiKey(!!value);
                    break;
                case 'geminiApiKey':
                    logic.setHasGeminiApiKey(!!value);
                    break;
            }
            // Save to backend
            const result = await call('set_setting', backendKey, value);
            if (result) {
                // if (label) logic.notify(`${label} updated successfully`);
                return true;
            }
            else {
                logic.notify(`Failed to update ${label || key}`, 2000);
                return false;
            }
        }
        catch (error) {
            logger.error('SettingsContext', `Failed to update ${key}`, error);
            logic.notify(`Failed to update ${label || key}`, 2000);
            return false;
        }
    };
    // Initialize settings on mount
    SP_REACT.useEffect(() => {
        loadAllSettings();
    }, []);
    return (window.SP_REACT.createElement(SettingsContext.Provider, { value: {
            settings,
            updateSetting,
            initialized: settings.initialized
        } }, children));
};
// Create a hook for using the settings
const useSettings = () => {
    const context = SP_REACT.useContext(SettingsContext);
    if (!context) {
        throw new Error('useSettings must be used within a SettingsProvider');
    }
    return context;
};

const AUTHOR_NOTICE = "汉化：RenAmamiya";
const ZH = {
    "Decky Translator": "沉浸式翻译",
    "Loading...": "正在加载…",
    "Plugin is enabled": "插件已启用",
    "Plugin is disabled": "插件已停用",
    "Toggle the functionality on or off": "开启或关闭翻译功能",
    "Close Overlay": "关闭翻译浮层",
    "Translate": "立即翻译",
    "Text Recognition:": "文字识别：",
    "Translation:": "翻译服务：",
    "Recognize + Translate:": "识别并翻译：",
    "Checking...": "正在检查…",
    "Ready": "已就绪",
    "Not ready": "未就绪",
    "Download required": "需要下载组件",
    "Installing...": "正在安装…",
    "Model not installed": "模型未安装",
    "No API key needed": "无需 API 密钥",
    "10 min limit:": "10 分钟限额：",
    "Daily limit:": "每日限额：",
    "Rate limit exceeded": "已达到请求频率上限",
    "On-Device": "设备本地",
    "Model:": "模型：",
    "Cached Translations": "缓存译文",
    "Cache Translations": "缓存翻译结果",
    "View Cached Translations": "查看缓存译文",
    "Faster Translation": "加速翻译",
    "On-device Text Recognition": "设备本地文字识别",
    "Low daily requests remaining": "今日剩余请求次数不多",
    "API key configured": "API 密钥已配置",
    "API key required": "需要 API 密钥",
    "Requires internet connection": "需要网络连接",
    "Support on Ko-fi": "支持插件原作者",
    "Show QR Code": "显示二维码",
    "Languages": "语言",
    "Select language...": "请选择语言…",
    "Input Language": "原文语言",
    "Output Language": "目标语言",
    "Source language for text recognition": "用于文字识别的原文语言",
    "Source language (Select auto-detect if unsure)": "原文语言（不确定时请选择自动检测）",
    "Target language for translation": "翻译后的目标语言",
    "Recognition": "文字识别",
    "Text Recognition Method": "文字识别方式",
    "On-Device Text Recognition": "设备本地文字识别",
    "Average accuracy and slower than web-based options": "准确率一般，速度慢于在线方案",
    "Customizable parameters": "支持自定义识别参数",
    "Screenshots do not leave your device": "截图不会离开本机",
    "Free EU-based cloud OCR API": "免费的欧洲云端 OCR 服务",
    "Max usage limits: 500/day and 10/10min": "用量上限：每天 500 次、每 10 分钟 10 次",
    "Provides good speed and results": "速度和识别效果较好",
    "Best accuracy and speed available": "准确率和速度最佳",
    "Ideal for complex/stylized text": "适合复杂或艺术字体",
    "Requires API key": "需要 API 密钥",
    "You need to add your API Key": "请先填写 API 密钥",
    "Customize Recognition": "自定义识别参数",
    "Fine-tune text recognition parameters. Can make things better or worse": "微调文字识别参数；设置不当可能降低效果",
    "Recognition Confidence": "识别置信度",
    "Higher = less noise but may miss text. Lower = more text but more errors": "调高可减少噪声但可能漏字；调低可识别更多文字但错误会增加",
    "Detection Sensitivity": "检测灵敏度",
    "Lower = finds more text regions, better for small text. Higher = fewer regions, but more confident detections": "调低可发现更多小字区域；调高则区域更少但结果更可靠",
    "Box Expansion": "文本框扩展",
    "Higher = larger text boxes, helps capture full words. Lower = tighter boxes around text": "调高可扩大文本框并覆盖完整词语；调低会更贴合文字",
    "Text Recognition Confidence": "文字识别置信度",
    "Minimum confidence level for detected text (higher = fewer false positives)": "检测文字的最低置信度（越高误识别越少）",
    "Translation": "翻译",
    "Text Translation Method": "文字翻译方式",
    "Free, no API key needed": "免费，无需 API 密钥",
    "Good quality for most languages": "适合大多数语言",
    "High quality translations": "高质量翻译",
    "Very quick": "速度很快",
    "Control": "控制",
    "Quick Translation Shortcut": "快捷翻译按键",
    "Select which buttons to hold to start translaton": "选择长按哪些按键开始翻译",
    "Both Touchpads Touch": "同时触摸两侧触控板",
    "Hold Time to Start": "启动长按时间",
    "Seconds to hold button(s) to translate": "长按多少秒开始翻译",
    "Hold Time to Dismiss": "关闭长按时间",
    "Seconds to hold button(s) to dismiss overlay": "长按多少秒关闭翻译浮层",
    "Quick toggle with Right Button": "用右侧按键快速切换",
    "If double buttons combination is selected, press right button to toggle overlay visibility": "选择双键组合后，可按右侧按键显示或隐藏浮层",
    "Display": "显示",
    "Font Scaling": "字体缩放",
    "Increase if translated text is too small. Can be useful for large external monitors": "译文字体过小时可调高，外接大屏时也很实用",
    "Text Blocks Grouping": "文本块合并",
    "Normal - Keeps text blocks separated": "普通：保持文本块分离",
    "Increased - Merges text blocks": "增强：合并相邻文本块",
    "Large - Merges distant text blocks": "较大：合并较远文本块",
    "Huge - Merges very distant text blocks": "最大：合并距离很远的文本块",
    "Hide Identical Translations": "隐藏相同译文",
    "Don't display if translation is the same as original word/sentence": "译文与原词句相同时不显示",
    "Allow Labels to Expand": "允许标签扩展",
    "Let translated labels grow wider if the text doesn't fit the original box": "译文放不下时允许标签扩宽",
    "Behavior": "行为",
    "Pause Game While Translating": "翻译时暂停游戏",
    "Pauses the active game and allows you to read the text more thoughtfully. The game is resumed when overlay is dismissed": "显示译文时暂停当前游戏，关闭浮层后继续运行",
    "Miscellaneous": "其它",
    "Debug Mode": "调试模式",
    "Enable verbose console logging and diagnostics panel": "启用详细日志和诊断面板",
    "Status:": "状态：",
    "Input mode:": "输入方式：",
    "Input active:": "输入状态：",
    "Buttons pressed:": "已按按键：",
    "Plugin State:": "插件状态：",
    "Timings:": "计时：",
    "Dismiss": "关闭",
    "Input language is not set": "尚未设置原文语言",
    "Output language is not set": "尚未设置目标语言",
    "Output and Input languages are not set": "尚未设置原文和目标语言",
    "Please select it in the plugin settings": "请在插件设置中选择语言",
    "Input and output languages can not be the same": "原文语言和目标语言不能相同",
    "Select change them in plugin settings": "请在插件设置中修改语言",
    "Processing": "正在处理",
    "Recognizing text": "正在识别文字",
    "Translating text": "正在翻译文字",
    "No text found": "未识别到文字",
    "No internet connection": "网络连接不可用",
    "Invalid API key": "API 密钥无效",
    "API key required for OCR & Translation": "文字识别和翻译需要 API 密钥",
    "API key required for OCR": "文字识别需要 API 密钥",
    "API key required for Translation": "翻译需要 API 密钥",
    "Please configure your Google Cloud API key in settings or switch to a free provider.": "请在设置中填写 Google Cloud API 密钥，或切换到免费服务。"
};
const normalize = (value) => String(value ?? "").replace(/\s+/g, " ").trim();
function translateNode(node) {
    if (node.nodeType === Node.TEXT_NODE) {
        const original = node.nodeValue ?? "";
        const normalized = normalize(original);
        const translated = ZH[normalized];
        if (translated)
            node.nodeValue = original.replace(normalized, translated);
        return;
    }
    if (!(node instanceof Element))
        return;
    for (const attribute of ["aria-label", "title", "placeholder"]) {
        const value = node.getAttribute(attribute);
        const translated = ZH[normalize(value)];
        if (translated)
            node.setAttribute(attribute, translated);
    }
    const walker = document.createTreeWalker(node, NodeFilter.SHOW_TEXT);
    while (walker.nextNode())
        translateNode(walker.currentNode);
}
function installChineseUi() {
    translateNode(document.body);
    const observer = new MutationObserver((records) => {
        for (const record of records) {
            if (record.type === "characterData")
                translateNode(record.target);
            record.addedNodes.forEach(translateNode);
        }
    });
    observer.observe(document.body, { childList: true, characterData: true, subtree: true });
    return () => observer.disconnect();
}

// THIS FILE IS AUTO GENERATED
function SiKofi (props) {
  return GenIcon({"attr":{"role":"img","viewBox":"0 0 24 24"},"child":[{"tag":"title","attr":{},"child":[]},{"tag":"path","attr":{"d":"M23.881 8.948c-.773-4.085-4.859-4.593-4.859-4.593H.723c-.604 0-.679.798-.679.798s-.082 7.324-.022 11.822c.164 2.424 2.586 2.672 2.586 2.672s8.267-.023 11.966-.049c2.438-.426 2.683-2.566 2.658-3.734 4.352.24 7.422-2.831 6.649-6.916zm-11.062 3.511c-1.246 1.453-4.011 3.976-4.011 3.976s-.121.119-.31.023c-.076-.057-.108-.09-.108-.09-.443-.441-3.368-3.049-4.034-3.954-.709-.965-1.041-2.7-.091-3.71.951-1.01 3.005-1.086 4.363.407 0 0 1.565-1.782 3.468-.963 1.904.82 1.832 3.011.723 4.311zm6.173.478c-.928.116-1.682.028-1.682.028V7.284h1.77s1.971.551 1.971 2.638c0 1.913-.985 2.667-2.059 3.015z"}}]})(props);
}

var __defProp = Object.defineProperty;
var __getOwnPropSymbols = Object.getOwnPropertySymbols;
var __hasOwnProp = Object.prototype.hasOwnProperty;
var __propIsEnum = Object.prototype.propertyIsEnumerable;
var __defNormalProp = (obj, key, value) => key in obj ? __defProp(obj, key, { enumerable: true, configurable: true, writable: true, value }) : obj[key] = value;
var __spreadValues = (a, b) => {
  for (var prop in b || (b = {}))
    if (__hasOwnProp.call(b, prop))
      __defNormalProp(a, prop, b[prop]);
  if (__getOwnPropSymbols)
    for (var prop of __getOwnPropSymbols(b)) {
      if (__propIsEnum.call(b, prop))
        __defNormalProp(a, prop, b[prop]);
    }
  return a;
};
var __objRest = (source, exclude) => {
  var target = {};
  for (var prop in source)
    if (__hasOwnProp.call(source, prop) && exclude.indexOf(prop) < 0)
      target[prop] = source[prop];
  if (source != null && __getOwnPropSymbols)
    for (var prop of __getOwnPropSymbols(source)) {
      if (exclude.indexOf(prop) < 0 && __propIsEnum.call(source, prop))
        target[prop] = source[prop];
    }
  return target;
};

// src/index.tsx


// src/third-party/qrcodegen/index.ts
/**
 * @license QR Code generator library (TypeScript)
 * Copyright (c) Project Nayuki.
 * SPDX-License-Identifier: MIT
 */
var qrcodegen;
((qrcodegen2) => {
  const _QrCode = class _QrCode {
    /*-- Constructor (low level) and fields --*/
    // Creates a new QR Code with the given version number,
    // error correction level, data codeword bytes, and mask number.
    // This is a low-level API that most users should not use directly.
    // A mid-level API is the encodeSegments() function.
    constructor(version, errorCorrectionLevel, dataCodewords, msk) {
      this.version = version;
      this.errorCorrectionLevel = errorCorrectionLevel;
      // The modules of this QR Code (false = light, true = dark).
      // Immutable after constructor finishes. Accessed through getModule().
      this.modules = [];
      // Indicates function modules that are not subjected to masking. Discarded when constructor finishes.
      this.isFunction = [];
      if (version < _QrCode.MIN_VERSION || version > _QrCode.MAX_VERSION)
        throw new RangeError("Version value out of range");
      if (msk < -1 || msk > 7)
        throw new RangeError("Mask value out of range");
      this.size = version * 4 + 17;
      let row = [];
      for (let i = 0; i < this.size; i++)
        row.push(false);
      for (let i = 0; i < this.size; i++) {
        this.modules.push(row.slice());
        this.isFunction.push(row.slice());
      }
      this.drawFunctionPatterns();
      const allCodewords = this.addEccAndInterleave(dataCodewords);
      this.drawCodewords(allCodewords);
      if (msk == -1) {
        let minPenalty = 1e9;
        for (let i = 0; i < 8; i++) {
          this.applyMask(i);
          this.drawFormatBits(i);
          const penalty = this.getPenaltyScore();
          if (penalty < minPenalty) {
            msk = i;
            minPenalty = penalty;
          }
          this.applyMask(i);
        }
      }
      assert(0 <= msk && msk <= 7);
      this.mask = msk;
      this.applyMask(msk);
      this.drawFormatBits(msk);
      this.isFunction = [];
    }
    /*-- Static factory functions (high level) --*/
    // Returns a QR Code representing the given Unicode text string at the given error correction level.
    // As a conservative upper bound, this function is guaranteed to succeed for strings that have 738 or fewer
    // Unicode code points (not UTF-16 code units) if the low error correction level is used. The smallest possible
    // QR Code version is automatically chosen for the output. The ECC level of the result may be higher than the
    // ecl argument if it can be done without increasing the version.
    static encodeText(text, ecl) {
      const segs = qrcodegen2.QrSegment.makeSegments(text);
      return _QrCode.encodeSegments(segs, ecl);
    }
    // Returns a QR Code representing the given binary data at the given error correction level.
    // This function always encodes using the binary segment mode, not any text mode. The maximum number of
    // bytes allowed is 2953. The smallest possible QR Code version is automatically chosen for the output.
    // The ECC level of the result may be higher than the ecl argument if it can be done without increasing the version.
    static encodeBinary(data, ecl) {
      const seg = qrcodegen2.QrSegment.makeBytes(data);
      return _QrCode.encodeSegments([seg], ecl);
    }
    /*-- Static factory functions (mid level) --*/
    // Returns a QR Code representing the given segments with the given encoding parameters.
    // The smallest possible QR Code version within the given range is automatically
    // chosen for the output. Iff boostEcl is true, then the ECC level of the result
    // may be higher than the ecl argument if it can be done without increasing the
    // version. The mask number is either between 0 to 7 (inclusive) to force that
    // mask, or -1 to automatically choose an appropriate mask (which may be slow).
    // This function allows the user to create a custom sequence of segments that switches
    // between modes (such as alphanumeric and byte) to encode text in less space.
    // This is a mid-level API; the high-level API is encodeText() and encodeBinary().
    static encodeSegments(segs, ecl, minVersion = 1, maxVersion = 40, mask = -1, boostEcl = true) {
      if (!(_QrCode.MIN_VERSION <= minVersion && minVersion <= maxVersion && maxVersion <= _QrCode.MAX_VERSION) || mask < -1 || mask > 7)
        throw new RangeError("Invalid value");
      let version;
      let dataUsedBits;
      for (version = minVersion; ; version++) {
        const dataCapacityBits2 = _QrCode.getNumDataCodewords(version, ecl) * 8;
        const usedBits = QrSegment.getTotalBits(segs, version);
        if (usedBits <= dataCapacityBits2) {
          dataUsedBits = usedBits;
          break;
        }
        if (version >= maxVersion)
          throw new RangeError("Data too long");
      }
      for (const newEcl of [_QrCode.Ecc.MEDIUM, _QrCode.Ecc.QUARTILE, _QrCode.Ecc.HIGH]) {
        if (boostEcl && dataUsedBits <= _QrCode.getNumDataCodewords(version, newEcl) * 8)
          ecl = newEcl;
      }
      let bb = [];
      for (const seg of segs) {
        appendBits(seg.mode.modeBits, 4, bb);
        appendBits(seg.numChars, seg.mode.numCharCountBits(version), bb);
        for (const b of seg.getData())
          bb.push(b);
      }
      assert(bb.length == dataUsedBits);
      const dataCapacityBits = _QrCode.getNumDataCodewords(version, ecl) * 8;
      assert(bb.length <= dataCapacityBits);
      appendBits(0, Math.min(4, dataCapacityBits - bb.length), bb);
      appendBits(0, (8 - bb.length % 8) % 8, bb);
      assert(bb.length % 8 == 0);
      for (let padByte = 236; bb.length < dataCapacityBits; padByte ^= 236 ^ 17)
        appendBits(padByte, 8, bb);
      let dataCodewords = [];
      while (dataCodewords.length * 8 < bb.length)
        dataCodewords.push(0);
      bb.forEach((b, i) => dataCodewords[i >>> 3] |= b << 7 - (i & 7));
      return new _QrCode(version, ecl, dataCodewords, mask);
    }
    /*-- Accessor methods --*/
    // Returns the color of the module (pixel) at the given coordinates, which is false
    // for light or true for dark. The top left corner has the coordinates (x=0, y=0).
    // If the given coordinates are out of bounds, then false (light) is returned.
    getModule(x, y) {
      return 0 <= x && x < this.size && 0 <= y && y < this.size && this.modules[y][x];
    }
    // Modified to expose modules for easy access
    getModules() {
      return this.modules;
    }
    /*-- Private helper methods for constructor: Drawing function modules --*/
    // Reads this object's version field, and draws and marks all function modules.
    drawFunctionPatterns() {
      for (let i = 0; i < this.size; i++) {
        this.setFunctionModule(6, i, i % 2 == 0);
        this.setFunctionModule(i, 6, i % 2 == 0);
      }
      this.drawFinderPattern(3, 3);
      this.drawFinderPattern(this.size - 4, 3);
      this.drawFinderPattern(3, this.size - 4);
      const alignPatPos = this.getAlignmentPatternPositions();
      const numAlign = alignPatPos.length;
      for (let i = 0; i < numAlign; i++) {
        for (let j = 0; j < numAlign; j++) {
          if (!(i == 0 && j == 0 || i == 0 && j == numAlign - 1 || i == numAlign - 1 && j == 0))
            this.drawAlignmentPattern(alignPatPos[i], alignPatPos[j]);
        }
      }
      this.drawFormatBits(0);
      this.drawVersion();
    }
    // Draws two copies of the format bits (with its own error correction code)
    // based on the given mask and this object's error correction level field.
    drawFormatBits(mask) {
      const data = this.errorCorrectionLevel.formatBits << 3 | mask;
      let rem = data;
      for (let i = 0; i < 10; i++)
        rem = rem << 1 ^ (rem >>> 9) * 1335;
      const bits = (data << 10 | rem) ^ 21522;
      assert(bits >>> 15 == 0);
      for (let i = 0; i <= 5; i++)
        this.setFunctionModule(8, i, getBit(bits, i));
      this.setFunctionModule(8, 7, getBit(bits, 6));
      this.setFunctionModule(8, 8, getBit(bits, 7));
      this.setFunctionModule(7, 8, getBit(bits, 8));
      for (let i = 9; i < 15; i++)
        this.setFunctionModule(14 - i, 8, getBit(bits, i));
      for (let i = 0; i < 8; i++)
        this.setFunctionModule(this.size - 1 - i, 8, getBit(bits, i));
      for (let i = 8; i < 15; i++)
        this.setFunctionModule(8, this.size - 15 + i, getBit(bits, i));
      this.setFunctionModule(8, this.size - 8, true);
    }
    // Draws two copies of the version bits (with its own error correction code),
    // based on this object's version field, iff 7 <= version <= 40.
    drawVersion() {
      if (this.version < 7)
        return;
      let rem = this.version;
      for (let i = 0; i < 12; i++)
        rem = rem << 1 ^ (rem >>> 11) * 7973;
      const bits = this.version << 12 | rem;
      assert(bits >>> 18 == 0);
      for (let i = 0; i < 18; i++) {
        const color = getBit(bits, i);
        const a = this.size - 11 + i % 3;
        const b = Math.floor(i / 3);
        this.setFunctionModule(a, b, color);
        this.setFunctionModule(b, a, color);
      }
    }
    // Draws a 9*9 finder pattern including the border separator,
    // with the center module at (x, y). Modules can be out of bounds.
    drawFinderPattern(x, y) {
      for (let dy = -4; dy <= 4; dy++) {
        for (let dx = -4; dx <= 4; dx++) {
          const dist = Math.max(Math.abs(dx), Math.abs(dy));
          const xx = x + dx;
          const yy = y + dy;
          if (0 <= xx && xx < this.size && 0 <= yy && yy < this.size)
            this.setFunctionModule(xx, yy, dist != 2 && dist != 4);
        }
      }
    }
    // Draws a 5*5 alignment pattern, with the center module
    // at (x, y). All modules must be in bounds.
    drawAlignmentPattern(x, y) {
      for (let dy = -2; dy <= 2; dy++) {
        for (let dx = -2; dx <= 2; dx++)
          this.setFunctionModule(x + dx, y + dy, Math.max(Math.abs(dx), Math.abs(dy)) != 1);
      }
    }
    // Sets the color of a module and marks it as a function module.
    // Only used by the constructor. Coordinates must be in bounds.
    setFunctionModule(x, y, isDark) {
      this.modules[y][x] = isDark;
      this.isFunction[y][x] = true;
    }
    /*-- Private helper methods for constructor: Codewords and masking --*/
    // Returns a new byte string representing the given data with the appropriate error correction
    // codewords appended to it, based on this object's version and error correction level.
    addEccAndInterleave(data) {
      const ver = this.version;
      const ecl = this.errorCorrectionLevel;
      if (data.length != _QrCode.getNumDataCodewords(ver, ecl))
        throw new RangeError("Invalid argument");
      const numBlocks = _QrCode.NUM_ERROR_CORRECTION_BLOCKS[ecl.ordinal][ver];
      const blockEccLen = _QrCode.ECC_CODEWORDS_PER_BLOCK[ecl.ordinal][ver];
      const rawCodewords = Math.floor(_QrCode.getNumRawDataModules(ver) / 8);
      const numShortBlocks = numBlocks - rawCodewords % numBlocks;
      const shortBlockLen = Math.floor(rawCodewords / numBlocks);
      let blocks = [];
      const rsDiv = _QrCode.reedSolomonComputeDivisor(blockEccLen);
      for (let i = 0, k = 0; i < numBlocks; i++) {
        let dat = data.slice(k, k + shortBlockLen - blockEccLen + (i < numShortBlocks ? 0 : 1));
        k += dat.length;
        const ecc = _QrCode.reedSolomonComputeRemainder(dat, rsDiv);
        if (i < numShortBlocks)
          dat.push(0);
        blocks.push(dat.concat(ecc));
      }
      let result = [];
      for (let i = 0; i < blocks[0].length; i++) {
        blocks.forEach((block, j) => {
          if (i != shortBlockLen - blockEccLen || j >= numShortBlocks)
            result.push(block[i]);
        });
      }
      assert(result.length == rawCodewords);
      return result;
    }
    // Draws the given sequence of 8-bit codewords (data and error correction) onto the entire
    // data area of this QR Code. Function modules need to be marked off before this is called.
    drawCodewords(data) {
      if (data.length != Math.floor(_QrCode.getNumRawDataModules(this.version) / 8))
        throw new RangeError("Invalid argument");
      let i = 0;
      for (let right = this.size - 1; right >= 1; right -= 2) {
        if (right == 6)
          right = 5;
        for (let vert = 0; vert < this.size; vert++) {
          for (let j = 0; j < 2; j++) {
            const x = right - j;
            const upward = (right + 1 & 2) == 0;
            const y = upward ? this.size - 1 - vert : vert;
            if (!this.isFunction[y][x] && i < data.length * 8) {
              this.modules[y][x] = getBit(data[i >>> 3], 7 - (i & 7));
              i++;
            }
          }
        }
      }
      assert(i == data.length * 8);
    }
    // XORs the codeword modules in this QR Code with the given mask pattern.
    // The function modules must be marked and the codeword bits must be drawn
    // before masking. Due to the arithmetic of XOR, calling applyMask() with
    // the same mask value a second time will undo the mask. A final well-formed
    // QR Code needs exactly one (not zero, two, etc.) mask applied.
    applyMask(mask) {
      if (mask < 0 || mask > 7)
        throw new RangeError("Mask value out of range");
      for (let y = 0; y < this.size; y++) {
        for (let x = 0; x < this.size; x++) {
          let invert;
          switch (mask) {
            case 0:
              invert = (x + y) % 2 == 0;
              break;
            case 1:
              invert = y % 2 == 0;
              break;
            case 2:
              invert = x % 3 == 0;
              break;
            case 3:
              invert = (x + y) % 3 == 0;
              break;
            case 4:
              invert = (Math.floor(x / 3) + Math.floor(y / 2)) % 2 == 0;
              break;
            case 5:
              invert = x * y % 2 + x * y % 3 == 0;
              break;
            case 6:
              invert = (x * y % 2 + x * y % 3) % 2 == 0;
              break;
            case 7:
              invert = ((x + y) % 2 + x * y % 3) % 2 == 0;
              break;
            default:
              throw new Error("Unreachable");
          }
          if (!this.isFunction[y][x] && invert)
            this.modules[y][x] = !this.modules[y][x];
        }
      }
    }
    // Calculates and returns the penalty score based on state of this QR Code's current modules.
    // This is used by the automatic mask choice algorithm to find the mask pattern that yields the lowest score.
    getPenaltyScore() {
      let result = 0;
      for (let y = 0; y < this.size; y++) {
        let runColor = false;
        let runX = 0;
        let runHistory = [0, 0, 0, 0, 0, 0, 0];
        for (let x = 0; x < this.size; x++) {
          if (this.modules[y][x] == runColor) {
            runX++;
            if (runX == 5)
              result += _QrCode.PENALTY_N1;
            else if (runX > 5)
              result++;
          } else {
            this.finderPenaltyAddHistory(runX, runHistory);
            if (!runColor)
              result += this.finderPenaltyCountPatterns(runHistory) * _QrCode.PENALTY_N3;
            runColor = this.modules[y][x];
            runX = 1;
          }
        }
        result += this.finderPenaltyTerminateAndCount(runColor, runX, runHistory) * _QrCode.PENALTY_N3;
      }
      for (let x = 0; x < this.size; x++) {
        let runColor = false;
        let runY = 0;
        let runHistory = [0, 0, 0, 0, 0, 0, 0];
        for (let y = 0; y < this.size; y++) {
          if (this.modules[y][x] == runColor) {
            runY++;
            if (runY == 5)
              result += _QrCode.PENALTY_N1;
            else if (runY > 5)
              result++;
          } else {
            this.finderPenaltyAddHistory(runY, runHistory);
            if (!runColor)
              result += this.finderPenaltyCountPatterns(runHistory) * _QrCode.PENALTY_N3;
            runColor = this.modules[y][x];
            runY = 1;
          }
        }
        result += this.finderPenaltyTerminateAndCount(runColor, runY, runHistory) * _QrCode.PENALTY_N3;
      }
      for (let y = 0; y < this.size - 1; y++) {
        for (let x = 0; x < this.size - 1; x++) {
          const color = this.modules[y][x];
          if (color == this.modules[y][x + 1] && color == this.modules[y + 1][x] && color == this.modules[y + 1][x + 1])
            result += _QrCode.PENALTY_N2;
        }
      }
      let dark = 0;
      for (const row of this.modules)
        dark = row.reduce((sum, color) => sum + (color ? 1 : 0), dark);
      const total = this.size * this.size;
      const k = Math.ceil(Math.abs(dark * 20 - total * 10) / total) - 1;
      assert(0 <= k && k <= 9);
      result += k * _QrCode.PENALTY_N4;
      assert(0 <= result && result <= 2568888);
      return result;
    }
    /*-- Private helper functions --*/
    // Returns an ascending list of positions of alignment patterns for this version number.
    // Each position is in the range [0,177), and are used on both the x and y axes.
    // This could be implemented as lookup table of 40 variable-length lists of integers.
    getAlignmentPatternPositions() {
      if (this.version == 1)
        return [];
      else {
        const numAlign = Math.floor(this.version / 7) + 2;
        const step = this.version == 32 ? 26 : Math.ceil((this.version * 4 + 4) / (numAlign * 2 - 2)) * 2;
        let result = [6];
        for (let pos = this.size - 7; result.length < numAlign; pos -= step)
          result.splice(1, 0, pos);
        return result;
      }
    }
    // Returns the number of data bits that can be stored in a QR Code of the given version number, after
    // all function modules are excluded. This includes remainder bits, so it might not be a multiple of 8.
    // The result is in the range [208, 29648]. This could be implemented as a 40-entry lookup table.
    static getNumRawDataModules(ver) {
      if (ver < _QrCode.MIN_VERSION || ver > _QrCode.MAX_VERSION)
        throw new RangeError("Version number out of range");
      let result = (16 * ver + 128) * ver + 64;
      if (ver >= 2) {
        const numAlign = Math.floor(ver / 7) + 2;
        result -= (25 * numAlign - 10) * numAlign - 55;
        if (ver >= 7)
          result -= 36;
      }
      assert(208 <= result && result <= 29648);
      return result;
    }
    // Returns the number of 8-bit data (i.e. not error correction) codewords contained in any
    // QR Code of the given version number and error correction level, with remainder bits discarded.
    // This stateless pure function could be implemented as a (40*4)-cell lookup table.
    static getNumDataCodewords(ver, ecl) {
      return Math.floor(_QrCode.getNumRawDataModules(ver) / 8) - _QrCode.ECC_CODEWORDS_PER_BLOCK[ecl.ordinal][ver] * _QrCode.NUM_ERROR_CORRECTION_BLOCKS[ecl.ordinal][ver];
    }
    // Returns a Reed-Solomon ECC generator polynomial for the given degree. This could be
    // implemented as a lookup table over all possible parameter values, instead of as an algorithm.
    static reedSolomonComputeDivisor(degree) {
      if (degree < 1 || degree > 255)
        throw new RangeError("Degree out of range");
      let result = [];
      for (let i = 0; i < degree - 1; i++)
        result.push(0);
      result.push(1);
      let root = 1;
      for (let i = 0; i < degree; i++) {
        for (let j = 0; j < result.length; j++) {
          result[j] = _QrCode.reedSolomonMultiply(result[j], root);
          if (j + 1 < result.length)
            result[j] ^= result[j + 1];
        }
        root = _QrCode.reedSolomonMultiply(root, 2);
      }
      return result;
    }
    // Returns the Reed-Solomon error correction codeword for the given data and divisor polynomials.
    static reedSolomonComputeRemainder(data, divisor) {
      let result = divisor.map((_) => 0);
      for (const b of data) {
        const factor = b ^ result.shift();
        result.push(0);
        divisor.forEach((coef, i) => result[i] ^= _QrCode.reedSolomonMultiply(coef, factor));
      }
      return result;
    }
    // Returns the product of the two given field elements modulo GF(2^8/0x11D). The arguments and result
    // are unsigned 8-bit integers. This could be implemented as a lookup table of 256*256 entries of uint8.
    static reedSolomonMultiply(x, y) {
      if (x >>> 8 != 0 || y >>> 8 != 0)
        throw new RangeError("Byte out of range");
      let z = 0;
      for (let i = 7; i >= 0; i--) {
        z = z << 1 ^ (z >>> 7) * 285;
        z ^= (y >>> i & 1) * x;
      }
      assert(z >>> 8 == 0);
      return z;
    }
    // Can only be called immediately after a light run is added, and
    // returns either 0, 1, or 2. A helper function for getPenaltyScore().
    finderPenaltyCountPatterns(runHistory) {
      const n = runHistory[1];
      assert(n <= this.size * 3);
      const core = n > 0 && runHistory[2] == n && runHistory[3] == n * 3 && runHistory[4] == n && runHistory[5] == n;
      return (core && runHistory[0] >= n * 4 && runHistory[6] >= n ? 1 : 0) + (core && runHistory[6] >= n * 4 && runHistory[0] >= n ? 1 : 0);
    }
    // Must be called at the end of a line (row or column) of modules. A helper function for getPenaltyScore().
    finderPenaltyTerminateAndCount(currentRunColor, currentRunLength, runHistory) {
      if (currentRunColor) {
        this.finderPenaltyAddHistory(currentRunLength, runHistory);
        currentRunLength = 0;
      }
      currentRunLength += this.size;
      this.finderPenaltyAddHistory(currentRunLength, runHistory);
      return this.finderPenaltyCountPatterns(runHistory);
    }
    // Pushes the given value to the front and drops the last value. A helper function for getPenaltyScore().
    finderPenaltyAddHistory(currentRunLength, runHistory) {
      if (runHistory[0] == 0)
        currentRunLength += this.size;
      runHistory.pop();
      runHistory.unshift(currentRunLength);
    }
  };
  /*-- Constants and tables --*/
  // The minimum version number supported in the QR Code Model 2 standard.
  _QrCode.MIN_VERSION = 1;
  // The maximum version number supported in the QR Code Model 2 standard.
  _QrCode.MAX_VERSION = 40;
  // For use in getPenaltyScore(), when evaluating which mask is best.
  _QrCode.PENALTY_N1 = 3;
  _QrCode.PENALTY_N2 = 3;
  _QrCode.PENALTY_N3 = 40;
  _QrCode.PENALTY_N4 = 10;
  _QrCode.ECC_CODEWORDS_PER_BLOCK = [
    // Version: (note that index 0 is for padding, and is set to an illegal value)
    //0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40    Error correction level
    [-1, 7, 10, 15, 20, 26, 18, 20, 24, 30, 18, 20, 24, 26, 30, 22, 24, 28, 30, 28, 28, 28, 28, 30, 30, 26, 28, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30],
    // Low
    [-1, 10, 16, 26, 18, 24, 16, 18, 22, 22, 26, 30, 22, 22, 24, 24, 28, 28, 26, 26, 26, 26, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28],
    // Medium
    [-1, 13, 22, 18, 26, 18, 24, 18, 22, 20, 24, 28, 26, 24, 20, 30, 24, 28, 28, 26, 30, 28, 30, 30, 30, 30, 28, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30],
    // Quartile
    [-1, 17, 28, 22, 16, 22, 28, 26, 26, 24, 28, 24, 28, 22, 24, 24, 30, 28, 28, 26, 28, 30, 24, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30]
    // High
  ];
  _QrCode.NUM_ERROR_CORRECTION_BLOCKS = [
    // Version: (note that index 0 is for padding, and is set to an illegal value)
    //0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40    Error correction level
    [-1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 4, 4, 4, 4, 4, 6, 6, 6, 6, 7, 8, 8, 9, 9, 10, 12, 12, 12, 13, 14, 15, 16, 17, 18, 19, 19, 20, 21, 22, 24, 25],
    // Low
    [-1, 1, 1, 1, 2, 2, 4, 4, 4, 5, 5, 5, 8, 9, 9, 10, 10, 11, 13, 14, 16, 17, 17, 18, 20, 21, 23, 25, 26, 28, 29, 31, 33, 35, 37, 38, 40, 43, 45, 47, 49],
    // Medium
    [-1, 1, 1, 2, 2, 4, 4, 6, 6, 8, 8, 8, 10, 12, 16, 12, 17, 16, 18, 21, 20, 23, 23, 25, 27, 29, 34, 34, 35, 38, 40, 43, 45, 48, 51, 53, 56, 59, 62, 65, 68],
    // Quartile
    [-1, 1, 1, 2, 4, 4, 4, 5, 6, 8, 8, 11, 11, 16, 16, 18, 16, 19, 21, 25, 25, 25, 34, 30, 32, 35, 37, 40, 42, 45, 48, 51, 54, 57, 60, 63, 66, 70, 74, 77, 81]
    // High
  ];
  qrcodegen2.QrCode = _QrCode;
  function appendBits(val, len, bb) {
    if (len < 0 || len > 31 || val >>> len != 0)
      throw new RangeError("Value out of range");
    for (let i = len - 1; i >= 0; i--)
      bb.push(val >>> i & 1);
  }
  function getBit(x, i) {
    return (x >>> i & 1) != 0;
  }
  function assert(cond) {
    if (!cond)
      throw new Error("Assertion error");
  }
  const _QrSegment = class _QrSegment {
    /*-- Constructor (low level) and fields --*/
    // Creates a new QR Code segment with the given attributes and data.
    // The character count (numChars) must agree with the mode and the bit buffer length,
    // but the constraint isn't checked. The given bit buffer is cloned and stored.
    constructor(mode, numChars, bitData) {
      this.mode = mode;
      this.numChars = numChars;
      this.bitData = bitData;
      if (numChars < 0)
        throw new RangeError("Invalid argument");
      this.bitData = bitData.slice();
    }
    /*-- Static factory functions (mid level) --*/
    // Returns a segment representing the given binary data encoded in
    // byte mode. All input byte arrays are acceptable. Any text string
    // can be converted to UTF-8 bytes and encoded as a byte mode segment.
    static makeBytes(data) {
      let bb = [];
      for (const b of data)
        appendBits(b, 8, bb);
      return new _QrSegment(_QrSegment.Mode.BYTE, data.length, bb);
    }
    // Returns a segment representing the given string of decimal digits encoded in numeric mode.
    static makeNumeric(digits) {
      if (!_QrSegment.isNumeric(digits))
        throw new RangeError("String contains non-numeric characters");
      let bb = [];
      for (let i = 0; i < digits.length; ) {
        const n = Math.min(digits.length - i, 3);
        appendBits(parseInt(digits.substring(i, i + n), 10), n * 3 + 1, bb);
        i += n;
      }
      return new _QrSegment(_QrSegment.Mode.NUMERIC, digits.length, bb);
    }
    // Returns a segment representing the given text string encoded in alphanumeric mode.
    // The characters allowed are: 0 to 9, A to Z (uppercase only), space,
    // dollar, percent, asterisk, plus, hyphen, period, slash, colon.
    static makeAlphanumeric(text) {
      if (!_QrSegment.isAlphanumeric(text))
        throw new RangeError("String contains unencodable characters in alphanumeric mode");
      let bb = [];
      let i;
      for (i = 0; i + 2 <= text.length; i += 2) {
        let temp = _QrSegment.ALPHANUMERIC_CHARSET.indexOf(text.charAt(i)) * 45;
        temp += _QrSegment.ALPHANUMERIC_CHARSET.indexOf(text.charAt(i + 1));
        appendBits(temp, 11, bb);
      }
      if (i < text.length)
        appendBits(_QrSegment.ALPHANUMERIC_CHARSET.indexOf(text.charAt(i)), 6, bb);
      return new _QrSegment(_QrSegment.Mode.ALPHANUMERIC, text.length, bb);
    }
    // Returns a new mutable list of zero or more segments to represent the given Unicode text string.
    // The result may use various segment modes and switch modes to optimize the length of the bit stream.
    static makeSegments(text) {
      if (text == "")
        return [];
      else if (_QrSegment.isNumeric(text))
        return [_QrSegment.makeNumeric(text)];
      else if (_QrSegment.isAlphanumeric(text))
        return [_QrSegment.makeAlphanumeric(text)];
      else
        return [_QrSegment.makeBytes(_QrSegment.toUtf8ByteArray(text))];
    }
    // Returns a segment representing an Extended Channel Interpretation
    // (ECI) designator with the given assignment value.
    static makeEci(assignVal) {
      let bb = [];
      if (assignVal < 0)
        throw new RangeError("ECI assignment value out of range");
      else if (assignVal < 1 << 7)
        appendBits(assignVal, 8, bb);
      else if (assignVal < 1 << 14) {
        appendBits(2, 2, bb);
        appendBits(assignVal, 14, bb);
      } else if (assignVal < 1e6) {
        appendBits(6, 3, bb);
        appendBits(assignVal, 21, bb);
      } else
        throw new RangeError("ECI assignment value out of range");
      return new _QrSegment(_QrSegment.Mode.ECI, 0, bb);
    }
    // Tests whether the given string can be encoded as a segment in numeric mode.
    // A string is encodable iff each character is in the range 0 to 9.
    static isNumeric(text) {
      return _QrSegment.NUMERIC_REGEX.test(text);
    }
    // Tests whether the given string can be encoded as a segment in alphanumeric mode.
    // A string is encodable iff each character is in the following set: 0 to 9, A to Z
    // (uppercase only), space, dollar, percent, asterisk, plus, hyphen, period, slash, colon.
    static isAlphanumeric(text) {
      return _QrSegment.ALPHANUMERIC_REGEX.test(text);
    }
    /*-- Methods --*/
    // Returns a new copy of the data bits of this segment.
    getData() {
      return this.bitData.slice();
    }
    // (Package-private) Calculates and returns the number of bits needed to encode the given segments at
    // the given version. The result is infinity if a segment has too many characters to fit its length field.
    static getTotalBits(segs, version) {
      let result = 0;
      for (const seg of segs) {
        const ccbits = seg.mode.numCharCountBits(version);
        if (seg.numChars >= 1 << ccbits)
          return Infinity;
        result += 4 + ccbits + seg.bitData.length;
      }
      return result;
    }
    // Returns a new array of bytes representing the given string encoded in UTF-8.
    static toUtf8ByteArray(str) {
      str = encodeURI(str);
      let result = [];
      for (let i = 0; i < str.length; i++) {
        if (str.charAt(i) != "%")
          result.push(str.charCodeAt(i));
        else {
          result.push(parseInt(str.substring(i + 1, i + 3), 16));
          i += 2;
        }
      }
      return result;
    }
  };
  /*-- Constants --*/
  // Describes precisely all strings that are encodable in numeric mode.
  _QrSegment.NUMERIC_REGEX = /^[0-9]*$/;
  // Describes precisely all strings that are encodable in alphanumeric mode.
  _QrSegment.ALPHANUMERIC_REGEX = /^[A-Z0-9 $%*+.\/:-]*$/;
  // The set of all legal characters in alphanumeric mode,
  // where each character value maps to the index in the string.
  _QrSegment.ALPHANUMERIC_CHARSET = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:";
  let QrSegment = _QrSegment;
  qrcodegen2.QrSegment = _QrSegment;
})(qrcodegen || (qrcodegen = {}));
((qrcodegen2) => {
  ((QrCode2) => {
    const _Ecc = class _Ecc {
      // The QR Code can tolerate about 30% erroneous codewords
      /*-- Constructor and fields --*/
      constructor(ordinal, formatBits) {
        this.ordinal = ordinal;
        this.formatBits = formatBits;
      }
    };
    /*-- Constants --*/
    _Ecc.LOW = new _Ecc(0, 1);
    // The QR Code can tolerate about  7% erroneous codewords
    _Ecc.MEDIUM = new _Ecc(1, 0);
    // The QR Code can tolerate about 15% erroneous codewords
    _Ecc.QUARTILE = new _Ecc(2, 3);
    // The QR Code can tolerate about 25% erroneous codewords
    _Ecc.HIGH = new _Ecc(3, 2);
    QrCode2.Ecc = _Ecc;
  })(qrcodegen2.QrCode || (qrcodegen2.QrCode = {}));
})(qrcodegen || (qrcodegen = {}));
((qrcodegen2) => {
  ((QrSegment2) => {
    const _Mode = class _Mode {
      /*-- Constructor and fields --*/
      constructor(modeBits, numBitsCharCount) {
        this.modeBits = modeBits;
        this.numBitsCharCount = numBitsCharCount;
      }
      /*-- Method --*/
      // (Package-private) Returns the bit width of the character count field for a segment in
      // this mode in a QR Code at the given version number. The result is in the range [0, 16].
      numCharCountBits(ver) {
        return this.numBitsCharCount[Math.floor((ver + 7) / 17)];
      }
    };
    /*-- Constants --*/
    _Mode.NUMERIC = new _Mode(1, [10, 12, 14]);
    _Mode.ALPHANUMERIC = new _Mode(2, [9, 11, 13]);
    _Mode.BYTE = new _Mode(4, [8, 16, 16]);
    _Mode.KANJI = new _Mode(8, [8, 10, 12]);
    _Mode.ECI = new _Mode(7, [0, 0, 0]);
    QrSegment2.Mode = _Mode;
  })(qrcodegen2.QrSegment || (qrcodegen2.QrSegment = {}));
})(qrcodegen || (qrcodegen = {}));
var qrcodegen_default = qrcodegen;

// src/index.tsx
/**
 * @license qrcode.react
 * Copyright (c) Paul O'Shannessy
 * SPDX-License-Identifier: ISC
 */
var ERROR_LEVEL_MAP = {
  L: qrcodegen_default.QrCode.Ecc.LOW,
  M: qrcodegen_default.QrCode.Ecc.MEDIUM,
  Q: qrcodegen_default.QrCode.Ecc.QUARTILE,
  H: qrcodegen_default.QrCode.Ecc.HIGH
};
var DEFAULT_SIZE = 128;
var DEFAULT_LEVEL = "L";
var DEFAULT_BGCOLOR = "#FFFFFF";
var DEFAULT_FGCOLOR = "#000000";
var DEFAULT_INCLUDEMARGIN = false;
var DEFAULT_MINVERSION = 1;
var SPEC_MARGIN_SIZE = 4;
var DEFAULT_MARGIN_SIZE = 0;
var DEFAULT_IMG_SCALE = 0.1;
function generatePath(modules, margin = 0) {
  const ops = [];
  modules.forEach(function(row, y) {
    let start = null;
    row.forEach(function(cell, x) {
      if (!cell && start !== null) {
        ops.push(
          `M${start + margin} ${y + margin}h${x - start}v1H${start + margin}z`
        );
        start = null;
        return;
      }
      if (x === row.length - 1) {
        if (!cell) {
          return;
        }
        if (start === null) {
          ops.push(`M${x + margin},${y + margin} h1v1H${x + margin}z`);
        } else {
          ops.push(
            `M${start + margin},${y + margin} h${x + 1 - start}v1H${start + margin}z`
          );
        }
        return;
      }
      if (cell && start === null) {
        start = x;
      }
    });
  });
  return ops.join("");
}
function excavateModules(modules, excavation) {
  return modules.slice().map((row, y) => {
    if (y < excavation.y || y >= excavation.y + excavation.h) {
      return row;
    }
    return row.map((cell, x) => {
      if (x < excavation.x || x >= excavation.x + excavation.w) {
        return cell;
      }
      return false;
    });
  });
}
function getImageSettings(cells, size, margin, imageSettings) {
  if (imageSettings == null) {
    return null;
  }
  const numCells = cells.length + margin * 2;
  const defaultSize = Math.floor(size * DEFAULT_IMG_SCALE);
  const scale = numCells / size;
  const w = (imageSettings.width || defaultSize) * scale;
  const h = (imageSettings.height || defaultSize) * scale;
  const x = imageSettings.x == null ? cells.length / 2 - w / 2 : imageSettings.x * scale;
  const y = imageSettings.y == null ? cells.length / 2 - h / 2 : imageSettings.y * scale;
  const opacity = imageSettings.opacity == null ? 1 : imageSettings.opacity;
  let excavation = null;
  if (imageSettings.excavate) {
    let floorX = Math.floor(x);
    let floorY = Math.floor(y);
    let ceilW = Math.ceil(w + x - floorX);
    let ceilH = Math.ceil(h + y - floorY);
    excavation = { x: floorX, y: floorY, w: ceilW, h: ceilH };
  }
  const crossOrigin = imageSettings.crossOrigin;
  return { x, y, h, w, excavation, opacity, crossOrigin };
}
function getMarginSize(includeMargin, marginSize) {
  if (marginSize != null) {
    return Math.max(Math.floor(marginSize), 0);
  }
  return includeMargin ? SPEC_MARGIN_SIZE : DEFAULT_MARGIN_SIZE;
}
function useQRCode({
  value,
  level,
  minVersion,
  includeMargin,
  marginSize,
  imageSettings,
  size,
  boostLevel
}) {
  let qrcode = SP_REACT.useMemo(() => {
    const values = Array.isArray(value) ? value : [value];
    const segments = values.reduce((accum, v) => {
      accum.push(...qrcodegen_default.QrSegment.makeSegments(v));
      return accum;
    }, []);
    return qrcodegen_default.QrCode.encodeSegments(
      segments,
      ERROR_LEVEL_MAP[level],
      minVersion,
      void 0,
      void 0,
      boostLevel
    );
  }, [value, level, minVersion, boostLevel]);
  const { cells, margin, numCells, calculatedImageSettings } = SP_REACT.useMemo(() => {
    let cells2 = qrcode.getModules();
    const margin2 = getMarginSize(includeMargin, marginSize);
    const numCells2 = cells2.length + margin2 * 2;
    const calculatedImageSettings2 = getImageSettings(
      cells2,
      size,
      margin2,
      imageSettings
    );
    return {
      cells: cells2,
      margin: margin2,
      numCells: numCells2,
      calculatedImageSettings: calculatedImageSettings2
    };
  }, [qrcode, size, imageSettings, includeMargin, marginSize]);
  return {
    qrcode,
    margin,
    cells,
    numCells,
    calculatedImageSettings
  };
}
var SUPPORTS_PATH2D = function() {
  try {
    new Path2D().addPath(new Path2D());
  } catch (e) {
    return false;
  }
  return true;
}();
var QRCodeCanvas = SP_REACT.forwardRef(
  function QRCodeCanvas2(props, forwardedRef) {
    const _a = props, {
      value,
      size = DEFAULT_SIZE,
      level = DEFAULT_LEVEL,
      bgColor = DEFAULT_BGCOLOR,
      fgColor = DEFAULT_FGCOLOR,
      includeMargin = DEFAULT_INCLUDEMARGIN,
      minVersion = DEFAULT_MINVERSION,
      boostLevel,
      marginSize,
      imageSettings
    } = _a, extraProps = __objRest(_a, [
      "value",
      "size",
      "level",
      "bgColor",
      "fgColor",
      "includeMargin",
      "minVersion",
      "boostLevel",
      "marginSize",
      "imageSettings"
    ]);
    const _b = extraProps, { style } = _b, otherProps = __objRest(_b, ["style"]);
    const imgSrc = imageSettings == null ? void 0 : imageSettings.src;
    const _canvas = SP_REACT.useRef(null);
    const _image = SP_REACT.useRef(null);
    const setCanvasRef = SP_REACT.useCallback(
      (node) => {
        _canvas.current = node;
        if (typeof forwardedRef === "function") {
          forwardedRef(node);
        } else if (forwardedRef) {
          forwardedRef.current = node;
        }
      },
      [forwardedRef]
    );
    const [isImgLoaded, setIsImageLoaded] = SP_REACT.useState(false);
    const { margin, cells, numCells, calculatedImageSettings } = useQRCode({
      value,
      level,
      minVersion,
      boostLevel,
      includeMargin,
      marginSize,
      imageSettings,
      size
    });
    SP_REACT.useEffect(() => {
      if (_canvas.current != null) {
        const canvas = _canvas.current;
        const ctx = canvas.getContext("2d");
        if (!ctx) {
          return;
        }
        let cellsToDraw = cells;
        const image = _image.current;
        const haveImageToRender = calculatedImageSettings != null && image !== null && image.complete && image.naturalHeight !== 0 && image.naturalWidth !== 0;
        if (haveImageToRender) {
          if (calculatedImageSettings.excavation != null) {
            cellsToDraw = excavateModules(
              cells,
              calculatedImageSettings.excavation
            );
          }
        }
        const pixelRatio = window.devicePixelRatio || 1;
        canvas.height = canvas.width = size * pixelRatio;
        const scale = size / numCells * pixelRatio;
        ctx.scale(scale, scale);
        ctx.fillStyle = bgColor;
        ctx.fillRect(0, 0, numCells, numCells);
        ctx.fillStyle = fgColor;
        if (SUPPORTS_PATH2D) {
          ctx.fill(new Path2D(generatePath(cellsToDraw, margin)));
        } else {
          cells.forEach(function(row, rdx) {
            row.forEach(function(cell, cdx) {
              if (cell) {
                ctx.fillRect(cdx + margin, rdx + margin, 1, 1);
              }
            });
          });
        }
        if (calculatedImageSettings) {
          ctx.globalAlpha = calculatedImageSettings.opacity;
        }
        if (haveImageToRender) {
          ctx.drawImage(
            image,
            calculatedImageSettings.x + margin,
            calculatedImageSettings.y + margin,
            calculatedImageSettings.w,
            calculatedImageSettings.h
          );
        }
      }
    });
    SP_REACT.useEffect(() => {
      setIsImageLoaded(false);
    }, [imgSrc]);
    const canvasStyle = __spreadValues({ height: size, width: size }, style);
    let img = null;
    if (imgSrc != null) {
      img = /* @__PURE__ */ SP_REACT.createElement(
        "img",
        {
          src: imgSrc,
          key: imgSrc,
          style: { display: "none" },
          onLoad: () => {
            setIsImageLoaded(true);
          },
          ref: _image,
          crossOrigin: calculatedImageSettings == null ? void 0 : calculatedImageSettings.crossOrigin
        }
      );
    }
    return /* @__PURE__ */ SP_REACT.createElement(SP_REACT.Fragment, null, /* @__PURE__ */ SP_REACT.createElement(
      "canvas",
      __spreadValues({
        style: canvasStyle,
        height: size,
        width: size,
        ref: setCanvasRef,
        role: "img"
      }, otherProps)
    ), img);
  }
);
QRCodeCanvas.displayName = "QRCodeCanvas";
var QRCodeSVG = SP_REACT.forwardRef(
  function QRCodeSVG2(props, forwardedRef) {
    const _a = props, {
      value,
      size = DEFAULT_SIZE,
      level = DEFAULT_LEVEL,
      bgColor = DEFAULT_BGCOLOR,
      fgColor = DEFAULT_FGCOLOR,
      includeMargin = DEFAULT_INCLUDEMARGIN,
      minVersion = DEFAULT_MINVERSION,
      boostLevel,
      title,
      marginSize,
      imageSettings
    } = _a, otherProps = __objRest(_a, [
      "value",
      "size",
      "level",
      "bgColor",
      "fgColor",
      "includeMargin",
      "minVersion",
      "boostLevel",
      "title",
      "marginSize",
      "imageSettings"
    ]);
    const { margin, cells, numCells, calculatedImageSettings } = useQRCode({
      value,
      level,
      minVersion,
      boostLevel,
      includeMargin,
      marginSize,
      imageSettings,
      size
    });
    let cellsToDraw = cells;
    let image = null;
    if (imageSettings != null && calculatedImageSettings != null) {
      if (calculatedImageSettings.excavation != null) {
        cellsToDraw = excavateModules(
          cells,
          calculatedImageSettings.excavation
        );
      }
      image = /* @__PURE__ */ SP_REACT.createElement(
        "image",
        {
          href: imageSettings.src,
          height: calculatedImageSettings.h,
          width: calculatedImageSettings.w,
          x: calculatedImageSettings.x + margin,
          y: calculatedImageSettings.y + margin,
          preserveAspectRatio: "none",
          opacity: calculatedImageSettings.opacity,
          crossOrigin: calculatedImageSettings.crossOrigin
        }
      );
    }
    const fgPath = generatePath(cellsToDraw, margin);
    return /* @__PURE__ */ SP_REACT.createElement(
      "svg",
      __spreadValues({
        height: size,
        width: size,
        viewBox: `0 0 ${numCells} ${numCells}`,
        ref: forwardedRef,
        role: "img"
      }, otherProps),
      !!title && /* @__PURE__ */ SP_REACT.createElement("title", null, title),
      /* @__PURE__ */ SP_REACT.createElement(
        "path",
        {
          fill: bgColor,
          d: `M0,0 h${numCells}v${numCells}H0z`,
          shapeRendering: "crispEdges"
        }
      ),
      /* @__PURE__ */ SP_REACT.createElement("path", { fill: fgColor, d: fgPath, shapeRendering: "crispEdges" }),
      image
    );
  }
);
QRCodeSVG.displayName = "QRCodeSVG";

const showQrModal = (url) => {
    DFL.showModal(window.SP_REACT.createElement(DFL.ModalRoot, null,
        window.SP_REACT.createElement(QRCodeSVG, { style: { margin: '0 auto 1.5em auto', display: 'block' }, value: url, includeMargin: true, size: 256 }),
        window.SP_REACT.createElement("span", { style: { textAlign: 'center', wordBreak: 'break-word', display: 'block' } }, url)), window);
};

// src/tabs/TabMain.tsx - Main tab with enable toggle and translate button

const StatusDot = ({ ok }) => (window.SP_REACT.createElement("span", { style: {
        display: 'inline-block',
        width: '5px',
        height: '5px',
        borderRadius: '50%',
        backgroundColor: ok ? '#4caf50' : '#ff6b6b',
        marginRight: '6px',
        flexShrink: 0
    } }));
const PendingDot = () => (window.SP_REACT.createElement("span", { style: {
        display: 'inline-block',
        width: '5px',
        height: '5px',
        borderRadius: '50%',
        backgroundColor: '#888',
        marginRight: '6px',
        flexShrink: 0
    } }));
const InstallingDot = () => (window.SP_REACT.createElement("span", { style: {
        display: 'inline-block',
        width: '5px',
        height: '5px',
        borderRadius: '50%',
        backgroundColor: '#ffa726',
        marginRight: '6px',
        flexShrink: 0
    } }));
const ReachabilityRow = ({ result, expectedProvider }) => {
    if (!result || result.provider !== expectedProvider) {
        return (window.SP_REACT.createElement("div", { style: { color: '#666', fontSize: '10px', display: 'flex', alignItems: 'center' } },
            window.SP_REACT.createElement(PendingDot, null),
            window.SP_REACT.createElement("span", null, "Checking...")));
    }
    return (window.SP_REACT.createElement("div", { style: { color: '#666', fontSize: '10px', display: 'flex', alignItems: 'center' } },
        window.SP_REACT.createElement(StatusDot, { ok: result.ok }),
        window.SP_REACT.createElement("span", null, result.ok ? 'Ready' : `Not ready (${result.reason || 'unreachable'})`)));
};
const TabMain = ({ logic, overlayVisible, providerStatus, webReachability, onNavigateToTab }) => {
    const { settings, updateSetting } = useSettings();
    const ocrNeedsDownload = !!providerStatus
        && ((settings.ocrProvider === 'chromescreenai' && !providerStatus.chromescreenai_downloaded)
            || (settings.ocrProvider === 'rapidocr' && !providerStatus.rapidocr_downloaded));
    const translationNeedsDownload = settings.ocrProvider !== 'gemini_vision'
        && settings.translationProvider === 'ct2'
        && !!providerStatus
        && !providerStatus.nllb_downloaded;
    const handleButtonClick = () => {
        if (overlayVisible) {
            logic.dismiss();
            DFL.Router.CloseSideMenus();
            return;
        }
        if (ocrNeedsDownload) {
            const target = settings.ocrProvider === 'rapidocr' ? 'rapidocr-action' : 'chromescreenai-action';
            onNavigateToTab('translation', target);
            return;
        }
        if (translationNeedsDownload) {
            onNavigateToTab('translation', 'ct2-action');
            return;
        }
        // Close menu first, then wait for UI to fully close before taking screenshot
        DFL.Router.CloseSideMenus();
        setTimeout(() => {
            logic.takeScreenshotAndTranslate().catch(err => logger.error('TabMain', 'Screenshot failed', err));
        }, 200);
    };
    const renderButtonContent = () => {
        if (overlayVisible) {
            return window.SP_REACT.createElement("span", { style: { display: "inline-flex", alignItems: "center", gap: "8px" } },
                window.SP_REACT.createElement(BsXLg, null),
                " Close Overlay");
        }
        if (ocrNeedsDownload || translationNeedsDownload) {
            return window.SP_REACT.createElement("span", { style: { display: "inline-flex", alignItems: "center", gap: "8px" } },
                window.SP_REACT.createElement(HiInboxArrowDown, { size: 20 }),
                " Download required");
        }
        return window.SP_REACT.createElement("span", { style: { display: "inline-flex", alignItems: "center", gap: "8px" } },
            window.SP_REACT.createElement(BsTranslate, null),
            " Translate");
    };
    return (window.SP_REACT.createElement("div", null,
        window.SP_REACT.createElement(DFL.PanelSection, null,
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.ToggleField, { label: settings.enabled ? "Plugin is enabled" : "Plugin is disabled", description: "Toggle the functionality on or off", checked: settings.enabled, onChange: (value) => updateSetting('enabled', value, 'Decky Translator') })),
            settings.enabled && (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                    window.SP_REACT.createElement(DFL.ButtonItem, { bottomSeparator: "standard", layout: "below", onClick: handleButtonClick }, renderButtonContent())),
                window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                    window.SP_REACT.createElement("div", { style: { fontSize: '12px', marginTop: '8px' } },
                        settings.ocrProvider === 'gemini_vision' && (window.SP_REACT.createElement("div", { style: { display: 'flex', alignItems: 'center', marginBottom: '4px' } },
                            window.SP_REACT.createElement(BsStars, { style: { marginRight: '8px', color: '#aaa' } }),
                            window.SP_REACT.createElement("span", { style: { color: '#888' } }, "Recognize + Translate:"),
                            window.SP_REACT.createElement("span", { style: { marginLeft: '6px', fontWeight: 'bold' } }, "Gemini"))),
                        settings.ocrProvider !== 'gemini_vision' && (window.SP_REACT.createElement("div", { style: { display: 'flex', alignItems: 'center', marginBottom: '4px' } },
                            window.SP_REACT.createElement(BsEye, { style: { marginRight: '8px', color: '#aaa' } }),
                            window.SP_REACT.createElement("span", { style: { color: '#888' } }, "Text Recognition:"),
                            window.SP_REACT.createElement("span", { style: { marginLeft: '6px', fontWeight: 'bold' } }, settings.ocrProvider === 'chromescreenai' ? 'On-Device' :
                                settings.ocrProvider === 'rapidocr' ? 'On-Device' :
                                    settings.ocrProvider === 'ocrspace' ? 'OCR.space' : 'Google Cloud'))),
                        settings.ocrProvider === 'rapidocr' && (window.SP_REACT.createElement("div", { style: { marginLeft: '22px', marginBottom: '6px' } },
                            providerStatus?.rapidocr_downloaded && (window.SP_REACT.createElement("div", { style: { color: '#666', fontSize: '10px' } },
                                "Installed model: RapidOCR",
                                providerStatus?.rapidocr_info?.version ? ` v${providerStatus.rapidocr_info.version}` : '')),
                            window.SP_REACT.createElement("div", { style: { color: '#666', fontSize: '10px', display: 'flex', alignItems: 'center' } }, providerStatus?.rapidocr_downloading ? (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                                window.SP_REACT.createElement(InstallingDot, null),
                                window.SP_REACT.createElement("span", null, "Installing..."))) : (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                                window.SP_REACT.createElement(StatusDot, { ok: !!providerStatus?.rapidocr_downloaded }),
                                window.SP_REACT.createElement("span", null, providerStatus?.rapidocr_downloaded ? 'Ready' : 'Not ready (Model not installed)')))))),
                        settings.ocrProvider === 'chromescreenai' && (window.SP_REACT.createElement("div", { style: { marginLeft: '22px', marginBottom: '6px' } },
                            providerStatus?.chromescreenai_downloaded && (window.SP_REACT.createElement("div", { style: { color: '#666', fontSize: '10px', marginBottom: '4px' } }, "Engine: Chrome Screen AI")),
                            window.SP_REACT.createElement("div", { style: { color: '#666', fontSize: '10px', display: 'flex', alignItems: 'center' } }, providerStatus?.chromescreenai_downloading ? (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                                window.SP_REACT.createElement(InstallingDot, null),
                                window.SP_REACT.createElement("span", null, "Installing..."))) : (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                                window.SP_REACT.createElement(StatusDot, { ok: !!providerStatus?.chromescreenai_downloaded }),
                                window.SP_REACT.createElement("span", null, providerStatus?.chromescreenai_downloaded ? 'Ready' : 'Not ready (Engine not installed)')))))),
                        settings.ocrProvider === 'googlecloud' && (window.SP_REACT.createElement("div", { style: { marginLeft: '22px', marginBottom: '6px' } },
                            window.SP_REACT.createElement(ReachabilityRow, { result: webReachability?.ocr, expectedProvider: "googlecloud" }))),
                        settings.ocrProvider === 'ocrspace' && (window.SP_REACT.createElement("div", { style: { marginLeft: '22px', marginBottom: '6px' } },
                            window.SP_REACT.createElement("div", { style: { color: '#666', fontSize: '10px', marginBottom: '4px' } }, "Free, no API key needed"),
                            providerStatus?.ocr_usage && (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                                window.SP_REACT.createElement("div", { style: {
                                        display: 'flex',
                                        justifyContent: 'space-between',
                                        alignItems: 'center',
                                        marginBottom: '3px'
                                    } },
                                    window.SP_REACT.createElement("span", { style: { color: '#666', fontSize: '10px' } }, "10 min limit:"),
                                    window.SP_REACT.createElement("span", { style: {
                                            fontSize: '10px',
                                            color: providerStatus.ocr_usage.rate_remaining <= 2 ? '#ff6b6b' : '#888'
                                        } },
                                        providerStatus.ocr_usage.rate_remaining,
                                        "/",
                                        providerStatus.ocr_usage.rate_limit)),
                                window.SP_REACT.createElement("div", { style: {
                                        height: '3px',
                                        backgroundColor: 'rgba(255,255,255,0.1)',
                                        borderRadius: '2px',
                                        overflow: 'hidden',
                                        marginBottom: '4px'
                                    } },
                                    window.SP_REACT.createElement("div", { style: {
                                            height: '100%',
                                            width: `${(providerStatus.ocr_usage.rate_remaining / providerStatus.ocr_usage.rate_limit) * 100}%`,
                                            backgroundColor: providerStatus.ocr_usage.rate_remaining <= 2
                                                ? '#ff6b6b'
                                                : providerStatus.ocr_usage.rate_remaining <= 5
                                                    ? '#ffa726'
                                                    : '#4caf50',
                                            borderRadius: '2px',
                                            transition: 'width 0.3s ease'
                                        } })),
                                providerStatus.ocr_usage.rate_remaining === 0 && providerStatus.ocr_usage.rate_reset_seconds > 0 && (window.SP_REACT.createElement("div", { style: { color: '#ff6b6b', fontSize: '10px', marginBottom: '4px' } },
                                    "Rate limit exceeded - resets in ",
                                    Math.ceil(providerStatus.ocr_usage.rate_reset_seconds / 60),
                                    " min")),
                                window.SP_REACT.createElement("div", { style: {
                                        display: 'flex',
                                        justifyContent: 'space-between',
                                        alignItems: 'center',
                                        marginBottom: '3px'
                                    } },
                                    window.SP_REACT.createElement("span", { style: { color: '#666', fontSize: '10px' } }, "Daily limit:"),
                                    window.SP_REACT.createElement("span", { style: {
                                            fontSize: '10px',
                                            color: providerStatus.ocr_usage.remaining < 50 ? '#ff6b6b' : '#888'
                                        } },
                                        providerStatus.ocr_usage.remaining,
                                        "/",
                                        providerStatus.ocr_usage.limit)),
                                window.SP_REACT.createElement("div", { style: {
                                        height: '3px',
                                        backgroundColor: 'rgba(255,255,255,0.1)',
                                        borderRadius: '2px',
                                        overflow: 'hidden',
                                        marginBottom: '4px'
                                    } },
                                    window.SP_REACT.createElement("div", { style: {
                                            height: '100%',
                                            width: `${(providerStatus.ocr_usage.remaining / providerStatus.ocr_usage.limit) * 100}%`,
                                            backgroundColor: providerStatus.ocr_usage.remaining < 50
                                                ? '#ff6b6b'
                                                : providerStatus.ocr_usage.remaining < 100
                                                    ? '#ffa726'
                                                    : '#4caf50',
                                            borderRadius: '2px',
                                            transition: 'width 0.3s ease'
                                        } })),
                                providerStatus.ocr_usage.remaining < 50 && (window.SP_REACT.createElement("div", { style: { color: '#ff6b6b', fontSize: '10px', marginBottom: '4px' } }, "Low daily requests remaining")))),
                            window.SP_REACT.createElement(ReachabilityRow, { result: webReachability?.ocr, expectedProvider: "ocrspace" }))),
                        settings.ocrProvider !== 'gemini_vision' && (window.SP_REACT.createElement("div", { style: { display: 'flex', alignItems: 'center', marginBottom: '2px' } },
                            window.SP_REACT.createElement(BsTranslate, { style: { marginRight: '8px', color: '#aaa' } }),
                            window.SP_REACT.createElement("span", { style: { color: '#888' } }, "Translation:"),
                            window.SP_REACT.createElement("span", { style: { marginLeft: '6px', fontWeight: 'bold' } }, settings.translationProvider === 'googlecloud' ? 'Google Cloud' :
                                settings.translationProvider === 'ct2' ? 'On-Device' : 'Google Translate'))),
                        window.SP_REACT.createElement("div", { style: { marginLeft: '22px', marginBottom: '6px' } },
                            settings.ocrProvider === 'gemini_vision' && (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                                window.SP_REACT.createElement("div", { style: { color: '#666', fontSize: '10px' } },
                                    "Model: ",
                                    settings.geminiModel.replace(/^gemini-/, '').split('-').map((w) => w.charAt(0).toUpperCase() + w.slice(1)).join(' ')),
                                window.SP_REACT.createElement(ReachabilityRow, { result: webReachability?.ocr, expectedProvider: "gemini_vision" }))),
                            settings.ocrProvider !== 'gemini_vision' && settings.translationProvider === 'freegoogle' && (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                                window.SP_REACT.createElement("div", { style: { color: '#666', fontSize: '10px' } }, "No API key needed"),
                                window.SP_REACT.createElement(ReachabilityRow, { result: webReachability?.translation, expectedProvider: "freegoogle" }))),
                            settings.ocrProvider !== 'gemini_vision' && settings.translationProvider === 'googlecloud' && (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                                window.SP_REACT.createElement(ReachabilityRow, { result: webReachability?.translation, expectedProvider: "googlecloud" }))),
                            settings.ocrProvider !== 'gemini_vision' && settings.translationProvider === 'ct2' && (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                                providerStatus?.nllb_downloaded && (window.SP_REACT.createElement("div", { style: { color: '#666', fontSize: '10px' } }, "Model: NLLB-200 1.3B")),
                                window.SP_REACT.createElement("div", { style: { color: '#666', fontSize: '10px', display: 'flex', alignItems: 'center' } }, providerStatus?.nllb_downloading ? (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                                    window.SP_REACT.createElement(InstallingDot, null),
                                    window.SP_REACT.createElement("span", null, "Installing..."))) : (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                                    window.SP_REACT.createElement(StatusDot, { ok: !!providerStatus?.nllb_downloaded }),
                                    window.SP_REACT.createElement("span", null, providerStatus?.nllb_downloaded ? 'Ready' : 'Not ready (Model not installed)'))))))))))),
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement("div", { style: {
                        display: 'flex',
                        justifyContent: 'center',
                        marginTop: '12px',
                    } },
                    window.SP_REACT.createElement(DFL.Focusable, null,
                        window.SP_REACT.createElement(DFL.DialogButton, { onClick: () => {
                                DFL.Navigation.CloseSideMenus();
                                DFL.Navigation.NavigateToExternalWeb('https://ko-fi.com/alexanderdev');
                            }, onSecondaryButton: () => showQrModal('https://ko-fi.com/alexanderdev'), onSecondaryActionDescription: "Show QR Code", style: {
                                display: 'flex',
                                alignItems: 'center',
                                gap: '8px',
                                padding: '6px 12px',
                                fontSize: '11px',
                                minWidth: 'auto',
                            } },
                            window.SP_REACT.createElement(SiKofi, { style: { fontSize: '13px' } }),
                            window.SP_REACT.createElement("span", null, "Support on Ko-fi"),
                            window.SP_REACT.createElement(HiQrCode, { style: { fontSize: '13px', opacity: 0.6 } }))))),
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement("div", { style: { fontSize: "12px", opacity: 0.72, textAlign: "center" } }, AUTHOR_NOTICE)))));
};

var ocrspaceLogo = 'http://127.0.0.1:1337/plugins/沉浸式翻译/assets/ocrspace-logo-58c0dfa3.png';

var googlecloudLogo = 'http://127.0.0.1:1337/plugins/沉浸式翻译/assets/googlecloud-logo-2d6a69b8.png';

var googletranslateLogo = 'http://127.0.0.1:1337/plugins/沉浸式翻译/assets/googletranslate-logo-2f4d4d7c.png';

var geminiLogo = 'http://127.0.0.1:1337/plugins/沉浸式翻译/assets/gemini-logo-f555a33e.png';

var steamdeckLogo = 'http://127.0.0.1:1337/plugins/沉浸式翻译/assets/steamdeck-logo-6b4919ff.png';

var chromeLogo = 'http://127.0.0.1:1337/plugins/沉浸式翻译/assets/chrome-logo-4c195a07.png';

// src/tabs/TabTranslation.tsx - Language and provider settings

// Language options with flag emojis
const languageOptions = [
    { label: "\ud83c\udf10 Auto-detect", data: "auto" },
    { label: "\ud83c\uddf8\ud83c\udde6 Arabic", data: "ar" },
    { label: "\ud83c\udde7\ud83c\uddec Bulgarian", data: "bg" },
    { label: "\ud83c\udde8\ud83c\uddf3 Chinese (Simplified)", data: "zh-CN" },
    { label: "\ud83c\uddf9\ud83c\uddfc Chinese (Traditional)", data: "zh-TW" },
    { label: "\ud83c\udded\ud83c\uddf7 Croatian", data: "hr" },
    { label: "\ud83c\udde8\ud83c\uddff Czech", data: "cs" },
    { label: "\ud83c\udde9\ud83c\uddf0 Danish", data: "da" },
    { label: "\ud83c\uddf3\ud83c\uddf1 Dutch", data: "nl" },
    { label: "\ud83c\uddec\ud83c\udde7 English", data: "en" },
    { label: "\ud83c\uddeb\ud83c\uddee Finnish", data: "fi" },
    { label: "\ud83c\uddeb\ud83c\uddf7 French", data: "fr" },
    { label: "\ud83c\udde9\ud83c\uddea German", data: "de" },
    { label: "\ud83c\uddec\ud83c\uddf7 Greek", data: "el" },
    { label: "\ud83c\uddee\ud83c\uddf3 Hindi", data: "hi" },
    { label: "\ud83c\udded\ud83c\uddfa Hungarian", data: "hu" },
    { label: "\ud83c\uddee\ud83c\uddf9 Italian", data: "it" },
    { label: "\ud83c\uddef\ud83c\uddf5 Japanese", data: "ja" },
    { label: "\ud83c\uddf0\ud83c\uddf7 Korean", data: "ko" },
    { label: "\ud83c\uddf3\ud83c\uddf4 Norwegian", data: "no" },
    { label: "\ud83c\uddf5\ud83c\uddf1 Polish", data: "pl" },
    { label: "\ud83c\uddf5\ud83c\uddf9 Portuguese", data: "pt" },
    { label: "\ud83c\uddf7\ud83c\uddf4 Romanian", data: "ro" },
    { label: "\ud83c\uddf7\ud83c\uddfa Russian", data: "ru" },
    { label: "\ud83c\uddea\ud83c\uddf8 Spanish", data: "es" },
    { label: "\ud83c\uddf8\ud83c\uddea Swedish", data: "sv" },
    { label: "\ud83c\uddf9\ud83c\udded Thai", data: "th" },
    { label: "\ud83c\uddf9\ud83c\uddf7 Turkish", data: "tr" },
    { label: "\ud83c\uddfa\ud83c\udde6 Ukrainian", data: "uk" },
    { label: "\ud83c\uddfb\ud83c\uddf3 Vietnamese", data: "vi" }
];
const selectLanguageOption = { label: "Select language...", data: "" };
const outputLanguageOptions = languageOptions.filter(lang => lang.data !== "auto");
// Languages RapidOCR able to work with
const rapidocrLanguages = new Set([
    'en', 'zh-CN', 'zh-TW', 'ja', 'ko',
    'de', 'fr', 'es', 'it', 'pt', 'nl', 'no', 'pl', 'tr', 'ro', 'vi', 'fi', 'hr',
    'cs', 'hu', 'sv', 'da',
    'ru', 'uk', 'el', 'th', 'bg'
]);
function formatBytes(bytes) {
    if (bytes < 1024)
        return bytes + ' B';
    if (bytes < 1024 * 1024)
        return Math.round(bytes / 1024) + ' KB';
    return Math.round(bytes / (1024 * 1024)) + ' MB';
}
// API Key Modal Component
const ApiKeyModal = ({ currentKey, onSave, closeModal, title, description }) => {
    const [apiKey, setApiKey] = SP_REACT.useState(currentKey || "");
    return (window.SP_REACT.createElement(DFL.ModalRoot, { onCancel: closeModal, onEscKeypress: closeModal },
        window.SP_REACT.createElement("div", { style: { padding: "20px", minWidth: "400px" } },
            window.SP_REACT.createElement("h2", { style: { marginBottom: "15px" } }, title || "API Key"),
            window.SP_REACT.createElement("p", { style: { marginBottom: "15px", color: "#aaa", fontSize: "13px" } }, description || "Enter your API key."),
            window.SP_REACT.createElement(DFL.TextField, { label: "API Key", value: apiKey, bIsPassword: true, bShowClearAction: true, onChange: (e) => setApiKey(e.target.value) }),
            window.SP_REACT.createElement(DFL.Focusable, { style: { display: "flex", gap: "10px", marginTop: "20px", justifyContent: "flex-end" } },
                window.SP_REACT.createElement(DFL.DialogButton, { onClick: closeModal }, "Cancel"),
                window.SP_REACT.createElement(DFL.DialogButton, { onClick: () => {
                        onSave(apiKey.trim());
                        closeModal?.();
                    } }, "Save")))));
};
const cacheProviderLabel = (p) => ({
    ct2: "On-Device",
    freegoogle: "Google Translate",
    googlecloud: "Google Cloud",
    gemini_vision: "Gemini Vision",
}[p] || p || "?");
const cacheLangFlag = (code) => {
    const opt = languageOptions.find(o => o.data === code);
    return opt ? opt.label.split(" ")[0] : code;
};
// compare by word content only, ignoring spacing, punctuation and case
const cacheWordContent = (s) => (s || "").toLowerCase().replace(/[^\p{L}\p{N}]+/gu, "");
const cacheSameText = (a, b) => cacheWordContent(a) === cacheWordContent(b);
// matches the backend MAX_ROWS eviction cap, so we load every cached entry
const CACHE_ENTRY_LIMIT = 50000;
const CACHE_PAGE_SIZE = 100;
const CacheEntriesModal = ({ closeModal, onCleared }) => {
    const [entries, setEntries] = SP_REACT.useState(null);
    const [filter, setFilter] = SP_REACT.useState("all");
    const [page, setPage] = SP_REACT.useState(0);
    const [confirmClear, setConfirmClear] = SP_REACT.useState(false);
    const wrapRef = SP_REACT.useRef(null);
    const trackRef = SP_REACT.useRef(null);
    const thumbRef = SP_REACT.useRef(null);
    const cycleFilter = () => {
        const order = ["unique", "identical", "all"];
        setFilter(f => order[(order.indexOf(f) + 1) % order.length]);
        setPage(0);
        setConfirmClear(false);
    };
    SP_REACT.useEffect(() => {
        call('get_translation_cache_entries', CACHE_ENTRY_LIMIT)
            .then((rows) => setEntries(rows || []))
            .catch(() => setEntries([]));
    }, []);
    const all = entries || [];
    const shown = filter === "all"
        ? all
        : all.filter(e => cacheSameText(e.source, e.translation) === (filter === "identical"));
    const totalPages = Math.max(1, Math.ceil(shown.length / CACHE_PAGE_SIZE));
    const pageItems = shown.slice(page * CACHE_PAGE_SIZE, (page + 1) * CACHE_PAGE_SIZE);
    SP_REACT.useEffect(() => {
        if (page >= totalPages)
            setPage(totalPages - 1);
    }, [totalPages, page]);
    SP_REACT.useEffect(() => {
        const sc = wrapRef.current?.querySelector(".dt-cache-scroll");
        const track = trackRef.current;
        const thumbEl = thumbRef.current;
        if (!sc || !track || !thumbEl)
            return;
        const update = () => {
            const h = sc.clientHeight;
            if (!sc.scrollHeight || sc.scrollHeight <= h) {
                track.style.display = "none";
                return;
            }
            track.style.display = "block";
            const height = Math.max(24, h * h / sc.scrollHeight);
            const range = sc.scrollHeight - h;
            const top = range > 0 ? (sc.scrollTop / range) * (h - height) : 0;
            thumbEl.style.height = `${height}px`;
            thumbEl.style.transform = `translateY(${top}px)`;
        };
        update();
        sc.addEventListener("scroll", update);
        return () => sc.removeEventListener("scroll", update);
    }, [entries, filter, page]);
    const removeEntry = async (e) => {
        await call('delete_translation_cache_entry', e.sourceLang, e.targetLang, e.source);
        setEntries(prev => prev ? prev.filter(x => !(x.sourceLang === e.sourceLang && x.targetLang === e.targetLang && x.source === e.source)) : prev);
    };
    // first press arms the button, second press actually clears
    const handleClear = async () => {
        if (!confirmClear) {
            setConfirmClear(true);
            return;
        }
        setConfirmClear(false);
        await call('clear_translation_cache');
        setEntries([]);
        onCleared?.();
    };
    const onThumbDown = (e) => {
        e.preventDefault();
        const sc = wrapRef.current?.querySelector(".dt-cache-scroll");
        if (!sc)
            return;
        const startY = e.clientY;
        const startScroll = sc.scrollTop;
        const track = sc.clientHeight;
        const thumbH = Math.max(24, track * track / sc.scrollHeight);
        const travel = track - thumbH;
        const scrollRange = sc.scrollHeight - track;
        const onMove = (ev) => {
            if (travel > 0)
                sc.scrollTop = startScroll + (ev.clientY - startY) * (scrollRange / travel);
        };
        const onUp = () => {
            document.removeEventListener("mousemove", onMove);
            document.removeEventListener("mouseup", onUp);
        };
        document.addEventListener("mousemove", onMove);
        document.addEventListener("mouseup", onUp);
    };
    const pagerButton = (label, enabled, onClick) => {
        const base = { minWidth: "auto", width: "auto", padding: "4px 14px", fontSize: "12px" };
        return enabled
            ? window.SP_REACT.createElement(DFL.DialogButton, { onClick: onClick, style: base }, label)
            : window.SP_REACT.createElement("div", { style: { ...base, opacity: 0.3, color: "#8b929a", display: "flex", alignItems: "center", justifyContent: "center", background: "rgba(255,255,255,0.05)", borderRadius: "2px" } }, label);
    };
    return (window.SP_REACT.createElement(DFL.ModalRoot, { onCancel: closeModal, onEscKeypress: closeModal },
        window.SP_REACT.createElement(DFL.Focusable, { style: { display: "flex", flexDirection: "column", maxHeight: "70vh", boxSizing: "border-box", minWidth: "540px" } },
            window.SP_REACT.createElement("div", { style: { display: "flex", alignItems: "center", justifyContent: "space-between", gap: "10px", marginBottom: "10px", flexShrink: 0 } },
                window.SP_REACT.createElement("div", { style: { fontSize: "16px", fontWeight: "bold" } },
                    filter === "all" ? "All" : filter === "unique" ? "Unique" : "Identical",
                    " Cached Translations",
                    entries !== null && window.SP_REACT.createElement("span", { style: { color: "rgba(255,255,255,0.45)" } },
                        " (",
                        shown.length,
                        ")")),
                all.length > 0 && (window.SP_REACT.createElement(DFL.Focusable, { style: { display: "flex", gap: "8px", alignItems: "center", flex: "0 0 auto" } },
                    window.SP_REACT.createElement(DFL.DialogButton, { onClick: cycleFilter, style: { width: "auto", minWidth: "auto", height: "32px", padding: "0 12px", whiteSpace: "nowrap", display: "flex", alignItems: "center", justifyContent: "center", fontSize: "13px" } },
                        "Showing: ",
                        filter === "all" ? "all" : `${filter} only`),
                    window.SP_REACT.createElement(DFL.DialogButton, { onClick: handleClear, style: { width: "auto", minWidth: "auto", height: "32px", padding: "0 12px", whiteSpace: "nowrap", display: "flex", alignItems: "center", justifyContent: "center", gap: "6px", fontSize: "13px", color: confirmClear ? "#ff4d4d" : undefined } },
                        confirmClear ? window.SP_REACT.createElement(HiExclamationTriangle, { style: { fontSize: "16px" } }) : window.SP_REACT.createElement(HiXCircle, { style: { fontSize: "16px" } }),
                        confirmClear ? "Are you sure?" : "Clear all")))),
            window.SP_REACT.createElement("style", null, `.dt-rowfocus { background: rgba(103,160,255,0.22) !important; }`),
            entries === null && window.SP_REACT.createElement("p", { style: { color: "#aaa" } }, "Loading..."),
            entries !== null && shown.length === 0 && (window.SP_REACT.createElement("p", { style: { color: "#aaa" } }, all.length === 0 ? "Nothing cached yet." : "Nothing to show.")),
            shown.length > 0 && (window.SP_REACT.createElement("div", { ref: wrapRef, style: { position: "relative", flex: "1 1 auto", minHeight: 0, display: "flex" } },
                window.SP_REACT.createElement(DFL.Focusable, { key: `${filter}-${page}`, className: "dt-cache-scroll", style: { flex: 1, overflowY: "scroll", display: "flex", flexDirection: "column", gap: "6px", paddingRight: "12px", paddingTop: "8px", paddingBottom: "8px" } }, pageItems.map((e) => (window.SP_REACT.createElement(DFL.Focusable, { key: `${e.sourceLang}|${e.targetLang}|${e.source}`, focusWithinClassName: "dt-rowfocus", style: { display: "flex", gap: "10px", alignItems: "center", paddingRight: "10px", background: "rgba(255,255,255,0.04)", borderRadius: "4px", scrollMargin: "8px" } },
                    window.SP_REACT.createElement(DFL.Focusable, { onActivate: () => { }, noFocusRing: true, style: { flex: "1 1 auto", minWidth: 0, display: "flex", flexDirection: "column", gap: "2px", padding: "8px 0 8px 10px", scrollMargin: "8px" } },
                        window.SP_REACT.createElement("div", { style: { display: "flex", justifyContent: "space-between", gap: "8px", color: "rgba(255,255,255,0.28)", fontSize: "9px" } },
                            window.SP_REACT.createElement("span", null,
                                window.SP_REACT.createElement("span", { style: { fontWeight: "bold" } }, "Translated with:"),
                                " ",
                                cacheProviderLabel(e.provider)),
                            window.SP_REACT.createElement("span", null,
                                window.SP_REACT.createElement("span", { style: { fontWeight: "bold" } }, "Date:"),
                                " ",
                                e.createdAt ? new Date(e.createdAt * 1000).toLocaleString([], { day: "numeric", month: "short", year: "numeric", hour: "2-digit", minute: "2-digit" }) : ""),
                            window.SP_REACT.createElement("span", null,
                                window.SP_REACT.createElement("span", { style: { fontWeight: "bold" } }, "Reused:"),
                                " ",
                                e.hits,
                                " ",
                                e.hits === 1 ? "time" : "times")),
                        window.SP_REACT.createElement("div", { style: { display: "flex", alignItems: "center", gap: "8px" } },
                            window.SP_REACT.createElement("span", { style: { fontSize: "14px", flexShrink: 0, width: "20px", textAlign: "center" } }, cacheLangFlag(e.sourceLang)),
                            window.SP_REACT.createElement("span", { style: { color: "#dcdedf", fontSize: "11px", flex: "1 1 auto", minWidth: 0 } }, e.source)),
                        window.SP_REACT.createElement("div", { style: { display: "flex", alignItems: "center", gap: "8px" } },
                            window.SP_REACT.createElement("span", { style: { fontSize: "14px", flexShrink: 0, width: "20px", textAlign: "center" } }, cacheLangFlag(e.targetLang)),
                            window.SP_REACT.createElement("span", { style: { color: "#6fcf97", fontStyle: "italic", fontSize: "11px", flex: "1 1 auto", minWidth: 0 } }, e.translation))),
                    window.SP_REACT.createElement(DFL.DialogButton, { onClick: () => removeEntry(e), style: { minWidth: "32px", width: "32px", height: "32px", padding: "0", flexShrink: 0, display: "flex", alignItems: "center", justifyContent: "center" } },
                        window.SP_REACT.createElement(HiTrash, null)))))),
                window.SP_REACT.createElement("div", { ref: trackRef, style: { position: "absolute", top: 0, right: "2px", width: "8px", height: "100%", borderRadius: "4px", background: "rgba(255,255,255,0.08)", display: "none" } },
                    window.SP_REACT.createElement("div", { ref: thumbRef, onMouseDown: onThumbDown, style: { position: "absolute", left: 0, width: "100%", height: 0, background: "rgba(255,255,255,0.4)", borderRadius: "4px", cursor: "pointer" } })))),
            totalPages > 1 && (window.SP_REACT.createElement(DFL.Focusable, { style: { display: "flex", alignItems: "center", justifyContent: "center", gap: "12px", marginTop: "8px", flexShrink: 0 } },
                pagerButton("Prev", page > 0, () => setPage(p => Math.max(0, p - 1))),
                window.SP_REACT.createElement("div", { style: { display: "flex", flexDirection: "column", alignItems: "center", minWidth: "80px" } },
                    window.SP_REACT.createElement("span", { style: { fontSize: "12px", color: "#8b929a" } },
                        "Page ",
                        page + 1,
                        " / ",
                        totalPages),
                    window.SP_REACT.createElement("span", { style: { fontSize: "9px", color: "rgba(255,255,255,0.28)" } },
                        pageItems.length,
                        " of ",
                        shown.length)),
                pagerButton("Next", page < totalPages - 1, () => setPage(p => Math.min(totalPages - 1, p + 1))))))));
};
const knownGeminiModels = [
    { label: window.SP_REACT.createElement("span", null, "2.5 Flash"), data: "gemini-2.5-flash" },
    { label: window.SP_REACT.createElement("span", null, "2.5 Flash Lite"), data: "gemini-2.5-flash-lite" },
    { label: window.SP_REACT.createElement("span", null, "3 Flash (Preview)"), data: "gemini-3-flash-preview" },
    { label: window.SP_REACT.createElement("span", null, "3 Flash"), data: "gemini-3-flash" },
    { label: window.SP_REACT.createElement("span", null, "3.1 Flash Lite (Preview)"), data: "gemini-3.1-flash-lite-preview" },
    { label: window.SP_REACT.createElement("span", null, "3.1 Flash Lite"), data: "gemini-3.1-flash-lite" },
];
const GeminiModelSelector = ({ selectedModel, hasApiKey, onChange }) => {
    const [models, setModels] = SP_REACT.useState(knownGeminiModels);
    const [loading, setLoading] = SP_REACT.useState(false);
    const [validated, setValidated] = SP_REACT.useState(false);
    const validateModels = async () => {
        if (!hasApiKey)
            return;
        setLoading(true);
        try {
            const available = await call('get_gemini_models');
            if (available && available.length > 0) {
                const availableSet = new Set(available);
                const filtered = knownGeminiModels.filter(m => availableSet.has(m.data));
                if (filtered.length > 0) {
                    setModels(filtered);
                    // If current selection was removed, switch to first available
                    if (!availableSet.has(selectedModel) && filtered.length > 0) {
                        onChange(filtered[0].data);
                    }
                }
            }
            setValidated(true);
        }
        catch (e) {
            // keep full list on error
        }
        setLoading(false);
    };
    // Validate when component mounts (user selected Gemini Vision)
    SP_REACT.useEffect(() => {
        if (hasApiKey && !validated) {
            validateModels();
        }
    }, [hasApiKey]);
    return (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
        window.SP_REACT.createElement("style", null, `@keyframes gemini-spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }`),
        window.SP_REACT.createElement(DFL.PanelSectionRow, null,
            window.SP_REACT.createElement(DFL.Field, { label: "Gemini Model", childrenContainerWidth: "max", childrenLayout: "below", focusable: false },
                window.SP_REACT.createElement(DFL.Focusable, { style: { display: "flex", gap: "8px", alignItems: "center" } },
                    window.SP_REACT.createElement("div", { style: { flex: 1 } },
                        window.SP_REACT.createElement(DFL.Dropdown, { rgOptions: models, selectedOption: selectedModel, onChange: (option) => onChange(option.data) })),
                    window.SP_REACT.createElement(DFL.DialogButton, { onClick: validateModels, disabled: loading || !hasApiKey, style: { minWidth: "40px", width: "40px", padding: "10px 0" } },
                        window.SP_REACT.createElement(BsArrowRepeat, { style: loading ? { animation: "gemini-spin 1s linear infinite" } : {} })))))));
};
function formatApproxSize(mb) {
    if (mb >= 1000) {
        return `${(mb / 1024).toFixed(1)} GB`;
    }
    return `${Math.round(mb)} MB`;
}
function useModelDownload(opts) {
    const [status, setStatus] = SP_REACT.useState({
        downloaded: false, size: 0, approx_size_mb: opts.defaultApproxMb,
        downloading: false, progress: 0, error: null,
    });
    const pollRef = SP_REACT.useRef(null);
    const refresh = SP_REACT.useCallback(async () => {
        try {
            const s = await call(opts.getStatusCall);
            if (s)
                setStatus(s);
        }
        catch (e) { /* ignore */ }
    }, [opts.getStatusCall]);
    SP_REACT.useEffect(() => { refresh(); }, []);
    SP_REACT.useEffect(() => {
        if (status.downloading) {
            pollRef.current = setInterval(refresh, 500);
        }
        else if (pollRef.current) {
            clearInterval(pollRef.current);
            pollRef.current = null;
        }
        return () => {
            if (pollRef.current)
                clearInterval(pollRef.current);
        };
    }, [status.downloading, refresh]);
    const handleDownload = async () => {
        await call(opts.clearErrorCall);
        const started = await call(opts.downloadCall);
        if (started) {
            setStatus((prev) => ({ ...prev, downloading: true, progress: 0, error: null }));
        }
    };
    const handleCancel = async () => { await call(opts.cancelCall); };
    const handleDelete = async () => { await call(opts.deleteCall); refresh(); };
    const isDownloading = status.downloading;
    const isDownloaded = status.downloaded;
    const progressPct = Math.round((status.progress || 0) * 100);
    const statusColor = isDownloading ? "#ffa726" : isDownloaded ? "#4caf50" : "#ff6b6b";
    const installedSize = status.size ? ` (${formatBytes(status.size)})` : '';
    const approxSize = status.approx_size_mb ? ` (${formatApproxSize(status.approx_size_mb)})` : '';
    const statusText = isDownloading
        ? `downloading ${progressPct}%`
        : isDownloaded
            ? `Installed${installedSize}`
            : `Not installed${approxSize}`;
    const ActionIcon = isDownloading ? HiXMark : isDownloaded ? HiTrash : HiInboxArrowDown;
    const onActionClick = isDownloading ? handleCancel : isDownloaded ? handleDelete : handleDownload;
    return { status, isDownloading, isDownloaded, progressPct, statusColor, statusText, ActionIcon, onActionClick };
}
function useChromeScreenAIStatus() {
    return useModelDownload({
        getStatusCall: 'get_chromescreenai_status',
        downloadCall: 'download_chromescreenai',
        cancelCall: 'cancel_chromescreenai_download',
        deleteCall: 'delete_chromescreenai',
        clearErrorCall: 'clear_chromescreenai_error',
        defaultApproxMb: 120,
    });
}
function useNllbModelStatus() {
    return useModelDownload({
        getStatusCall: 'get_nllb_model_status',
        downloadCall: 'download_nllb_model',
        cancelCall: 'cancel_nllb_download',
        deleteCall: 'delete_nllb_model',
        clearErrorCall: 'clear_nllb_model_error',
        defaultApproxMb: 1410,
    });
}
function useRapidOCRStatus() {
    return useModelDownload({
        getStatusCall: 'get_rapidocr_models_status',
        downloadCall: 'download_rapidocr_models',
        cancelCall: 'cancel_rapidocr_models_download',
        deleteCall: 'delete_rapidocr_models',
        clearErrorCall: 'clear_rapidocr_models_error',
        defaultApproxMb: 75,
    });
}
const ModelActionButton = ({ state, actionRef }) => {
    const { ActionIcon, onActionClick, isDownloaded, isDownloading } = state;
    const needsDownload = !isDownloaded && !isDownloading;
    return (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
        window.SP_REACT.createElement("style", null, `@keyframes dt-download-pulse { 0%, 100% { box-shadow: 0 0 0 0 rgba(255, 255, 255, 0); } 50% { box-shadow: 0 0 0 2px rgba(255, 255, 255, 0.45); } }`),
        window.SP_REACT.createElement(DFL.DialogButton, { ref: actionRef, onClick: onActionClick, style: {
                minWidth: "40px",
                width: "40px",
                padding: "10px 0",
                animation: needsDownload ? "dt-download-pulse 1.6s ease-in-out infinite" : undefined,
            } },
            window.SP_REACT.createElement(ActionIcon, { style: { transform: "scale(1.25) translateY(1px)" } }))));
};
const ModelStatusIndicator = ({ state }) => (window.SP_REACT.createElement("div", { style: {
        display: "flex",
        alignItems: "center",
        gap: "6px",
        marginBottom: "6px",
        marginLeft: "26px",
        fontSize: "11px",
    } },
    window.SP_REACT.createElement("div", { style: {
            width: "6px",
            height: "6px",
            borderRadius: "50%",
            backgroundColor: state.statusColor,
            flexShrink: 0,
        } }),
    window.SP_REACT.createElement("span", { style: { color: state.statusColor } }, state.statusText)));
const ModelHeadingProgressBar = ({ state }) => (state.isDownloading ? (window.SP_REACT.createElement("div", { style: {
        marginTop: "2px",
        marginBottom: "4px",
        marginLeft: "26px",
        height: "2px",
        backgroundColor: "rgba(255,255,255,0.1)",
        borderRadius: "2px",
        overflow: "hidden",
    } },
    window.SP_REACT.createElement("div", { style: {
            width: `${state.progressPct}%`,
            height: "100%",
            backgroundColor: state.statusColor,
            borderRadius: "2px",
            transition: "width 0.3s ease",
        } }))) : null);
const ModelDownloadError = ({ state }) => (state.status.error && !state.isDownloading ? (window.SP_REACT.createElement("div", { style: {
        color: "#ff6b6b",
        fontSize: "11px",
        marginTop: "6px",
        marginBottom: "4px",
        whiteSpace: "normal",
        wordBreak: "break-word",
    } }, state.status.error)) : null);
const StarRating = ({ label, filled, total = 3 }) => (window.SP_REACT.createElement("span", { style: { display: "flex", alignItems: "center", gap: "4px" } },
    window.SP_REACT.createElement("span", { style: { color: "#888", fontSize: "11px" } }, label),
    Array.from({ length: total }, (_, i) => (window.SP_REACT.createElement("svg", { key: i, width: "10", height: "10", viewBox: "0 0 24 24", fill: i < filled ? "#ffa726" : "#444" },
        window.SP_REACT.createElement("path", { d: "M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01z" }))))));
const ProviderRating = ({ quality, speed }) => (window.SP_REACT.createElement("div", { style: { display: "flex", gap: "16px", marginBottom: "6px" } },
    window.SP_REACT.createElement(StarRating, { label: "Quality", filled: quality }),
    window.SP_REACT.createElement(StarRating, { label: "Speed", filled: speed })));
const TabTranslation = ({ scrollTarget, onScrolled }) => {
    const { settings, updateSetting } = useSettings();
    const chromescreenaiActionRef = SP_REACT.useRef(null);
    const rapidocrActionRef = SP_REACT.useRef(null);
    const ct2ActionRef = SP_REACT.useRef(null);
    const csai = useChromeScreenAIStatus();
    const nllb = useNllbModelStatus();
    const rapidocr = useRapidOCRStatus();
    const [cacheEntries, setCacheEntries] = SP_REACT.useState(null);
    const refreshCacheStats = SP_REACT.useCallback(async () => {
        try {
            const stats = await call('get_translation_cache_stats');
            setCacheEntries(stats?.entries ?? 0);
        }
        catch {
            setCacheEntries(null);
        }
    }, []);
    SP_REACT.useEffect(() => {
        if (settings.translationCacheEnabled)
            refreshCacheStats();
    }, [settings.translationCacheEnabled, refreshCacheStats]);
    SP_REACT.useEffect(() => {
        if (!scrollTarget)
            return;
        const ref = scrollTarget === 'chromescreenai-action' ? chromescreenaiActionRef
            : scrollTarget === 'rapidocr-action' ? rapidocrActionRef
                : scrollTarget === 'ct2-action' ? ct2ActionRef
                    : null;
        // Wait for Steam's tab transition + focus router to settle before scrolling, otherwise our scroll gets overridden.
        const timeoutId = setTimeout(() => {
            const el = ref?.current;
            if (el) {
                el.focus({ preventScroll: true });
                el.scrollIntoView({ behavior: 'smooth', block: 'center' });
            }
            onScrolled?.();
        }, 400);
        return () => clearTimeout(timeoutId);
    }, [scrollTarget]);
    const isCT2 = settings.translationProvider === 'ct2';
    const filteredLanguageOptions = isCT2
        ? languageOptions.filter(lang => lang.data !== "auto")
        : languageOptions;
    const placeholderOption = settings.inputLanguage === '' ? [selectLanguageOption] : [];
    const inputLanguageOptions = settings.ocrProvider === 'rapidocr'
        ? [...placeholderOption, ...filteredLanguageOptions.filter(lang => rapidocrLanguages.has(lang.data))]
        : [...placeholderOption, ...filteredLanguageOptions];
    // Reset input language if it's not supported by the current OCR provider
    SP_REACT.useEffect(() => {
        if (settings.initialized && settings.ocrProvider === 'rapidocr'
            && settings.inputLanguage !== '' && !rapidocrLanguages.has(settings.inputLanguage)) {
            updateSetting('inputLanguage', '', 'Input language');
        }
    }, [settings.initialized, settings.ocrProvider]);
    // When switching to CT2, if source is auto-detect, clear it so user picks a specific language
    SP_REACT.useEffect(() => {
        if (settings.initialized && isCT2 && settings.inputLanguage === 'auto') {
            updateSetting('inputLanguage', '', 'Input language');
        }
    }, [settings.initialized, settings.translationProvider]);
    return (window.SP_REACT.createElement("div", { style: { paddingBottom: "40px" } },
        window.SP_REACT.createElement(DFL.PanelSection, { title: "Languages" },
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.DropdownItem, { layout: "below", label: "Input Language", description: isCT2
                        ? "Source language (auto-detect not available for offline translation)"
                        : settings.ocrProvider === 'rapidocr'
                            ? "Source language for text recognition"
                            : "Source language (Select auto-detect if unsure)", rgOptions: inputLanguageOptions, selectedOption: settings.inputLanguage, onChange: (option) => updateSetting('inputLanguage', option.data, 'Input language') })),
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.DropdownItem, { layout: "below", label: "Output Language", description: "Target language for translation", rgOptions: [...(settings.targetLanguage === '' ? [selectLanguageOption] : []), ...outputLanguageOptions], selectedOption: settings.targetLanguage, onChange: (option) => updateSetting('targetLanguage', option.data, 'Output language') }))),
        window.SP_REACT.createElement(DFL.PanelSection, { title: "Recognition" },
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.Field, { label: "Text Recognition Method", childrenContainerWidth: "max", childrenLayout: "below", focusable: false },
                    window.SP_REACT.createElement(DFL.Focusable, { style: { display: "flex", gap: "8px", alignItems: "center" } },
                        window.SP_REACT.createElement("div", { className: "dt-ocr-dropdown-wrapper", style: { flex: 1 } },
                            window.SP_REACT.createElement("style", null, `.dt-ocr-dropdown-wrapper .dt-recommended-tag { display: none !important; }`),
                            window.SP_REACT.createElement(DFL.Dropdown, { rgOptions: [
                                    { label: window.SP_REACT.createElement("span", { style: { display: "flex", alignItems: "center", height: "20px", lineHeight: "20px" } },
                                            window.SP_REACT.createElement("span", null, "On-Device"),
                                            window.SP_REACT.createElement("span", { style: { fontSize: "10px", opacity: 0.7, marginLeft: "4px", transform: "translateY(2px)" } }, "(RapidOCR)")), data: "rapidocr" },
                                    { label: window.SP_REACT.createElement("span", { style: { display: "flex", alignItems: "center", justifyContent: "space-between", gap: "8px", width: "100%", height: "20px", lineHeight: "20px" } },
                                            window.SP_REACT.createElement("span", { style: { display: "flex", alignItems: "center" } },
                                                window.SP_REACT.createElement("span", null, "On-Device"),
                                                window.SP_REACT.createElement("span", { style: { fontSize: "10px", opacity: 0.7, marginLeft: "4px", transform: "translateY(2px)" } }, "(Chrome)")),
                                            window.SP_REACT.createElement("span", { className: "dt-recommended-tag", style: { fontSize: "10px", color: "#9aa0a6", fontStyle: "italic" } }, "\u2605 recommended")), data: "chromescreenai" },
                                    { label: window.SP_REACT.createElement("span", null, "OCR.space"), data: "ocrspace" },
                                    { label: window.SP_REACT.createElement("span", { style: { display: "flex", alignItems: "center", justifyContent: "space-between", gap: "8px", width: "100%", height: "20px", lineHeight: "20px" } },
                                            window.SP_REACT.createElement("span", null, "Google Cloud"),
                                            window.SP_REACT.createElement("span", { className: "dt-recommended-tag", style: { fontSize: "10px", color: "#9aa0a6", fontStyle: "italic" } }, "\u2605 recommended")), data: "googlecloud" },
                                    { label: window.SP_REACT.createElement("span", { style: { display: "flex", alignItems: "center", gap: "6px", height: "20px", lineHeight: "20px" } },
                                            "Gemini Vision ",
                                            window.SP_REACT.createElement(BsStars, { style: { fontSize: "12px" } })), data: "gemini_vision" }
                                ], selectedOption: settings.ocrProvider, onChange: (option) => {
                                    updateSetting('ocrProvider', option.data, 'OCR provider');
                                    if (option.data === 'rapidocr' && settings.inputLanguage !== '' && !rapidocrLanguages.has(settings.inputLanguage)) {
                                        updateSetting('inputLanguage', '', 'Input language');
                                    }
                                } })),
                        settings.ocrProvider === 'googlecloud' && (window.SP_REACT.createElement(DFL.DialogButton, { onClick: () => {
                                DFL.showModal(window.SP_REACT.createElement(ApiKeyModal, { currentKey: settings.googleApiKey, onSave: (key) => updateSetting('googleApiKey', key, 'Google API Key'), title: "Google Cloud API Key", description: "Enter your Google Cloud API key for Vision and Translation services." }));
                            }, style: { minWidth: "40px", width: "40px", padding: "10px 0" } },
                            window.SP_REACT.createElement("div", { style: { position: "relative", display: "inline-flex" } },
                                window.SP_REACT.createElement(HiKey, null),
                                window.SP_REACT.createElement("div", { style: {
                                        position: "absolute",
                                        bottom: "-8px",
                                        right: "-6px",
                                        width: "6px",
                                        height: "6px",
                                        borderRadius: "50%",
                                        backgroundColor: settings.googleApiKey ? "#4caf50" : "#ff6b6b"
                                    } })))),
                        settings.ocrProvider === 'gemini_vision' && (window.SP_REACT.createElement(DFL.DialogButton, { onClick: () => {
                                DFL.showModal(window.SP_REACT.createElement(ApiKeyModal, { currentKey: settings.geminiApiKey, onSave: (key) => updateSetting('geminiApiKey', key, 'Gemini API Key'), title: "Gemini API Key", description: "Enter your free Gemini API key from aistudio.google.com." }));
                            }, style: { minWidth: "40px", width: "40px", padding: "10px 0" } },
                            window.SP_REACT.createElement("div", { style: { position: "relative", display: "inline-flex" } },
                                window.SP_REACT.createElement(HiKey, null),
                                window.SP_REACT.createElement("div", { style: {
                                        position: "absolute",
                                        bottom: "-8px",
                                        right: "-6px",
                                        width: "6px",
                                        height: "6px",
                                        borderRadius: "50%",
                                        backgroundColor: settings.geminiApiKey ? "#4caf50" : "#ff6b6b"
                                    } })))),
                        settings.ocrProvider === 'chromescreenai' && (window.SP_REACT.createElement(ModelActionButton, { state: csai, actionRef: chromescreenaiActionRef })),
                        settings.ocrProvider === 'rapidocr' && (window.SP_REACT.createElement(ModelActionButton, { state: rapidocr, actionRef: rapidocrActionRef }))))),
            settings.ocrProvider === 'gemini_vision' && (window.SP_REACT.createElement(GeminiModelSelector, { selectedModel: settings.geminiModel, hasApiKey: !!settings.geminiApiKey, onChange: (model) => updateSetting('geminiModel', model, 'Gemini model') })),
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.Field, { focusable: true, childrenContainerWidth: "max", childrenLayout: "below" },
                    window.SP_REACT.createElement("div", { style: { color: "#8b929a", fontSize: "12px", lineHeight: "1.6", paddingLeft: "4px", paddingTop: "4px" } },
                        settings.ocrProvider === 'rapidocr' && (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                            window.SP_REACT.createElement("div", { style: { display: "inline-flex", flexDirection: "column" } },
                                window.SP_REACT.createElement("div", { style: { display: "flex", alignItems: "center", gap: "8px" } },
                                    window.SP_REACT.createElement("img", { src: steamdeckLogo, alt: "", style: { height: "18px" } }),
                                    window.SP_REACT.createElement("span", { style: { fontWeight: "bold", color: "#dcdedf" } }, "On-Device (RapidOCR)")),
                                window.SP_REACT.createElement(ModelHeadingProgressBar, { state: rapidocr })),
                            window.SP_REACT.createElement(ModelStatusIndicator, { state: rapidocr }),
                            window.SP_REACT.createElement(ModelDownloadError, { state: rapidocr }),
                            window.SP_REACT.createElement(ProviderRating, { quality: 1, speed: 1 }),
                            window.SP_REACT.createElement("div", null, "- Offline and privacy-friendly text recognition"),
                            window.SP_REACT.createElement("div", null, "- Requires 75MB one-time model download"),
                            window.SP_REACT.createElement("div", null, "- Customizable parameters"))),
                        settings.ocrProvider === 'chromescreenai' && (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                            window.SP_REACT.createElement("div", { style: { display: "inline-flex", flexDirection: "column" } },
                                window.SP_REACT.createElement("div", { style: { display: "flex", alignItems: "center", gap: "8px" } },
                                    window.SP_REACT.createElement("img", { src: chromeLogo, alt: "", style: { height: "18px" } }),
                                    window.SP_REACT.createElement("span", { style: { fontWeight: "bold", color: "#dcdedf" } }, "On-Device (Chrome Screen AI)")),
                                window.SP_REACT.createElement(ModelHeadingProgressBar, { state: csai })),
                            window.SP_REACT.createElement(ModelStatusIndicator, { state: csai }),
                            window.SP_REACT.createElement(ModelDownloadError, { state: csai }),
                            window.SP_REACT.createElement(ProviderRating, { quality: 3, speed: 2 }),
                            window.SP_REACT.createElement("div", null, "- Offline and privacy-friendly text recognition"),
                            window.SP_REACT.createElement("div", null, "- Requires 120MB one-time engine download"),
                            window.SP_REACT.createElement("div", null, "- Auto-detects 70+ languages"),
                            window.SP_REACT.createElement("div", { style: { marginTop: "6px", fontStyle: "italic", color: "#5f6268", fontSize: "10px" } }, "Downloaded on demand from Google's public server"),
                            window.SP_REACT.createElement("div", { style: { fontStyle: "italic", color: "#5f6268", fontSize: "10px" } }, "This plugin is not affiliated with or endorsed by Google"))),
                        settings.ocrProvider === 'ocrspace' && (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                            window.SP_REACT.createElement("div", { style: { display: "flex", alignItems: "center", gap: "8px", marginBottom: "8px" } },
                                window.SP_REACT.createElement("img", { src: ocrspaceLogo, alt: "", style: { height: "18px" } }),
                                window.SP_REACT.createElement("span", { style: { fontWeight: "bold", color: "#dcdedf" } }, "OCR.space")),
                            window.SP_REACT.createElement(ProviderRating, { quality: 2, speed: 3 }),
                            window.SP_REACT.createElement("div", null, "- Free EU-based cloud OCR API"),
                            window.SP_REACT.createElement("div", null, "- Max usage limits: 500/day and 10/10min"))),
                        settings.ocrProvider === 'googlecloud' && (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                            window.SP_REACT.createElement("div", { style: { display: "flex", alignItems: "center", gap: "8px", marginBottom: "8px" } },
                                window.SP_REACT.createElement("img", { src: googlecloudLogo, alt: "", style: { height: "18px" } }),
                                window.SP_REACT.createElement("span", { style: { fontWeight: "bold", color: "#dcdedf" } }, "Google Cloud Vision")),
                            window.SP_REACT.createElement(ProviderRating, { quality: 3, speed: 3 }),
                            window.SP_REACT.createElement("div", null, "- Best accuracy and speed available"),
                            window.SP_REACT.createElement("div", null, "- Ideal for complex/stylized text"),
                            window.SP_REACT.createElement("div", null, "- Requires API key"),
                            !settings.googleApiKey && (window.SP_REACT.createElement("div", { style: { color: "#ff6b6b", marginTop: "4px" } }, "You need to add your API Key")))),
                        settings.ocrProvider === 'gemini_vision' && (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                            window.SP_REACT.createElement("div", { style: { display: "flex", alignItems: "center", gap: "8px", marginBottom: "8px" } },
                                window.SP_REACT.createElement("img", { src: geminiLogo, alt: "", style: { height: "18px" } }),
                                window.SP_REACT.createElement("span", { style: { fontWeight: "bold", color: "#dcdedf" } }, "Gemini Vision")),
                            window.SP_REACT.createElement(ProviderRating, { quality: 3, speed: 1 }),
                            window.SP_REACT.createElement("div", null, "- AI-based Recognition and Translation"),
                            window.SP_REACT.createElement("div", null, "- Great accuracy, context-aware translations"),
                            window.SP_REACT.createElement("div", null, "- Free API key available at aistudio.google.com"),
                            !settings.geminiApiKey && (window.SP_REACT.createElement("div", { style: { color: "#ff6b6b", marginTop: "4px" } }, "You need to add your Gemini API Key"))))))),
            settings.ocrProvider === 'rapidocr' && (window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.ToggleField, { label: "Faster Recognition", description: "Keeps the recognition engine loaded in memory between translations", checked: settings.rapidocrPersistentMode, onChange: (value) => {
                        updateSetting('rapidocrPersistentMode', value, 'Faster recognition');
                    } }))),
            settings.ocrProvider === 'chromescreenai' && (window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.ToggleField, { label: "Faster Recognition", description: "Keeps the recognition engine loaded in memory between translations", checked: settings.chromeScreenAiPersistentMode, onChange: (value) => {
                        updateSetting('chromeScreenAiPersistentMode', value, 'Faster recognition');
                    } }))),
            settings.ocrProvider !== 'ocrspace' && settings.ocrProvider !== 'gemini_vision' && settings.ocrProvider !== 'chromescreenai' && (window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.ToggleField, { label: "Customize Recognition", description: "Fine-tune text recognition parameters. Can make things better or worse", checked: settings.customRecognitionSettings, onChange: (value) => {
                        updateSetting('customRecognitionSettings', value, 'Custom recognition settings');
                        if (!value) {
                            updateSetting('rapidocrConfidence', 0.5, 'RapidOCR confidence');
                            updateSetting('rapidocrBoxThresh', 0.5, 'RapidOCR box threshold');
                            updateSetting('rapidocrUnclipRatio', 1.6, 'RapidOCR unclip ratio');
                            updateSetting('confidenceThreshold', 0.6, 'Text recognition confidence');
                        }
                    } }))),
            settings.customRecognitionSettings && settings.ocrProvider === 'rapidocr' && (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                    window.SP_REACT.createElement(DFL.SliderField, { value: settings.rapidocrConfidence ?? 0.5, max: 1.0, min: 0.0, step: 0.05, label: "Recognition Confidence", description: "Higher = less noise but may miss text. Lower = more text but more errors", showValue: true, onChange: (value) => {
                            updateSetting('rapidocrConfidence', value, 'RapidOCR confidence');
                        } })),
                window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                    window.SP_REACT.createElement(DFL.SliderField, { value: settings.rapidocrBoxThresh ?? 0.5, max: 1.0, min: 0.1, step: 0.05, label: "Detection Sensitivity", description: "Lower = finds more text regions, better for small text. Higher = fewer regions, but more confident detections", showValue: true, onChange: (value) => {
                            updateSetting('rapidocrBoxThresh', value, 'RapidOCR box threshold');
                        } })),
                window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                    window.SP_REACT.createElement(DFL.SliderField, { value: settings.rapidocrUnclipRatio ?? 1.6, max: 3.0, min: 1.0, step: 0.1, label: "Box Expansion", description: "Higher = larger text boxes, helps capture full words. Lower = tighter boxes around text", showValue: true, onChange: (value) => {
                            updateSetting('rapidocrUnclipRatio', value, 'RapidOCR unclip ratio');
                        } })))),
            settings.customRecognitionSettings && settings.ocrProvider === 'googlecloud' && (window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.SliderField, { value: settings.confidenceThreshold, max: 1.0, min: 0.0, step: 0.05, label: "Text Recognition Confidence", description: "Minimum confidence level for detected text (higher = fewer false positives)", showValue: true, valueSuffix: "", onChange: (value) => {
                        updateSetting('confidenceThreshold', value, 'Text recognition confidence');
                    } })))),
        window.SP_REACT.createElement(DFL.PanelSection, { title: "Translation" },
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.Field, { label: "Text Translation Method", childrenContainerWidth: "max", childrenLayout: "below", focusable: false }, settings.ocrProvider === 'gemini_vision' ? (window.SP_REACT.createElement(DFL.Dropdown, { rgOptions: [
                        { label: window.SP_REACT.createElement("span", { style: { display: "flex", alignItems: "center", gap: "6px", height: "20px", lineHeight: "20px" } },
                                window.SP_REACT.createElement(HiLockClosed, { style: { fontSize: "12px", color: "#888" } }),
                                " Gemini Vision ",
                                window.SP_REACT.createElement(BsStars, { style: { fontSize: "12px" } })), data: "gemini_vision" }
                    ], selectedOption: "gemini_vision", disabled: true, onChange: () => { } })) : (window.SP_REACT.createElement(DFL.Focusable, { style: { display: "flex", gap: "8px", alignItems: "center" } },
                    window.SP_REACT.createElement("div", { style: { flex: 1 } },
                        window.SP_REACT.createElement(DFL.Dropdown, { rgOptions: [
                                { label: window.SP_REACT.createElement("span", null, "On-Device"), data: "ct2" },
                                { label: window.SP_REACT.createElement("span", null, "Google Translate"), data: "freegoogle" },
                                { label: window.SP_REACT.createElement("span", null, "Google Cloud"), data: "googlecloud" }
                            ], selectedOption: settings.translationProvider, onChange: (option) => updateSetting('translationProvider', option.data, 'Translation provider') })),
                    settings.translationProvider === 'googlecloud' && (window.SP_REACT.createElement(DFL.DialogButton, { onClick: () => {
                            DFL.showModal(window.SP_REACT.createElement(ApiKeyModal, { currentKey: settings.googleApiKey, onSave: (key) => updateSetting('googleApiKey', key, 'Google API Key'), title: "Google Cloud API Key", description: "Enter your Google Cloud API key for Translation services." }));
                        }, style: { minWidth: "40px", width: "40px", padding: "10px 0" } },
                        window.SP_REACT.createElement("div", { style: { position: "relative", display: "inline-flex" } },
                            window.SP_REACT.createElement(HiKey, null),
                            window.SP_REACT.createElement("div", { style: {
                                    position: "absolute",
                                    bottom: "-8px",
                                    right: "-6px",
                                    width: "6px",
                                    height: "6px",
                                    borderRadius: "50%",
                                    backgroundColor: settings.googleApiKey ? "#4caf50" : "#ff6b6b"
                                } })))),
                    settings.translationProvider === 'ct2' && (window.SP_REACT.createElement(ModelActionButton, { state: nllb, actionRef: ct2ActionRef })))))),
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.Field, { focusable: true, childrenContainerWidth: "max", childrenLayout: "below" },
                    window.SP_REACT.createElement("div", { style: { color: "#8b929a", fontSize: "12px", lineHeight: "1.6", paddingLeft: "4px", paddingTop: "4px" } },
                        settings.ocrProvider === 'gemini_vision' && (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                            window.SP_REACT.createElement("div", { style: { display: "flex", alignItems: "center", gap: "8px", marginBottom: "8px" } },
                                window.SP_REACT.createElement("img", { src: geminiLogo, alt: "", style: { height: "18px" } }),
                                window.SP_REACT.createElement("span", { style: { fontWeight: "bold", color: "#dcdedf" } }, "Gemini Vision")),
                            window.SP_REACT.createElement(ProviderRating, { quality: 3, speed: 1 }),
                            window.SP_REACT.createElement("div", null, "- Translation is handled by Gemini Vision"),
                            window.SP_REACT.createElement("div", null, "- OCR and translation happen in a single step"))),
                        settings.ocrProvider !== 'gemini_vision' && settings.translationProvider === 'freegoogle' && (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                            window.SP_REACT.createElement("div", { style: { display: "flex", alignItems: "center", gap: "8px", marginBottom: "8px" } },
                                window.SP_REACT.createElement("img", { src: googletranslateLogo, alt: "", style: { height: "18px" } }),
                                window.SP_REACT.createElement("span", { style: { fontWeight: "bold", color: "#dcdedf" } }, "Google Translate")),
                            window.SP_REACT.createElement(ProviderRating, { quality: 2, speed: 3 }),
                            window.SP_REACT.createElement("div", null, "- Free, no API key needed"),
                            window.SP_REACT.createElement("div", null, "- Good quality for most languages"))),
                        settings.ocrProvider !== 'gemini_vision' && settings.translationProvider === 'googlecloud' && (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                            window.SP_REACT.createElement("div", { style: { display: "flex", alignItems: "center", gap: "8px", marginBottom: "8px" } },
                                window.SP_REACT.createElement("img", { src: googlecloudLogo, alt: "", style: { height: "18px" } }),
                                window.SP_REACT.createElement("span", { style: { fontWeight: "bold", color: "#dcdedf" } }, "Google Cloud Translation")),
                            window.SP_REACT.createElement(ProviderRating, { quality: 3, speed: 3 }),
                            window.SP_REACT.createElement("div", null, "- High quality translations"),
                            window.SP_REACT.createElement("div", null, "- Requires API key"),
                            !settings.googleApiKey && (window.SP_REACT.createElement("div", { style: { color: "#ff6b6b", marginTop: "4px" } }, "You need to add your API Key")))),
                        settings.ocrProvider !== 'gemini_vision' && settings.translationProvider === 'ct2' && (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                            window.SP_REACT.createElement("div", { style: { display: "inline-flex", flexDirection: "column" } },
                                window.SP_REACT.createElement("div", { style: { display: "flex", alignItems: "center", gap: "8px" } },
                                    window.SP_REACT.createElement("img", { src: steamdeckLogo, alt: "", style: { height: "18px" } }),
                                    window.SP_REACT.createElement("span", { style: { fontWeight: "bold", color: "#dcdedf" } }, "On-Device (NLLB-200 1.3B)")),
                                window.SP_REACT.createElement(ModelHeadingProgressBar, { state: nllb })),
                            window.SP_REACT.createElement(ModelStatusIndicator, { state: nllb }),
                            window.SP_REACT.createElement(ModelDownloadError, { state: nllb }),
                            window.SP_REACT.createElement(ProviderRating, { quality: 1, speed: 1 }),
                            window.SP_REACT.createElement("div", null, "- Offline and privacy-friendly translation"),
                            window.SP_REACT.createElement("div", null, "- Requires 1.4GB one-time model download"),
                            window.SP_REACT.createElement("div", null, "- Single model covers most languages"),
                            window.SP_REACT.createElement("div", null, "- Language auto-detect not supported"),
                            window.SP_REACT.createElement("div", null, "- Experimental support"),
                            (settings.inputLanguage === 'auto' || settings.inputLanguage === '') && (window.SP_REACT.createElement("div", { style: { color: "#ffa726", marginTop: "6px" } }, "Offline translation needs a specific source language. Select one in the Languages section above."))))))),
            settings.translationProvider === 'ct2' && (window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.ToggleField, { label: "Faster Translation", description: "Keeps the translation model loaded in memory between translations", checked: settings.ct2PersistentMode, onChange: (value) => {
                        updateSetting('ct2PersistentMode', value, 'Faster translation');
                    } }))),
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.ToggleField, { label: "Cache Translations", description: window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                        "Save translated sentences to avoid translating them again and making the process faster.",
                        window.SP_REACT.createElement("div", { style: { display: "flex", alignItems: "center", gap: "5px", marginTop: "5px", fontSize: "11px", opacity: 0.6 } },
                            window.SP_REACT.createElement(HiInformationCircle, { style: { fontSize: "13px", flexShrink: 0 } }),
                            window.SP_REACT.createElement("span", null, "A lower-quality engine can reuse results from a higher-quality one, but not the other way around"))), checked: settings.translationCacheEnabled, onChange: (value) => {
                        updateSetting('translationCacheEnabled', value, 'Translation cache');
                        if (value)
                            refreshCacheStats();
                    } })),
            settings.translationCacheEnabled && (window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.ButtonItem, { layout: "below", onClick: () => DFL.showModal(window.SP_REACT.createElement(CacheEntriesModal, { onCleared: refreshCacheStats })) }, "View Cached Translations"))),
            settings.translationCacheEnabled && cacheEntries !== null && (window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement("div", { style: { width: "100%", textAlign: "center", fontSize: "12px", color: "#8b929a" } },
                    cacheEntries,
                    " cached items"))))));
};

// src/tabs/TabControls.tsx - Input controls, behavior settings, and debug

// Input mode options for dropdown
const inputModeOptions = [
    { label: "L3 (Left Stick Click)", data: InputMode.L3_BUTTON },
    { label: "L4", data: InputMode.L4_BUTTON },
    { label: "L5", data: InputMode.L5_BUTTON },
    { label: "R3 (Right Stick Click)", data: InputMode.R3_BUTTON },
    { label: "R4", data: InputMode.R4_BUTTON },
    { label: "R5", data: InputMode.R5_BUTTON },
    { label: "L3 + R3 (Both Sticks Click)", data: InputMode.L3_R3_COMBO },
    { label: "L4 + R4", data: InputMode.L4_R4_COMBO },
    { label: "L5 + R5", data: InputMode.L5_R5_COMBO },
    { label: "Both Touchpads Touch", data: InputMode.TOUCHPAD_COMBO }
];
const translatedTextAlignmentOptions = [
    { label: "Left", data: 'left' },
    { label: "Right", data: 'right' },
    { label: "Center", data: 'center' },
    { label: "Stretch", data: 'justify' }
];
const fontStyleLabels = {
    normal: 'Normal',
    bold: 'Bold',
    italic: 'Italic',
    bolditalic: 'Bold Italic'
};
// Helper to get button labels for current input mode
const getInputModeButtons = (mode) => {
    switch (mode) {
        case 'L3_BUTTON': return 'L3';
        case 'L4_BUTTON': return 'L4';
        case 'L5_BUTTON': return 'L5';
        case 'R3_BUTTON': return 'R3';
        case 'R4_BUTTON': return 'R4';
        case 'R5_BUTTON': return 'R5';
        case 'L3_R3_COMBO': return 'L3 + R3';
        case 'L4_R4_COMBO': return 'L4 + R4';
        case 'L5_R5_COMBO': return 'L5 + R5';
        case 'TOUCHPAD_COMBO': return 'Left Pad + Right Pad';
        default: return mode;
    }
};
const TabControls = ({ inputDiagnostics }) => {
    const { settings, updateSetting } = useSettings();
    const { fontOptions, fontDescription, preloadWebFonts, unavailableDyslexiaFonts } = useFontOptions(settings.translatedTextFontFamily, settings.targetLanguage, () => updateSetting('translatedTextFontFamily', '', 'Text font'));
    const [fontDropdownKey, setFontDropdownKey] = SP_REACT.useState(0);
    return (window.SP_REACT.createElement("div", null,
        window.SP_REACT.createElement(DFL.PanelSection, { title: "Control" },
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.DropdownItem, { layout: "below", label: "Quick Translation Shortcut", description: "Select which buttons to hold to start translaton", rgOptions: inputModeOptions, selectedOption: settings.inputMode, onChange: (option) => updateSetting('inputMode', option.data, 'Input method') })),
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.SliderField, { value: settings.holdTimeTranslate / 1000, max: 3, min: 0, step: 0.1, label: "Hold Time to Start", description: "Seconds to hold button(s) to translate", showValue: true, valueSuffix: "s", onChange: (value) => {
                        const milliseconds = Math.round(value * 1000);
                        updateSetting('holdTimeTranslate', milliseconds, 'Hold time');
                    } })),
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.SliderField, { value: settings.holdTimeDismiss / 1000, max: 3, min: 0, step: 0.1, label: "Hold Time to Dismiss", description: "Seconds to hold button(s) to dismiss overlay", showValue: true, valueSuffix: "s", onChange: (value) => {
                        const milliseconds = Math.round(value * 1000);
                        updateSetting('holdTimeDismiss', milliseconds, 'Hold time for dismissal');
                    } })),
            (settings.inputMode === InputMode.L4_R4_COMBO ||
                settings.inputMode === InputMode.L5_R5_COMBO ||
                settings.inputMode === InputMode.L3_R3_COMBO ||
                settings.inputMode === InputMode.TOUCHPAD_COMBO) && (window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.ToggleField, { checked: settings.quickToggleEnabled, label: "Quick toggle with Right Button", description: "If double buttons combination is selected, press right button to toggle overlay visibility", onChange: (value) => {
                        updateSetting('quickToggleEnabled', value, 'Quick toggle');
                    } })))),
        window.SP_REACT.createElement(DFL.PanelSection, { title: "Display" },
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.SliderField, { value: settings.fontScale, max: 3, min: 1, step: 0.1, label: "Font Scaling", description: "Increase if translated text is too small. Can be useful for large external monitors", showValue: true, valueSuffix: "x", onChange: (value) => {
                        const rounded = Math.round(value * 10) / 10;
                        updateSetting('fontScale', rounded, 'Font scale');
                    } })),
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.SliderField, { value: settings.groupingPower, min: 0.25, max: 1.0, step: 0.25, notchCount: 4, notchTicksVisible: true, label: "Text Blocks Grouping", description: settings.groupingPower <= 0.25 ? "Normal - Keeps text blocks separated" :
                        settings.groupingPower <= 0.5 ? "Increased - Merges text blocks" :
                            settings.groupingPower <= 0.75 ? "Large - Merges distant text blocks" :
                                "Huge - Merges very distant text blocks", onChange: (value) => {
                        updateSetting('groupingPower', value, 'Text grouping');
                    } })),
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.DropdownItem, { layout: "below", label: "Translated Text Alignment", description: "Choose alignment for translated text labels", rgOptions: translatedTextAlignmentOptions, selectedOption: settings.translatedTextAlignment, onChange: (option) => updateSetting('translatedTextAlignment', option.data, 'Text alignment') })),
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.DropdownItem, { key: fontDropdownKey, layout: "below", label: "Translated Text Font", description: fontDescription, rgOptions: fontOptions, selectedOption: settings.translatedTextFontFamily, onMenuWillOpen: (showMenu) => {
                        preloadWebFonts();
                        showMenu();
                    }, onChange: (option) => {
                        const fontName = option.data;
                        if (fontName && unavailableDyslexiaFonts.has(fontName)) {
                            setFontDropdownKey(k => k + 1);
                            return;
                        }
                        if (fontName && isRemoteFont(fontName)) {
                            const previousFont = settings.translatedTextFontFamily;
                            updateSetting('translatedTextFontFamily', fontName, 'Text font');
                            loadRemoteFont(fontName).then((ok) => {
                                if (!ok) {
                                    updateSetting('translatedTextFontFamily', previousFont, 'Text font');
                                }
                            });
                        }
                        else {
                            updateSetting('translatedTextFontFamily', fontName, 'Text font');
                        }
                    } })),
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.DropdownItem, { layout: "below", label: "Translated Text Style", description: "Font weight and style for translated text", rgOptions: [
                        { label: window.SP_REACT.createElement("span", null, "Normal"), data: "normal" },
                        { label: window.SP_REACT.createElement("span", { style: { fontWeight: 'bold' } }, "Bold"), data: "bold" },
                        { label: window.SP_REACT.createElement("span", { style: { fontStyle: 'italic' } }, "Italic"), data: "italic" },
                        { label: window.SP_REACT.createElement("span", { style: { fontWeight: 'bold', fontStyle: 'italic' } }, "Bold Italic"), data: "bolditalic" }
                    ], selectedOption: settings.translatedTextFontStyle, renderButtonValue: () => fontStyleLabels[settings.translatedTextFontStyle] || 'Normal', onChange: (option) => updateSetting('translatedTextFontStyle', option.data, 'Text style') })),
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.ToggleField, { checked: settings.hideIdenticalTranslations, label: "Hide Identical Translations", description: "Don't display if translation is the same as original word/sentence", onChange: (value) => {
                        updateSetting('hideIdenticalTranslations', value, 'Hide identical translations');
                    } })),
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.ToggleField, { checked: settings.allowLabelGrowth, label: "Allow Labels to Expand", description: "Let translated labels grow wider if the text doesn't fit the original box", onChange: (value) => {
                        updateSetting('allowLabelGrowth', value, 'Allow label growth');
                    } }))),
        window.SP_REACT.createElement(DFL.PanelSection, { title: "Behavior" },
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.ToggleField, { checked: settings.pauseGameOnOverlay, label: "Pause Game While Translating", description: window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
                        "Pauses the active game and allows you to read the text more thoughtfully. The game is resumed when overlay is dismissed.",
                        window.SP_REACT.createElement("br", null),
                        window.SP_REACT.createElement("br", null),
                        "Doesn't work well with game streaming (moonlight, geforce now, remote play, etc)"), onChange: (value) => {
                        updateSetting('pauseGameOnOverlay', value, 'Pause game while translating');
                    } }))),
        window.SP_REACT.createElement(DFL.PanelSection, { title: "Miscellaneous" },
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.ToggleField, { label: "Debug Mode", description: "Enable verbose console logging and diagnostics panel", checked: settings.debugMode, onChange: (value) => updateSetting('debugMode', value, 'Debug mode') })),
            settings.debugMode && inputDiagnostics && (window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement(DFL.Field, { focusable: true, childrenContainerWidth: "max" },
                    window.SP_REACT.createElement("div", { className: "dt-debug-panel", style: {
                            backgroundColor: 'rgba(0,0,0,0.4)',
                            padding: '12px',
                            borderRadius: '6px',
                            fontSize: '11px',
                            fontFamily: 'monospace',
                            border: '1px solid rgba(255,255,255,0.1)'
                        } },
                        window.SP_REACT.createElement("div", { style: { display: 'grid', gap: '3px' } },
                            window.SP_REACT.createElement("div", null,
                                window.SP_REACT.createElement("span", { style: { color: '#888' } }, "Status:"),
                                ' ',
                                inputDiagnostics.enabled ?
                                    (inputDiagnostics.healthy ? 'Healthy' : 'Unhealthy') :
                                    'Disabled'),
                            window.SP_REACT.createElement("div", null,
                                window.SP_REACT.createElement("span", { style: { color: '#888' } }, "Input mode:"),
                                ' ',
                                getInputModeButtons(inputDiagnostics.inputMode)),
                            window.SP_REACT.createElement("div", null,
                                window.SP_REACT.createElement("span", { style: { color: '#888' } }, "Input active:"),
                                ' ',
                                inputDiagnostics.leftTouchpadTouched ? 'Yes' : 'No'),
                            window.SP_REACT.createElement("div", null,
                                window.SP_REACT.createElement("span", { style: { color: '#888' } }, "Buttons pressed:"),
                                ' ',
                                inputDiagnostics.currentButtons && inputDiagnostics.currentButtons.length > 0
                                    ? inputDiagnostics.currentButtons.join(', ')
                                    : 'None'),
                            window.SP_REACT.createElement("div", null,
                                window.SP_REACT.createElement("span", { style: { color: '#888' } }, "Plugin State:"),
                                ' ',
                                !inputDiagnostics.inCooldown && !inputDiagnostics.waitingForRelease && !inputDiagnostics.overlayVisible ? 'Ready' : '',
                                inputDiagnostics.inCooldown ? 'Cooldown ' : '',
                                inputDiagnostics.waitingForRelease ? 'WaitRelease ' : '',
                                inputDiagnostics.overlayVisible ? 'Overlay ' : ''),
                            window.SP_REACT.createElement("div", null,
                                window.SP_REACT.createElement("span", { style: { color: '#888' } }, "Timings:"),
                                ' ',
                                "Hold:",
                                inputDiagnostics.translateHoldTime,
                                "ms",
                                ' ',
                                "Dismiss:",
                                inputDiagnostics.dismissHoldTime,
                                "ms")),
                        !inputDiagnostics.healthy && inputDiagnostics.enabled && (window.SP_REACT.createElement("div", { style: {
                                color: '#ff6b6b',
                                fontWeight: 'bold',
                                marginTop: '8px',
                                padding: '6px',
                                backgroundColor: 'rgba(255, 107, 107, 0.1)',
                                borderRadius: '4px',
                                fontSize: '11px'
                            } }, "Input system is unhealthy - try toggling the plugin off/on")))))))));
};

// index.tsx - Main plugin entry point
// SVG Icons for tabs
const IconTranslate = () => (window.SP_REACT.createElement("svg", { style: { display: "block" }, width: "20", height: "20", viewBox: "0 0 24 24", fill: "none", xmlns: "http://www.w3.org/2000/svg" },
    window.SP_REACT.createElement("path", { d: "M12.87 15.07l-2.54-2.51.03-.03A17.52 17.52 0 0014.07 6H17V4h-7V2H8v2H1v2h11.17A15.4 15.4 0 018.87 12a15.4 15.4 0 01-2.44-4H4.3a17.38 17.38 0 003.08 5.22l-5.3 5.25 1.42 1.42L9 14.4l3.11 3.11.76-2.44zM18.5 10h-2L12 22h2l1.12-3h4.75L21 22h2l-4.5-12zm-2.62 7l1.62-4.33L19.12 17h-3.24z", fill: "currentColor" })));
const IconLanguage = () => (window.SP_REACT.createElement("svg", { style: { display: "block" }, width: "20", height: "20", viewBox: "0 0 24 24", fill: "none", xmlns: "http://www.w3.org/2000/svg" },
    window.SP_REACT.createElement("path", { d: "M11.99 2C6.47 2 2 6.48 2 12s4.47 10 9.99 10C17.52 22 22 17.52 22 12S17.52 2 11.99 2zm6.93 6h-2.95a15.65 15.65 0 00-1.38-3.56A8.03 8.03 0 0118.92 8zM12 4.04c.83 1.2 1.48 2.53 1.91 3.96h-3.82c.43-1.43 1.08-2.76 1.91-3.96zM4.26 14C4.1 13.36 4 12.69 4 12s.1-1.36.26-2h3.38c-.08.66-.14 1.32-.14 2s.06 1.34.14 2H4.26zm.82 2h2.95c.32 1.25.78 2.45 1.38 3.56A7.987 7.987 0 015.08 16zm2.95-8H5.08a7.987 7.987 0 014.33-3.56A15.65 15.65 0 008.03 8zM12 19.96c-.83-1.2-1.48-2.53-1.91-3.96h3.82c-.43 1.43-1.08 2.76-1.91 3.96zM14.34 14H9.66c-.09-.66-.16-1.32-.16-2s.07-1.35.16-2h4.68c.09.65.16 1.32.16 2s-.07 1.34-.16 2zm.25 5.56c.6-1.11 1.06-2.31 1.38-3.56h2.95a8.03 8.03 0 01-4.33 3.56zM16.36 14c.08-.66.14-1.32.14-2s-.06-1.34-.14-2h3.38c.16.64.26 1.31.26 2s-.1 1.36-.26 2h-3.38z", fill: "currentColor" })));
const IconGear = () => (window.SP_REACT.createElement("svg", { style: { display: "block" }, width: "20", height: "20", viewBox: "0 0 24 24", fill: "none", xmlns: "http://www.w3.org/2000/svg" },
    window.SP_REACT.createElement("path", { d: "M19.14 12.94c.04-.3.06-.61.06-.94 0-.32-.02-.64-.07-.94l2.03-1.58a.49.49 0 00.12-.61l-1.92-3.32a.49.49 0 00-.59-.22l-2.39.96c-.5-.38-1.03-.7-1.62-.94l-.36-2.54a.484.484 0 00-.48-.41h-3.84c-.24 0-.43.17-.47.41l-.36 2.54c-.59.24-1.13.57-1.62.94l-2.39-.96a.49.49 0 00-.59.22L2.74 8.87c-.12.21-.08.47.12.61l2.03 1.58c-.05.3-.07.62-.07.94s.02.64.07.94l-2.03 1.58a.49.49 0 00-.12.61l1.92 3.32c.12.22.37.29.59.22l2.39-.96c.5.38 1.03.7 1.62.94l.36 2.54c.05.24.24.41.48.41h3.84c.24 0 .44-.17.47-.41l.36-2.54c.59-.24 1.13-.56 1.62-.94l2.39.96c.22.08.47 0 .59-.22l1.92-3.32c.12-.22.07-.47-.12-.61l-2.01-1.58zM12 15.6A3.6 3.6 0 1115.6 12 3.611 3.611 0 0112 15.6z", fill: "currentColor" })));
// Main plugin component
const GameTranslator = ({ logic }) => {
    const { settings, initialized } = useSettings();
    const [overlayVisible, setOverlayVisible] = SP_REACT.useState(logic.isOverlayVisible());
    const [inputDiagnostics, setInputDiagnostics] = SP_REACT.useState(null);
    const [providerStatus, setProviderStatus] = SP_REACT.useState(null);
    const [currentTabRoute, setCurrentTabRoute] = SP_REACT.useState("main");
    const [pendingScrollTarget, setPendingScrollTarget] = SP_REACT.useState(null);
    const [webReachability, setWebReachability] = SP_REACT.useState(null);
    const currentTabRouteRef = SP_REACT.useRef(currentTabRoute);
    const settingsRef = SP_REACT.useRef(settings);
    SP_REACT.useEffect(() => { currentTabRouteRef.current = currentTabRoute; }, [currentTabRoute]);
    SP_REACT.useEffect(() => { settingsRef.current = settings; }, [settings]);
    const handleNavigateToTab = (tabId, scrollTargetId) => {
        setCurrentTabRoute(tabId);
        setPendingScrollTarget(scrollTargetId ?? null);
    };
    SP_REACT.useEffect(() => {
        // Don't poll overlay state if plugin is disabled
        if (!settings.enabled) {
            setOverlayVisible(false);
            return;
        }
        const checkOverlayState = () => {
            setOverlayVisible(logic.isOverlayVisible());
        };
        checkOverlayState();
        const intervalId = setInterval(checkOverlayState, 500);
        return () => {
            clearInterval(intervalId);
        };
    }, [logic, settings.enabled]);
    const probeReachability = SP_REACT.useCallback(async () => {
        const s = settingsRef.current;
        if (currentTabRouteRef.current !== 'main' || !s?.enabled)
            return;
        const webOcr = new Set(['gemini_vision', 'googlecloud', 'ocrspace']);
        const webTrans = new Set(['freegoogle', 'googlecloud']);
        const probeOcr = webOcr.has(s.ocrProvider);
        const probeTrans = s.ocrProvider !== 'gemini_vision' && webTrans.has(s.translationProvider);
        if (!probeOcr && !probeTrans)
            return;
        try {
            const reach = await call('check_web_reachability');
            if (reach && !reach.error) {
                setWebReachability({ ocr: reach.ocr ?? null, translation: reach.translation ?? null });
            }
        }
        catch (error) {
            logger.error('GameTranslator', 'Failed to probe web reachability', error);
        }
    }, []);
    const fetchProviderStatus = SP_REACT.useCallback(async () => {
        try {
            const result = await call('get_provider_status');
            if (result) {
                setProviderStatus(result);
            }
        }
        catch (error) {
            logger.error('GameTranslator', 'Failed to fetch provider status', error);
        }
        await probeReachability();
    }, [probeReachability]);
    SP_REACT.useEffect(() => {
        fetchProviderStatus();
        const intervalId = setInterval(fetchProviderStatus, 10000);
        return () => {
            clearInterval(intervalId);
        };
    }, [fetchProviderStatus]);
    SP_REACT.useEffect(() => {
        if (currentTabRoute === 'main')
            fetchProviderStatus();
    }, [currentTabRoute, fetchProviderStatus]);
    SP_REACT.useEffect(() => {
        setWebReachability(null);
    }, [settings.ocrProvider, settings.translationProvider]);
    // Refresh diagnostics while debug mode is on
    SP_REACT.useEffect(() => {
        if (!settings.debugMode)
            return;
        const refreshDiagnostics = () => {
            const diagnostics = logic.getInputDiagnostics();
            if (diagnostics) {
                setInputDiagnostics(diagnostics);
            }
        };
        // Initial fetch
        refreshDiagnostics();
        // Refresh at 10Hz (100ms) for responsive button feedback
        const intervalId = setInterval(refreshDiagnostics, 100);
        return () => {
            clearInterval(intervalId);
        };
    }, [settings.debugMode, logic]);
    // Show loading state if not initialized
    if (!initialized) {
        return (window.SP_REACT.createElement(DFL.PanelSection, null,
            window.SP_REACT.createElement(DFL.PanelSectionRow, null,
                window.SP_REACT.createElement("div", null, "Loading..."))));
    }
    return (window.SP_REACT.createElement(window.SP_REACT.Fragment, null,
        window.SP_REACT.createElement("style", null, `
                .decky-translator-tabs > div > div:first-child::before {
                    background: #0D141C;
                    box-shadow: none;
                    backdrop-filter: none;
                }
                .decky-translator-tabs [role="tabpanel"] {
                    padding-left: 0 !important;
                    padding-right: 0 !important;
                }
                `),
        window.SP_REACT.createElement("div", { className: "decky-translator-tabs", style: { height: "95%", width: "300px", position: "fixed", marginTop: "-12px", overflow: "hidden" } },
            window.SP_REACT.createElement(DFL.Tabs, { activeTab: currentTabRoute, 
                // @ts-ignore
                onShowTab: (tabID) => {
                    setCurrentTabRoute(tabID);
                }, tabs: [
                    {
                        // @ts-ignore
                        title: window.SP_REACT.createElement(IconTranslate, null),
                        content: window.SP_REACT.createElement(TabMain, { logic: logic, overlayVisible: overlayVisible, providerStatus: providerStatus, webReachability: webReachability, onNavigateToTab: handleNavigateToTab }),
                        id: "main",
                    },
                    {
                        // @ts-ignore
                        title: window.SP_REACT.createElement(IconLanguage, null),
                        content: window.SP_REACT.createElement(TabTranslation, { scrollTarget: pendingScrollTarget, onScrolled: () => setPendingScrollTarget(null) }),
                        id: "translation",
                    },
                    {
                        // @ts-ignore
                        title: window.SP_REACT.createElement(IconGear, null),
                        content: window.SP_REACT.createElement(TabControls, { inputDiagnostics: inputDiagnostics }),
                        id: "controls",
                    }
                ] }))));
};
// Activation Indicator component
const HoldActivationIndicator = ({ logic }) => {
    const { settings } = useSettings();
    const [progressInfo, setProgressInfo] = SP_REACT.useState({
        active: false,
        progress: 0,
        forDismiss: false
    });
    SP_REACT.useEffect(() => {
        logger.debug('HoldActivationIndicator', 'useEffect mounting, registering progress listener');
        let hideTimeout = null;
        const handleProgress = (info) => {
            // Clear any pending hide timeout
            if (hideTimeout) {
                clearTimeout(hideTimeout);
                hideTimeout = null;
            }
            // Delay hiding when progress reaches 100% to allow overlay to take over UI composition
            // This prevents Steam UI from flashing between progress bar and overlay
            if (info.active && info.progress >= 1.0) {
                // Keep showing at 100% briefly, then hide after overlay has initialized
                setProgressInfo({
                    active: true,
                    progress: 1.0,
                    forDismiss: info.forDismiss
                });
                hideTimeout = setTimeout(() => {
                    setProgressInfo({
                        active: false,
                        progress: 0,
                        forDismiss: info.forDismiss
                    });
                }, 600); // 600ms delay - covers screenshot capture time
            }
            else {
                setProgressInfo(info);
            }
        };
        logic.onProgress(handleProgress);
        return () => {
            logic.offProgress(handleProgress);
            if (hideTimeout) {
                clearTimeout(hideTimeout);
            }
        };
    }, [logic]);
    // Generate appropriate text based on action and progress
    const getActivationText = () => {
        if (!progressInfo.active)
            return "";
        const action = progressInfo.forDismiss ? "Dismiss" : "Translate";
        const timeRequired = `${(progressInfo.forDismiss ? settings.holdTimeDismiss : settings.holdTimeTranslate) / 1000}s`;
        return `Hold to ${action} (${timeRequired})`;
    };
    // Only show the indicator if the plugin is enabled
    if (!settings.enabled) {
        return null;
    }
    return (window.SP_REACT.createElement(ActivationIndicator, { visible: progressInfo.active, progress: progressInfo.progress, text: getActivationText(), forDismiss: progressInfo.forDismiss }));
};
// Main App wrapped with Settings provider
const TranslatorApp = ({ logic }) => {
    return (window.SP_REACT.createElement(SettingsProvider, { logic: logic },
        window.SP_REACT.createElement(GameTranslator, { logic: logic })));
};
// Indicator wrapped with Settings provider
const ActivationIndicatorWithSettings = ({ logic }) => {
    return (window.SP_REACT.createElement(SettingsProvider, { logic: logic },
        window.SP_REACT.createElement(HoldActivationIndicator, { logic: logic })));
};
// Export the plugin
var index = definePlugin(() => {
    const removeChineseUi = installChineseUi();
    // Create image state to manage the overlay
    const imageState = new ImageState();
    // Create logic instance
    const logic = new GameTranslatorLogic(imageState);
    // Add image overlay as a global component
    routerHook.addGlobalComponent("ImageOverlay", () => (window.SP_REACT.createElement(ImageOverlay, { state: imageState, onDismiss: logic.dismiss })));
    // Add activation indicator as a global component
    routerHook.addGlobalComponent("HoldActivationIndicator", () => (window.SP_REACT.createElement(ActivationIndicatorWithSettings, { logic: logic })));
    return {
        name: "沉浸式翻译",
        title: window.SP_REACT.createElement("div", { className: DFL.staticClasses.Title }, "\u6C89\u6D78\u5F0F\u7FFB\u8BD1"),
        content: window.SP_REACT.createElement(TranslatorApp, { logic: logic }),
        icon: window.SP_REACT.createElement(BsTranslate, null),
        onDismount() {
            // Clean up resources
            logic.cleanup();
            removeChineseUi();
            cleanupAllFontDOM();
            routerHook.removeGlobalComponent("ImageOverlay");
            routerHook.removeGlobalComponent("HoldActivationIndicator");
        },
        alwaysRender: true
    };
});

export { index as default };
//# sourceMappingURL=index.js.map
