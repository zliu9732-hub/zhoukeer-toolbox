# Frontend source and relinking

`dist/index.js` includes code from `@decky/api` 1.1.3 under LGPL-2.1. Its full
package source is included in `THIRD_PARTY_SOURCES/decky-api-1.1.3/`, and its
license is in `THIRD_PARTY_LICENSES/decky-api-LGPL-2.1.txt`.

The source and build inputs for this plugin's frontend are included in the
release archive as `src/`, `rollup.config.js`, `tsconfig.json`, `package.json`
and `package-lock.json`. With Node.js 18 or newer, rebuild the bundle with:

```bash
npm ci
npm run build
```

This permits replacing or modifying `@decky/api` and relinking the frontend.
The complete project source is also published at
https://github.com/Rayekkk/LeGo2BrightnessFix.
