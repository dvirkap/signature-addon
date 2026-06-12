chrome.runtime.onInstalled.addListener(() => {
  // Create context menu for links
  chrome.contextMenus.create({
    id: "sign-pdf-link",
    title: "חתום על PDF (מקישור)",
    contexts: ["link"]
  });

  // Create context menu for the current page
  chrome.contextMenus.create({
    id: "sign-pdf-page",
    title: "חתום על PDF (עמוד נוכחי)",
    contexts: ["page"]
  });
});

chrome.contextMenus.onClicked.addListener((info, tab) => {
  let pdfUrl = "";
  if (info.menuItemId === "sign-pdf-link") {
    pdfUrl = info.linkUrl;
  } else if (info.menuItemId === "sign-pdf-page") {
    pdfUrl = tab.url;
  }

  if (pdfUrl) {
    openEditor(pdfUrl);
  }
});

function openEditor(pdfUrl) {
  const editorUrl = chrome.runtime.getURL("editor.html") + "?file=" + encodeURIComponent(pdfUrl);
  chrome.tabs.create({ url: editorUrl });
}
