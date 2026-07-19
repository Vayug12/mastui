/**
 * Start render server + auto-generate in one command.
 *
 *   node start.js                    render server + auto-generate (OpenCode)
 *   node start.js --provider codex   render server + auto-generate (Codex)
 *   node start.js --pack neon-cyber  render server + pack generation
 */
import { spawn } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

function run(script, args = []) {
  const child = spawn('node', [path.join(__dirname, script), ...args], {
    stdio: 'inherit',
    shell: process.platform === 'win32',
  });
  return child;
}

// Collect extra args to pass to auto-generate
const extraArgs = process.argv.slice(2);

console.log('\n  Starting MastUI pipeline...\n');

// Start render server
const render = run('render-server.js');

// Start auto-generate with remaining args
const auto = run('auto-generate.js', extraArgs);

// If either dies, kill the other
render.on('close', () => { auto.kill(); process.exit(); });
auto.on('close', () => { render.kill(); process.exit(); });
