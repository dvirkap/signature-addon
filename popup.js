document.addEventListener("DOMContentLoaded", async () => {
  const signCurrentBtn = document.getElementById("sign-current");
  const openEditorBtn = document.getElementById("open-editor");
  const appTitle = document.getElementById("app-title");
  const creditsFooter = document.getElementById("credits-footer");

  // Determine UI language (defaults to Hebrew, falls back to English if not 'he')
  const userLang = navigator.language.startsWith('he') ? 'he' : 'en';

  if (userLang === 'en') {
    document.documentElement.dir = 'ltr';
    document.documentElement.lang = 'en';
    appTitle.textContent = "FreeSign PDF";
    signCurrentBtn.textContent = "Sign current PDF file";
    openEditorBtn.textContent = "Open signature workspace";
    creditsFooter.textContent = "FreeSign PDF by Dvir Kaplan";
  } else {
    document.documentElement.dir = 'rtl';
    document.documentElement.lang = 'he';
    appTitle.textContent = "FreeSign PDF - פשוט לחתום";
    signCurrentBtn.textContent = "חתום על קובץ ה-PDF הנוכחי";
    openEditorBtn.textContent = "פתח את לוח החתימות";
    creditsFooter.textContent = "FreeSign PDF ע\"י דביר קפלן";
  }

  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  
  if (tab && tab.url) {
    const url = tab.url.toLowerCase();
    if (url.endsWith(".pdf") || url.includes("content-type=application/pdf") || (url.startsWith("file://") && url.endsWith(".pdf"))) {
      signCurrentBtn.disabled = false;
      signCurrentBtn.addEventListener("click", () => {
        const editorUrl = chrome.runtime.getURL("editor.html") + "?file=" + encodeURIComponent(tab.url);
        chrome.tabs.create({ url: editorUrl });
      });
    }
  }

  openEditorBtn.addEventListener("click", () => {
    const editorUrl = chrome.runtime.getURL("editor.html");
    chrome.tabs.create({ url: editorUrl });
  });
});
