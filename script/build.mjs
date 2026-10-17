import { execFileSync } from 'node:child_process';
import { mkdirSync, copyFileSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
export const root = dirname(dirname(fileURLToPath(import.meta.url)));
/** Static inputs copied verbatim into dist/web; also watched by script/dev.mjs. */
export const staticFiles = [['apps/web/index.html', 'dist/web/index.html'],
  ['apps/web/styles.css', 'dist/web/assets/styles.css'],
  ['apps/web/fonts/m-plus-rounded-1c-latin-500-normal.woff2', 'dist/web/assets/fonts/m-plus-rounded-1c-latin-500-normal.woff2'],
  ['apps/web/fonts/m-plus-rounded-1c-latin-800-normal.woff2', 'dist/web/assets/fonts/m-plus-rounded-1c-latin-800-normal.woff2'],
  ['apps/web/fonts/OFL.txt', 'dist/web/assets/fonts/OFL.txt'],
  ['brand/purrtion-mark.svg', 'dist/web/assets/purrtion-mark.svg'],
  ['brand/purrtion-favicon.svg', 'dist/web/assets/favicon.svg'],
  ['brand/apple-touch-icon.png', 'dist/web/assets/apple-touch-icon.png'],
  ['apps/web/vendor/README.md', 'dist/web/vendor/README.md'],
  ['apps/web/vendor/temml/temml.min.js', 'dist/web/vendor/temml/temml.min.js'],
  ['apps/web/vendor/temml/LICENSE', 'dist/web/vendor/temml/LICENSE'],
  ['shared/default-plan.json', 'dist/web/shared/default-plan.json'],
  ['shared/plan.schema.json', 'dist/web/shared/plan.schema.json']];
export function copyStatic() {
  for (const [source, target] of staticFiles) {
    mkdirSync(dirname(join(root, target)), { recursive: true });
    copyFileSync(join(root, source), join(root, target));
  }
  // GitHub Pages: serve the files as they are, without Jekyll processing.
  writeFileSync(join(root, 'dist/web/.nojekyll'), '');
}
/** Stamps the compiled build-info module with package.json's version and the git commit ("-dirty" for local edits). */
function stampBuildInfo() {
  const { version } = JSON.parse(readFileSync(join(root, 'package.json'), 'utf8'));
  let build = 'unknown';
  try {
    const git = args => execFileSync('git', args, { cwd: root, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim();
    build = git(['rev-parse', '--short=7', 'HEAD']) + (git(['status', '--porcelain', '--untracked-files=no']) ? '-dirty' : '');
  } catch { /* not a git checkout, for example the source ZIP */ }
  const file = join(root, 'dist/web/apps/web/src/build-info.js');
  const unstamped = "{ version: 'dev', build: 'unknown' }", source = readFileSync(file, 'utf8');
  if (!source.includes(unstamped)) throw new Error(`build-info.js no longer contains ${unstamped}`);
  writeFileSync(file, source.replace(unstamped, JSON.stringify({ version, build })));
}
export function build() {
  rmSync(join(root, 'dist/web'), { recursive: true, force: true });
  execFileSync(process.execPath, [join(root, 'node_modules/typescript/bin/tsc')], { cwd: root, stdio: 'inherit' });
  stampBuildInfo(); copyStatic(); console.log('Website built in dist/web (static files; no runtime dependencies).');
}
if (process.argv[1] === fileURLToPath(import.meta.url)) build();
