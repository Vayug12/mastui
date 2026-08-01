/**
 * Service worker: opens the side panel, owns the context menu, and captures
 * the visible tab.
 *
 * Capture lives here rather than in the panel because `chrome.tabs` is not
 * available to extension pages, and because the downscale has to happen before
 * the image crosses to the Worker — it rejects anything over 4 MB.
 */

const CAPTURE_MENU_ID = 'mastui-capture';

/** Matches the Worker's own ceiling; a vision model gains nothing above this. */
const MAX_EDGE = 1600;

chrome.runtime.onInstalled.addListener(() => {
  // Clicking the toolbar icon opens the panel. This also grants `activeTab`
  // for the current tab, which is what makes capture work without asking for
  // broad host permissions.
  chrome.sidePanel
    .setPanelBehavior({ openPanelOnActionClick: true })
    .catch(() => {});

  chrome.contextMenus.create({
    id: CAPTURE_MENU_ID,
    title: 'Capture this page for a MastUI prompt',
    contexts: ['page', 'image'],
  });
});

chrome.contextMenus.onClicked.addListener(async (info, tab) => {
  if (info.menuItemId !== CAPTURE_MENU_ID || !tab) return;
  // A context-menu click is itself an activeTab grant, so this path works even
  // when the panel was opened long ago on a different tab.
  await chrome.sidePanel.open({ tabId: tab.id });
  const shot = await capture().catch((err) => ({ error: err.message }));
  await chrome.storage.session.set({ pendingCapture: shot });
});

chrome.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
  if (msg?.type === 'capture') {
    capture().then(sendResponse, (err) => sendResponse({ error: err.message }));
    return true; // keep the channel open for the async reply
  }

  if (msg?.type === 'insert') {
    insertPrompt(msg.prompt).then(sendResponse, (err) =>
      sendResponse({ error: err.message })
    );
    return true;
  }

  return false;
});

/** Screenshots the active tab and downscales it. Returns a PNG data URL. */
async function capture() {
  const dataUrl = await chrome.tabs.captureVisibleTab({ format: 'png' });
  return { dataUrl: await downscale(dataUrl) };
}

async function downscale(dataUrl) {
  const blob = await (await fetch(dataUrl)).blob();
  const bitmap = await createImageBitmap(blob);

  const scale = Math.min(1, MAX_EDGE / Math.max(bitmap.width, bitmap.height));
  if (scale === 1) {
    bitmap.close();
    return dataUrl;
  }

  const canvas = new OffscreenCanvas(
    Math.round(bitmap.width * scale),
    Math.round(bitmap.height * scale)
  );
  canvas.getContext('2d').drawImage(bitmap, 0, 0, canvas.width, canvas.height);
  bitmap.close();

  const out = await canvas.convertToBlob({ type: 'image/png' });
  return await new Promise((resolve) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result);
    reader.readAsDataURL(out);
  });
}

/**
 * Types a prompt into whatever input the page in front of the user is using.
 * This is the one thing a website cannot do, and the reason the extension
 * exists at all.
 */
async function insertPrompt(prompt) {
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (!tab?.id) throw new Error('No active tab.');

  const [result] = await chrome.scripting.executeScript({
    target: { tabId: tab.id },
    func: injectIntoPage,
    args: [prompt],
  });

  if (!result?.result?.ok) {
    throw new Error(
      result?.result?.reason ?? 'Could not find an input on this page.'
    );
  }
  return { ok: true };
}

/**
 * Runs inside the page. Kept self-contained because `executeScript` serializes
 * the function — it cannot close over anything from this module.
 */
function injectIntoPage(prompt) {
  const isVisible = (el) => {
    const r = el.getBoundingClientRect();
    return r.width > 120 && r.height > 20;
  };

  const candidates = [
    ...document.querySelectorAll('textarea, [contenteditable="true"]'),
  ].filter(isVisible);

  if (!candidates.length) {
    return { ok: false, reason: 'No prompt box found on this page.' };
  }

  // The largest visible box is the composer on every tool we support.
  const target = candidates.sort((a, b) => {
    const ar = a.getBoundingClientRect();
    const br = b.getBoundingClientRect();
    return br.width * br.height - ar.width * ar.height;
  })[0];

  target.focus();

  if (target.tagName === 'TEXTAREA') {
    // React tracks the previous value on the DOM node and ignores plain
    // assignment, so the write has to go through the native setter.
    const setter = Object.getOwnPropertyDescriptor(
      window.HTMLTextAreaElement.prototype,
      'value'
    ).set;
    setter.call(target, prompt);
  } else {
    target.textContent = prompt;
  }

  target.dispatchEvent(new Event('input', { bubbles: true }));
  target.dispatchEvent(new Event('change', { bubbles: true }));
  return { ok: true };
}
