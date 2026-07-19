import { spawn } from 'node:child_process';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';

import Anthropic from '@anthropic-ai/sdk';

export const PROVIDERS = ['claude', 'claude-code', 'codex', 'opencode'];

const CLAUDE_MODEL = 'claude-opus-4-8';
const EFFORT = process.env.MASTUI_EFFORT ?? 'high'; // low | medium | high | xhigh | max (claude only)
const CLAUDE_CODE_MODEL = process.env.MASTUI_CLAUDE_CODE_MODEL; // optional, e.g. opus | sonnet
const CODEX_MODEL = process.env.MASTUI_CODEX_MODEL; // optional, e.g. gpt-5.1-codex
const OPENCODE_MODEL = process.env.MASTUI_OPENCODE_MODEL; // optional, e.g. anthropic/claude-sonnet-5

const SYSTEM_PROMPT =
  'You are a senior UI designer who writes pixel-precise, self-contained HTML mockups of mobile and web app screens. You output only a complete HTML document — never explanation, never markdown fences.';

export function createClient(provider = 'claude') {
  // Claude talks to the API via the SDK (needs ANTHROPIC_API_KEY). Codex and OpenCode
  // shell out to their CLIs, which carry their own login, so no client is needed.
  if (provider !== 'claude') return null;
  if (!process.env.ANTHROPIC_API_KEY && !process.env.ANTHROPIC_AUTH_TOKEN) {
    throw new Error(
      'ANTHROPIC_API_KEY is not set. Set it ($env:ANTHROPIC_API_KEY = "sk-ant-...") ' +
        'or use --provider claude-code / codex / opencode, which use their own CLI login ' +
        '(claude-code runs on your Claude subscription).',
    );
  }
  return new Anthropic();
}

/** Strip markdown fences if the model wrapped the document despite instructions. */
function unwrap(text) {
  const fenced = text.match(/```(?:html)?\s*\n([\s\S]*?)\n```/i);
  const body = fenced ? fenced[1] : text;
  const start = body.search(/<!doctype html|<html/i);
  return (start > 0 ? body.slice(start) : body).trim();
}

/**
 * A pack's screens must look like one app, but each is a separate model call —
 * so every screen after the first carries the first screen's full HTML as the
 * design system to copy.
 */
function withReference(renderPrompt, referenceHtml) {
  if (!referenceHtml) return renderPrompt;
  return [
    renderPrompt,
    ``,
    `---`,
    `This screen belongs to the SAME APP as the reference screen below. Reuse its design system exactly: the same palette hex values, font stack and type scale, the same button/card/input shapes and corner radii, the same border and shadow treatment, the same spacing rhythm, and the same status-bar and icon styling. Only the screen's content differs — a user flipping between the two screens must believe they come from one product.`,
    ``,
    `Reference screen (HTML):`,
    referenceHtml,
  ].join('\n');
}

/**
 * Render one catalog item's prompt into a self-contained HTML document
 * with whichever provider is selected.
 */
export async function generateHtml(client, item, provider = 'claude', { referenceHtml } = {}) {
  const prompt = withReference(item.renderPrompt, referenceHtml);
  const result =
    provider === 'claude-code'
      ? await runClaudeCode(prompt)
      : provider === 'codex'
        ? await runCodex(prompt)
        : provider === 'opencode'
          ? await runOpencode(prompt)
          : await runClaude(client, prompt);

  const html = unwrap(result.text);
  if (!/<html/i.test(html)) {
    throw new Error(`${provider} did not return an HTML document`);
  }

  return { html, usage: result.usage };
}

/** Streams because max_tokens is high enough to risk an HTTP timeout otherwise. */
async function runClaude(client, prompt) {
  const stream = client.messages.stream({
    model: CLAUDE_MODEL,
    max_tokens: 32000,
    thinking: { type: 'adaptive' },
    output_config: { effort: EFFORT },
    system: [
      {
        type: 'text',
        text: SYSTEM_PROMPT,
        cache_control: { type: 'ephemeral' },
      },
    ],
    messages: [{ role: 'user', content: prompt }],
  });

  const message = await stream.finalMessage();

  if (message.stop_reason === 'max_tokens') {
    throw new Error('output truncated (max_tokens) — raise max_tokens or simplify the screen');
  }

  const text = message.content
    .filter((block) => block.type === 'text')
    .map((block) => block.text)
    .join('');

  return { text, usage: message.usage };
}

/** Claude Code CLI headless mode — runs on the user's Claude subscription, no API key. */
async function runClaudeCode(prompt) {
  const args = ['-p', '--output-format', 'text'];
  if (CLAUDE_CODE_MODEL) args.push('--model', CLAUDE_CODE_MODEL);
  const text = await runCli('claude', args, `${SYSTEM_PROMPT}\n\n${prompt}`);
  return { text, usage: {} };
}

async function runCodex(prompt) {
  // --output-last-message keeps the answer separate from codex's progress logs on stdout.
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), 'mastui-codex-'));
  const outFile = path.join(dir, 'last-message.txt');
  try {
    const args = ['exec', '--skip-git-repo-check', '-s', 'read-only', '--output-last-message', outFile];
    if (CODEX_MODEL) args.push('-m', CODEX_MODEL);
    args.push('-'); // read the prompt from stdin
    await runCli('codex', args, `${SYSTEM_PROMPT}\n\n${prompt}`);
    return { text: await fs.readFile(outFile, 'utf8'), usage: {} };
  } finally {
    await fs.rm(dir, { recursive: true, force: true });
  }
}

async function runOpencode(prompt) {
  const args = ['run', '--pure'];
  if (OPENCODE_MODEL) args.push('-m', OPENCODE_MODEL);
  const text = await runCli('opencode', args, `${SYSTEM_PROMPT}\n\n${prompt}`);
  return { text, usage: {} };
}

/** Spawn a CLI, feed the prompt on stdin (avoids Windows argv quoting limits), return stdout. */
function runCli(command, args, input) {
  return new Promise((resolve, reject) => {
    // npm installs codex/opencode as .cmd shims on Windows, which need a shell to run.
    const useShell = process.platform === 'win32';
    const quoted = useShell ? args.map((a) => (/\s/.test(a) ? `"${a}"` : a)) : args;
    const child = spawn(command, quoted, { shell: useShell });

    let stdout = '';
    let stderr = '';
    child.stdout.on('data', (chunk) => (stdout += chunk));
    child.stderr.on('data', (chunk) => (stderr += chunk));
    child.on('error', (err) => reject(new Error(`could not start ${command}: ${err.message}`)));
    child.on('close', (code) => {
      if (code !== 0) {
        reject(new Error(`${command} exited with ${code}: ${stderr.trim().slice(-400)}`));
      } else {
        resolve(stdout);
      }
    });

    child.stdin.on('error', () => {}); // CLI may exit before reading all of stdin
    child.stdin.write(input);
    child.stdin.end();
  });
}
