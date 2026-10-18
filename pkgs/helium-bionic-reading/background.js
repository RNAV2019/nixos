// Toggles bionic reading from the toolbar button (Alt+B) and sends every PDF to the bundled
// PDF.js viewer, whose text rendering does the bolding.
const VIEWER = chrome.runtime.getURL("pdfjs/web/viewer.html");

// Redirect PDFs once their headers arrive, by content type, or by a .pdf path served as a
// generic binary. Downloads (Content-Disposition: attachment) are left alone.
async function installRules() {
  const action = {
    type: "redirect",
    redirect: { regexSubstitution: `${VIEWER}?bionic-src=\\0` },
  };
  const base = {
    regexFilter: "^https?://.*",
    resourceTypes: ["main_frame", "sub_frame", "object"],
    requestMethods: ["get"],
    excludedResponseHeaders: [{ header: "content-disposition", values: ["attachment*"] }],
  };
  await chrome.declarativeNetRequest.updateDynamicRules({
    removeRuleIds: [1, 2],
    addRules: [
      {
        id: 1,
        priority: 1,
        action,
        condition: {
          ...base,
          responseHeaders: [{ header: "content-type", values: ["application/pdf*"] }],
        },
      },
      {
        id: 2,
        priority: 1,
        action,
        condition: {
          ...base,
          regexFilter: "^https?://[^?#]*\\.[pP][dD][fF]([?#].*)?$",
          responseHeaders: [
            {
              header: "content-type",
              values: ["application/octet-stream*", "binary/octet-stream*", "application/x-pdf*"],
            },
          ],
        },
      },
    ],
  });
}

async function showState() {
  const { enabled } = await chrome.storage.local.get({ enabled: false });
  const state = enabled ? "on" : "off";
  await chrome.action.setIcon({
    path: { 16: `icons/${state}-16.png`, 32: `icons/${state}-32.png` },
  });
  await chrome.action.setTitle({ title: `Bionic reading: ${state} (Alt+B)` });
}

chrome.action.onClicked.addListener(async () => {
  const { enabled } = await chrome.storage.local.get({ enabled: false });
  await chrome.storage.local.set({ enabled: !enabled });
});

chrome.storage.onChanged.addListener((changes, area) => {
  if (area === "local" && "enabled" in changes) {
    showState();
  }
});

chrome.runtime.onInstalled.addListener(() => {
  installRules();
  showState();
});
chrome.runtime.onStartup.addListener(showState);

// Network rules never see file:// loads. Reading the file needs "Allow access to file URLs"
// on the extension's details page.
chrome.webNavigation.onBeforeNavigate.addListener(
  ({ tabId, frameId, url }) => {
    if (frameId === 0) {
      chrome.tabs.update(tabId, { url: `${VIEWER}?bionic-src=${url}` });
    }
  },
  { url: [{ schemes: ["file"], pathSuffix: ".pdf" }, { schemes: ["file"], pathSuffix: ".PDF" }] },
);
