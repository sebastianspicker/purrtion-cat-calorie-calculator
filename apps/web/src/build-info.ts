/** Which build is running. `script/build.mjs` stamps the compiled module with the package version and git commit;
 * the TypeScript watcher in `npm run dev` re-emits it unstamped, so a dev server shows "dev". */
export const buildInfo: { readonly version: string; readonly build: string } = { version: 'dev', build: 'unknown' };
/** Where testers report problems; the Mac app links to the same page. */
export const reportUrl = 'https://github.com/sebastianspicker/purrtion-cat-calorie-calculator/issues';
