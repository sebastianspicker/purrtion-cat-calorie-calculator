import { spawn } from 'node:child_process';
import { watch } from 'node:fs';
import { join } from 'node:path';
import { build, copyStatic, root, staticFiles } from './build.mjs';
import { serve } from './serve.mjs';
build();
const compiler = spawn(process.execPath, [join(root, 'node_modules/typescript/bin/tsc'), '--watch', '--preserveWatchOutput'], { cwd: root, stdio: 'inherit' });
const watchers = staticFiles.map(([path]) => path)
  .map(path => watch(join(root, path), () => { try { copyStatic(); } catch (error) { console.error(error); } }));
const server = serve();
console.log('Watching TypeScript and static files. Refresh the browser after editing; no HMR dependency.');
function stop() { compiler.kill(); watchers.forEach(w => w.close()); server.close(() => process.exit(0)); }
process.on('SIGINT', stop); process.on('SIGTERM', stop);
