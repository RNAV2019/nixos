// Tracks which desktop theme Helium is wearing, for the content scripts to colour labels by.
// The `helium` launcher (home/themes/helium.nix) swaps in one Chrome theme extension per
// palette, named after its label, so the enabled theme's name is the palette's label.
let timer = 0;

async function sync() {
  const themes = await chrome.management.getAll();
  const theme = themes.find((e) => e.type === "theme" && e.enabled);
  const { theme: stored } = await chrome.storage.local.get("theme");
  const name = theme?.name ?? null;
  if (name !== stored) {
    await chrome.storage.local.set({ theme: name });
  }
}

// A switch is several installs and uninstalls in a row; act once it has settled.
function schedule() {
  clearTimeout(timer);
  timer = setTimeout(sync, 150);
}

chrome.management.onInstalled.addListener(schedule);
chrome.management.onUninstalled.addListener(schedule);
chrome.management.onEnabled.addListener(schedule);
chrome.management.onDisabled.addListener(schedule);
chrome.runtime.onStartup.addListener(schedule);
chrome.runtime.onInstalled.addListener(schedule);
