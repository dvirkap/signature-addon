// ============================================================
// ׳₪׳©׳•׳˜ ׳œ׳—׳×׳•׳  - Just sign
// Dynamic bilingual (HE/EN) rendering, scrolling & rotation.
// ============================================================

// Polyfill chrome.storage for PWA and Mobile WebView
if (typeof chrome === 'undefined' || !chrome.storage) {
  const mockStorage = {
    get: (keys, callback) => {
      return new Promise((resolve) => {
        const result = {};
        const keyList = Array.isArray(keys) ? keys : (typeof keys === 'string' ? [keys] : Object.keys(keys || {}));
        keyList.forEach(key => {
          const val = localStorage.getItem(key);
          if (val !== null) {
            try {
              result[key] = JSON.parse(val);
            } catch {
              result[key] = val;
            }
          } else if (keys && typeof keys === 'object' && !Array.isArray(keys)) {
            result[key] = keys[key];
          }
        });
        if (callback) callback(result);
        resolve(result);
      });
    },
    set: (items, callback) => {
      return new Promise((resolve) => {
        Object.keys(items).forEach(key => {
          const val = items[key];
          localStorage.setItem(key, typeof val === 'string' ? val : JSON.stringify(val));
        });
        if (callback) callback();
        resolve();
      });
    },
    remove: (keys, callback) => {
      return new Promise((resolve) => {
        const keyList = Array.isArray(keys) ? keys : [keys];
        keyList.forEach(key => localStorage.removeItem(key));
        if (callback) callback();
        resolve();
      });
    }
  };

  window.chrome = window.chrome || {};
  window.chrome.storage = {
    local: mockStorage,
    sync: mockStorage
  };
}

let pdfBytes = null;
let pdfFileName = "document.pdf";
let totalPagesCount = 1;
let savedSignatures = [];
let placedInstances = [];
let activeInstanceId = null;
let pageDimensions = []; // [{width, height}, ...] in PDF points
let currentLanguage = 'he';

// Drawing Canvas variables
const drawCanvas = document.getElementById('draw-canvas');
const drawCtx = drawCanvas.getContext('2d');
let isDrawing = false;
let lastX = 0, lastY = 0;
let drawColor = '#000000';
let drawWeight = 4;
let uploadedOriginalImg = null;

// PDF.js
let pdfjsLib = null;
let pdfjsDoc = null;

// Translation Dictionary
const translations = {
  he: {
    appName: "׳₪׳©׳•׳˜ ׳׳—׳×׳•׳",
    loadPdf: "נ“‚ ׳˜׳¢׳ PDF",
    saveDownloadPdf: "נ’¾ ׳©׳׳•׳¨ ׳•׳”׳•׳¨׳“ PDF",
    noFileLoaded: "׳׳ ׳ ׳˜׳¢׳ ׳§׳•׳‘׳¥ PDF",
    pageOf: "׳¢׳׳•׳“ {current} ׳׳×׳•׳ {total}",
    mySignatures: "׳”׳—׳×׳™׳׳•׳× ׳©׳׳™",
    newSignature: "׳—׳×׳™׳׳” ׳—׳“׳©׳”",
    subtabDraw: "׳¦׳™׳•׳¨",
    subtabType: "׳”׳§׳׳“׳”",
    subtabUpload: "׳”׳¢׳׳׳”",
    sigColor: "׳¦׳‘׳¢ ׳—׳×׳™׳׳”:",
    lineWidth: "׳¢׳•׳‘׳™ ׳§׳•:",
    drawThin: "׳“׳§",
    drawMedium: "׳‘׳™׳ ׳•׳ ׳™",
    drawThick: "׳¢׳‘׳”",
    sigNameLabel: "׳©׳ ׳”׳—׳×׳™׳׳”:",
    drawPlaceholder: '׳׳“׳•׳’׳׳”: "׳—׳×׳™׳׳” ׳¨׳©׳׳™׳×"',
    clearBtn: "׳ ׳§׳”",
    saveBtn: "׳©׳׳•׳¨ ׳—׳×׳™׳׳”",
    alertDrawSomething: "׳׳ ׳ ׳¦׳™׳™׳¨ ׳׳©׳”׳• ׳׳₪׳ ׳™ ׳”׳©׳׳™׳¨׳”!",
    typeInputLabel: "׳”׳§׳׳“ ׳˜׳§׳¡׳˜ ׳׳—׳×׳™׳׳”:",
    typePlaceholder: "׳”׳§׳׳“ ׳›׳׳ ׳׳× ׳©׳׳...",
    typeSigNamePlaceholder: '׳׳“׳•׳’׳׳”: "׳—׳×׳™׳׳” ׳“׳™׳’׳™׳˜׳׳™׳×"',
    fontStyleLabel: "׳‘׳—׳¨ ׳¡׳’׳ ׳•׳ ׳’׳•׳₪׳:",
    uploadLabel: "׳׳—׳¥ ׳׳”׳¢׳׳׳× ׳×׳׳•׳ ׳× ׳—׳×׳™׳׳”",
    uploadSubtext: "׳×׳•׳׳ ׳‘-PNG, JPG, SVG",
    previewTitle: "׳×׳¦׳•׳’׳” ׳׳§׳“׳™׳׳”:",
    removeBgLabel: "׳”׳¡׳¨ ׳¨׳§׳¢ ׳׳‘׳ (׳”׳₪׳•׳ ׳׳©׳§׳•׳£)",
    bgThresholdLabel: "׳¨׳’׳™׳©׳•׳× ׳”׳¡׳¨׳”:",
    uploadNamePlaceholder: '׳׳“׳•׳’׳׳”: "׳—׳×׳™׳׳” ׳¡׳¨׳•׳§׳”"',
    emptyState: "׳׳™׳ ׳—׳×׳™׳׳•׳× ׳©׳׳•׳¨׳•׳×. ׳׳—׳¥ ׳¢׳ ׳”׳׳©׳•׳ ׳™׳× \"׳—׳×׳™׳׳” ׳—׳“׳©׳”\" ׳›׳“׳™ ׳׳™׳¦׳•׳¨ ׳—׳×׳™׳׳”.",
    maxQuota: "׳׳›׳¡׳” ׳׳¨׳‘׳™׳× ׳©׳ 15 ׳—׳×׳™׳׳•׳×.",
    deleteConfirm: '׳׳׳—׳•׳§ ׳׳× "{name}"?',
    loadPdfFirst: "׳˜׳¢׳ PDF ׳×׳—׳™׳׳”!",
    loadingPdfText: "׳˜׳•׳¢׳ PDF...",
    loadingError: "׳©׳’׳™׳׳× ׳˜׳¢׳™׳ ׳”",
    loadPdfFailed: "׳׳ ׳”׳¦׳׳—׳ ׳• ׳׳˜׳¢׳•׳ ׳׳× ׳”-PDF ׳׳”׳›׳×׳•׳‘׳×. ׳׳ ׳ ׳©׳׳•׳¨ ׳׳× ׳”׳§׳•׳‘׳¥ ׳•׳’׳¨׳•׳¨ ׳׳•׳×׳• ׳׳›׳׳.",
    loadingPdfAlert: "׳©׳’׳™׳׳” ׳‘׳˜׳¢׳™׳ ׳× ׳”-PDF.",
    creatingFile: "ג³ ׳™׳•׳¦׳¨ ׳§׳•׳‘׳¥...",
    signingError: "׳©׳’׳™׳׳” ׳‘׳™׳¦׳™׳¨׳× ׳”-PDF ׳”׳—׳×׳•׳.",
    snapTooltip: "׳’׳¨׳•׳¨ ׳׳¡׳™׳‘׳•׳‘ ׳”׳—׳×׳™׳׳”",
    deleteTooltip: "׳׳—׳§",
    creditText: '׳”׳×׳•׳¡׳£ ׳ ׳•׳¦׳¨ ׳›׳©׳™׳¨׳•׳× ׳¢"׳™ <strong>׳“׳‘׳™׳¨ ׳§׳₪׳׳</strong> ׳׳׳¢׳ ׳׳ ׳©׳™ ׳”׳—׳™׳ ׳•׳ ג₪ן¸',
    themeLabel: "׳¡׳’׳ ׳•׳:",
    themeLight: "׳ ׳™׳§׳™׳•׳ ׳§׳׳׳¡׳™",
    themeWarm: "׳ ׳™׳™׳¨ ׳—׳",
    themeChalkboard: "׳׳•׳— ׳›׳™׳×׳”",
    themeDark: "׳¡׳’׳ ׳•׳ ׳›׳”׳”",
    dropZoneHeader: "׳’׳¨׳•׳¨ ׳•׳”׳©׳׳ ׳§׳•׳‘׳¥ PDF ׳›׳׳",
    dropZoneSub: "׳׳• ׳׳—׳¥ ׳¢׳ \"׳˜׳¢׳ PDF\" ׳‘׳¡׳¨׳’׳ ׳”׳¢׳׳™׳•׳",
    langLabel: "׳©׳₪׳” / Lang:"
  },
  en: {
    appName: "Just sign",
    loadPdf: "נ“‚ Load PDF",
    saveDownloadPdf: "נ’¾ Save & Download PDF",
    noFileLoaded: "No PDF file loaded",
    pageOf: "Page {current} of {total}",
    mySignatures: "My Signatures",
    newSignature: "New Signature",
    subtabDraw: "Draw",
    subtabType: "Type",
    subtabUpload: "Upload",
    sigColor: "Signature Color:",
    lineWidth: "Line Width:",
    drawThin: "Thin",
    drawMedium: "Medium",
    drawThick: "Thick",
    sigNameLabel: "Signature Name:",
    drawPlaceholder: 'e.g. "Official Signature"',
    clearBtn: "Clear",
    saveBtn: "Save Signature",
    alertDrawSomething: "Please draw something before saving!",
    typeInputLabel: "Type text for signature:",
    typePlaceholder: "Type your name here...",
    typeSigNamePlaceholder: 'e.g. "Digital Signature"',
    fontStyleLabel: "Choose font style:",
    uploadLabel: "Click to upload signature image",
    uploadSubtext: "Supports PNG, JPG, SVG",
    previewTitle: "Preview:",
    removeBgLabel: "Remove white background (make transparent)",
    bgThresholdLabel: "Removal sensitivity:",
    uploadNamePlaceholder: 'e.g. "Scanned Signature"',
    emptyState: "No saved signatures. Click the \"New Signature\" tab to create one.",
    maxQuota: "Maximum quota of 15 signatures reached.",
    deleteConfirm: 'Delete "{name}"?',
    loadPdfFirst: "Load PDF first!",
    loadingPdfText: "Loading PDF...",
    loadingError: "Loading Error",
    loadPdfFailed: "Failed to load PDF from URL. Please save the file and drag it here.",
    loadingPdfAlert: "Error loading PDF.",
    creatingFile: "ג³ Creating file...",
    signingError: "Error generating signed PDF.",
    snapTooltip: "Drag to rotate signature",
    deleteTooltip: "Delete",
    creditText: "Extension created as a service by <strong>Dvir Kaplan</strong> for educators ג₪ן¸",
    themeLabel: "Theme:",
    themeLight: "Classic Light",
    themeWarm: "Warm Paper",
    themeChalkboard: "Classroom Chalkboard",
    themeDark: "Sleek Dark",
    dropZoneHeader: "Drag and drop PDF file here",
    dropZoneSub: "or click \"Load PDF\" in the top bar",
    langLabel: "Language:"
  }
};

document.addEventListener("DOMContentLoaded", async () => {
  await loadPdfJs();

  initTabs();
  initDrawingPad();
  initSignatureCreator();
  initDropZone();
  initSidebarTabs();
  loadSavedSignatures();
  initScrollDetection();
  initThemes();
  initLanguages();

  const menuToggle = document.getElementById('menu-toggle');
  if (menuToggle) {
    menuToggle.onclick = () => {
      document.querySelector('.sidebar').classList.toggle('active');
    };
  }

  const params = new URLSearchParams(window.location.search);
  const pdfUrl = params.get('file');
  if (pdfUrl) loadPdfFromUrl(pdfUrl);
});

async function loadPdfJs() {
  return new Promise((resolve, reject) => {
    const script = document.createElement('script');
    script.src = 'libs/pdf.min.js';
    script.onload = () => {
      pdfjsLib = window.pdfjsLib;
      pdfjsLib.GlobalWorkerOptions.workerSrc = 'libs/pdf.worker.min.js';
      resolve();
    };
    script.onerror = reject;
    document.head.appendChild(script);
  });
}

// ==================== Languages ====================
function initLanguages() {
  const select = document.getElementById('lang-select');
  select.onchange = (e) => {
    const lang = e.target.value;
    currentLanguage = lang;
    chrome.storage.local.set({ selected_lang: lang });
    applyLanguage(lang);
  };
  
  chrome.storage.local.get(['selected_lang'], (r) => {
    const lang = r.selected_lang || 'he';
    currentLanguage = lang;
    select.value = lang;
    applyLanguage(lang);
  });
}

function applyLanguage(lang) {
  document.documentElement.dir = lang === 'he' ? 'rtl' : 'ltr';
  document.documentElement.lang = lang;
  document.title = translations[lang].appName + " - PDF";

  // Translate elements with data-i18n
  document.querySelectorAll('[data-i18n]').forEach(el => {
    const key = el.dataset.i18n;
    if (translations[lang][key]) {
      el.innerHTML = translations[lang][key];
    }
  });

  // Translate placeholders
  document.querySelectorAll('[data-i18n-placeholder]').forEach(el => {
    const key = el.dataset.i18nPlaceholder;
    if (translations[lang][key]) {
      el.placeholder = translations[lang][key];
    }
  });

  // Update dynamic content elements
  updatePageLabel();
  loadSavedSignatures();
}

function updatePageLabel() {
  if (!pdfjsDoc) return;
  const pageIdx = getMostVisiblePage();
  const labelEl = document.getElementById('page-num-container-label');
  if (labelEl) {
    labelEl.innerHTML = translations[currentLanguage].pageOf
      .replace('{current}', `<input type="number" id="current-page-num" value="${pageIdx + 1}" min="1" readonly>`)
      .replace('{total}', `<span id="total-pages">${totalPagesCount}</span>`);
  }
}

// ==================== Themes switching ====================
function initThemes() {
  const select = document.getElementById('theme-select');
  select.onchange = (e) => {
    const t = e.target.value;
    document.body.className = 'theme-' + t;
    chrome.storage.local.set({ selected_theme: t });
  };
  chrome.storage.local.get(['selected_theme'], (r) => {
    const t = r.selected_theme || 'light';
    select.value = t;
    document.body.className = 'theme-' + t;
  });
}

// ==================== Tab Switching ====================
function initTabs() {
  const tabMy = document.getElementById('tab-my-signatures');
  const tabNew = document.getElementById('tab-new-signature');
  const contentMy = document.getElementById('content-my-signatures');
  const contentNew = document.getElementById('content-new-signature');
  tabMy.onclick = () => { tabMy.classList.add('active'); tabNew.classList.remove('active'); contentMy.style.display='block'; contentNew.style.display='none'; };
  tabNew.onclick = () => { tabNew.classList.add('active'); tabMy.classList.remove('active'); contentNew.style.display='block'; contentMy.style.display='none'; };
}

function initSidebarTabs() {
  const subtabs = ['subtab-draw','subtab-type','subtab-upload'];
  const modes = ['mode-draw','mode-type','mode-upload'];
  subtabs.forEach((tabId, idx) => {
    document.getElementById(tabId).onclick = () => {
      subtabs.forEach(t => document.getElementById(t).classList.remove('active'));
      modes.forEach(m => document.getElementById(m).style.display='none');
      document.getElementById(tabId).classList.add('active');
      document.getElementById(modes[idx]).style.display='flex';
      if (tabId === 'subtab-draw') resizeDrawingCanvas();
    };
  });
}

// ==================== Drawing Pad ====================
function initDrawingPad() {
  document.querySelectorAll('#mode-draw .color-dot').forEach(dot => {
    dot.onclick = () => { document.querySelectorAll('#mode-draw .color-dot').forEach(d => d.classList.remove('active')); dot.classList.add('active'); drawColor = dot.dataset.color; };
  });
  document.getElementById('draw-weight').onchange = e => drawWeight = parseInt(e.target.value);
  document.getElementById('btn-clear-draw').onclick = () => drawCtx.clearRect(0, 0, drawCanvas.width, drawCanvas.height);

  function startDraw(e) { isDrawing = true; const r = drawCanvas.getBoundingClientRect(); lastX = (e.clientX||e.touches[0].clientX) - r.left; lastY = (e.clientY||e.touches[0].clientY) - r.top; }
  function doDraw(e) {
    if (!isDrawing) return;
    const r = drawCanvas.getBoundingClientRect();
    const x = (e.clientX||e.touches[0].clientX) - r.left;
    const y = (e.clientY||e.touches[0].clientY) - r.top;
    drawCtx.beginPath(); drawCtx.moveTo(lastX, lastY); drawCtx.lineTo(x, y);
    drawCtx.strokeStyle = drawColor; drawCtx.lineWidth = drawWeight; drawCtx.lineCap = 'round'; drawCtx.lineJoin = 'round'; drawCtx.stroke();
    lastX = x; lastY = y;
  }
  function stopDraw() { isDrawing = false; }

  drawCanvas.addEventListener('mousedown', startDraw); drawCanvas.addEventListener('mousemove', doDraw);
  drawCanvas.addEventListener('mouseup', stopDraw); drawCanvas.addEventListener('mouseout', stopDraw);
  drawCanvas.addEventListener('touchstart', e => { startDraw(e.touches[0]); e.preventDefault(); }, {passive:false});
  drawCanvas.addEventListener('touchmove', e => { doDraw(e.touches[0]); e.preventDefault(); }, {passive:false});
  drawCanvas.addEventListener('touchend', stopDraw);
}

function resizeDrawingCanvas() {
  const r = drawCanvas.parentElement.getBoundingClientRect();
  drawCanvas.width = r.width; drawCanvas.height = 150;
}

// ==================== Canvas Helpers ====================
function cropCanvas(canvas) {
  const ctx = canvas.getContext("2d"), w = canvas.width, h = canvas.height;
  const data = ctx.getImageData(0, 0, w, h).data;
  let minX=w, minY=h, maxX=0, maxY=0, found=false;
  for (let y=0; y<h; y++) for (let x=0; x<w; x++) { const a = data[(y*w+x)*4+3]; if (a>5) { found=true; minX=Math.min(minX,x); minY=Math.min(minY,y); maxX=Math.max(maxX,x); maxY=Math.max(maxY,y); } }
  if (!found) return canvas;
  minX=Math.max(0,minX-5); minY=Math.max(0,minY-5); maxX=Math.min(w-1,maxX+5); maxY=Math.min(h-1,maxY+5);
  const c2 = document.createElement("canvas"); c2.width=maxX-minX+1; c2.height=maxY-minY+1;
  c2.getContext("2d").drawImage(canvas, minX, minY, c2.width, c2.height, 0, 0, c2.width, c2.height);
  return c2;
}

function compressSignature(canvas) {
  const maxW = 240; let tw = canvas.width, th = canvas.height;
  if (tw > maxW) { const s = maxW/tw; tw = maxW; th *= s; }
  const tc = document.createElement('canvas'); tc.width = tw; tc.height = th;
  tc.getContext('2d').drawImage(canvas, 0, 0, tw, th);
  // Compress as WebP with 0.4 quality (supports transparency, extremely small file size: 1-3KB)
  return tc.toDataURL("image/webp", 0.4);
}

function convertWebpToPng(webpDataUrl) {
  return new Promise(resolve => {
    const img = new Image(); img.src = webpDataUrl;
    img.onload = () => { const c = document.createElement('canvas'); c.width=img.naturalWidth; c.height=img.naturalHeight; c.getContext('2d').drawImage(img,0,0); resolve(c.toDataURL("image/png")); };
    img.onerror = () => resolve(webpDataUrl);
  });
}

// ==================== Signature Creator ====================
function initSignatureCreator() {
  // Save drawn
  document.getElementById('btn-save-draw').onclick = async () => {
    const defaultName = currentLanguage === 'he' ? "׳—׳×׳™׳׳” ׳‘׳¦׳™׳•׳¨" : "Drawn Signature";
    const name = document.getElementById('draw-name').value.trim() || defaultName;
    const buf = drawCtx.getImageData(0,0,drawCanvas.width,drawCanvas.height);
    if (!Array.prototype.some.call(buf.data, (v,i) => i%4===3 && v>0)) { alert(translations[currentLanguage].alertDrawSomething); return; }
    await saveSignatureToStorage({ id:"sig_"+Date.now(), name, imgData: compressSignature(cropCanvas(drawCanvas)), type:"draw" });
    document.getElementById('draw-name').value = ""; drawCtx.clearRect(0,0,drawCanvas.width,drawCanvas.height);
    document.getElementById('tab-my-signatures').click();
  };

  // Type signature
  const typeInput = document.getElementById('type-input');
  let selectedTypeColor = '#000000', selectedFontFamily = 'Caveat';
  document.querySelectorAll('#type-color-picker .color-dot').forEach(dot => {
    dot.onclick = () => { document.querySelectorAll('#type-color-picker .color-dot').forEach(d=>d.classList.remove('active')); dot.classList.add('active'); selectedTypeColor = dot.dataset.color; updatePreviews(); };
  });
  typeInput.oninput = updatePreviews;
  function updatePreviews() { 
    const fallbackText = currentLanguage === 'he' ? "׳—׳×׳™׳׳” ׳©׳׳™" : "My Signature";
    const t = typeInput.value.trim() || fallbackText; 
    document.querySelectorAll('.font-preview-card .preview-text').forEach(el => { el.textContent=t; el.style.color=selectedTypeColor; }); 
  }
  document.querySelectorAll('.font-preview-card').forEach(card => {
    card.onclick = () => { document.querySelectorAll('.font-preview-card').forEach(c=>c.classList.remove('active')); card.classList.add('active'); selectedFontFamily=card.dataset.font; };
  });
  document.getElementById('btn-save-type').onclick = async () => {
    const text = typeInput.value.trim(); if (!text) { alert(currentLanguage==='he'?"׳׳ ׳ ׳”׳§׳׳“ ׳˜׳§׳¡׳˜!":"Please type text!"); return; }
    const defaultName = currentLanguage === 'he' ? "׳—׳×׳™׳׳× ׳˜׳§׳¡׳˜" : "Typed Signature";
    const name = document.getElementById('type-name').value.trim() || defaultName;
    const tc = document.createElement('canvas'); tc.width=600; tc.height=150; const tctx=tc.getContext('2d');
    tctx.font = `64px '${selectedFontFamily}', cursive`; tctx.fillStyle = selectedTypeColor; tctx.textBaseline='middle'; tctx.textAlign='center';
    tctx.fillText(text, 300, 75);
    await saveSignatureToStorage({ id:"sig_"+Date.now(), name, imgData: compressSignature(cropCanvas(tc)), type:"text" });
    typeInput.value=""; document.getElementById('type-name').value=""; document.getElementById('tab-my-signatures').click();
  };

  // Upload
  const uploadZone = document.getElementById('upload-dropzone'), imgInput = document.getElementById('image-upload-input');
  const previewContainer = document.getElementById('upload-preview-container'), previewImg = document.getElementById('upload-preview-img');
  const removeBgCb = document.getElementById('remove-bg-checkbox'), bgThreshold = document.getElementById('bg-threshold'), thresholdVal = document.getElementById('threshold-val');

  uploadZone.onclick = () => imgInput.click();
  imgInput.onchange = handleImgUpload;
  uploadZone.addEventListener('dragover', e => { e.preventDefault(); uploadZone.style.borderColor='var(--accent-color)'; });
  uploadZone.addEventListener('dragleave', () => uploadZone.style.borderColor='var(--border-color)');
  uploadZone.addEventListener('drop', e => { e.preventDefault(); uploadZone.style.borderColor='var(--border-color)'; if(e.dataTransfer.files.length){imgInput.files=e.dataTransfer.files; handleImgUpload();} });

  function handleImgUpload() {
    const file = imgInput.files[0]; if (!file) return;
    const reader = new FileReader();
    reader.onload = e => { uploadedOriginalImg = new Image(); uploadedOriginalImg.src = e.target.result; uploadedOriginalImg.onload = () => { uploadZone.style.display='none'; previewContainer.style.display='block'; processUploaded(); }; };
    reader.readAsDataURL(file);
  }
  removeBgCb.onchange = () => { document.getElementById('bg-threshold-group').style.opacity = removeBgCb.checked?"1":"0.5"; processUploaded(); };
  bgThreshold.oninput = e => { thresholdVal.textContent = e.target.value; processUploaded(); };

  window.handleScannedSignatureImage = (base64DataUrl) => {
    document.getElementById('tab-new-signature').click();
    document.getElementById('subtab-upload').click();
    
    uploadedOriginalImg = new Image();
    uploadedOriginalImg.src = base64DataUrl;
    uploadedOriginalImg.onload = () => {
      uploadZone.style.display = 'none';
      previewContainer.style.display = 'block';
      const nameInput = document.getElementById('upload-name');
      if (nameInput) {
        nameInput.value = `סריקה ${new Date().toLocaleDateString('he-IL')}`;
      }
      processUploaded();
    };
  };

  function processUploaded() {
    if (!uploadedOriginalImg) return;
    const c = document.createElement('canvas'); c.width=uploadedOriginalImg.naturalWidth; c.height=uploadedOriginalImg.naturalHeight;
    const ctx = c.getContext('2d'); ctx.drawImage(uploadedOriginalImg, 0, 0);
    if (removeBgCb.checked) {
      const threshold = parseInt(bgThreshold.value);
      const id = ctx.getImageData(0, 0, c.width, c.height); const d = id.data;
      for (let i=0; i<d.length; i+=4) { if ((d[i]+d[i+1]+d[i+2])/3 >= threshold) d[i+3]=0; }
      ctx.putImageData(id, 0, 0);
    }
    previewImg.src = c.toDataURL("image/png");
  }

  document.getElementById('btn-save-upload').onclick = async () => {
    const defaultName = currentLanguage === 'he' ? "׳—׳×׳™׳׳” ׳©׳”׳•׳¢׳׳×׳”" : "Uploaded Signature";
    const name = document.getElementById('upload-name').value.trim() || defaultName;
    const tc = document.createElement('canvas'); tc.width=previewImg.naturalWidth||400; tc.height=previewImg.naturalHeight||200;
    tc.getContext('2d').drawImage(previewImg, 0, 0);
    await saveSignatureToStorage({ id:"sig_"+Date.now(), name, imgData: compressSignature(cropCanvas(tc)), type:"upload" });
    document.getElementById('upload-name').value=""; uploadedOriginalImg=null; uploadZone.style.display='block'; previewContainer.style.display='none'; imgInput.value="";
    document.getElementById('tab-my-signatures').click();
  };
}

// ==================== Storage ====================
async function saveSignatureToStorage(sig) {
  try {
    let useSync = true;
    let isLocalOnly = false;
    let imgData = sig.imgData;

    // Text signatures only save small metadata, always fits in sync storage
    if (sig.type === "text") {
      useSync = true;
    } else {
      // WebP compressed data check: sync storage quota is 8,192 bytes per item
      if (imgData && imgData.length < 8000) {
        useSync = true;
      } else {
        useSync = false;
        isLocalOnly = true;
      }
    }

    // Get lists
    const syncR = await chrome.storage.sync.get(['signature_list']);
    const localR = await chrome.storage.local.get(['signature_list']);
    
    const syncList = syncR.signature_list || [];
    const localList = localR.signature_list || [];

    if (syncList.length >= 15 || localList.length >= 15) {
      alert(translations[currentLanguage].maxQuota);
      return;
    }

    const newEntry = {
      id: sig.id,
      name: sig.name,
      type: sig.type,
      isLocalOnly: isLocalOnly
    };

    if (sig.type === "text") {
      newEntry.text = sig.text;
      newEntry.color = sig.color;
      newEntry.font = sig.font;
    }

    if (useSync) {
      // Save signature index & image to sync
      syncList.push(newEntry);
      const store = { signature_list: syncList };
      if (sig.type !== "text") {
        store['sigdata_' + sig.id] = imgData;
      }
      await chrome.storage.sync.set(store);

      // Keep local list in sync
      const existsInLocal = localList.some(l => l.id === sig.id);
      if (!existsInLocal) {
        localList.push(newEntry);
        await chrome.storage.local.set({ signature_list: localList });
      }
    } else {
      // Image too large, save image locally and mark metadata as local-only in sync list
      localList.push(newEntry);
      const localStore = { signature_list: localList };
      localStore['sigdata_' + sig.id] = imgData;
      await chrome.storage.local.set(localStore);

      // Save metadata entry in sync list so other devices know it exists (but won't show image)
      syncList.push(newEntry);
      await chrome.storage.sync.set({ signature_list: syncList });
    }

    loadSavedSignatures();
  } catch (e) {
    console.error("Storage save error:", e);
    alert(currentLanguage === 'he' ? "׳©׳’׳™׳׳” ׳‘׳©׳׳™׳¨׳× ׳”׳—׳×׳™׳׳”." : "Error saving signature.");
  }
}

async function loadSavedSignatures() {
  const container = document.getElementById('signatures-list');
  container.innerHTML = '';

  const syncR = await chrome.storage.sync.get(['signature_list']);
  const localR = await chrome.storage.local.get(['signature_list']);
  const syncList = syncR.signature_list || [];
  const localList = localR.signature_list || [];
  
  // Merge lists (prefer local attributes if ID matches, in case local holds the image data)
  const merged = [...localList, ...syncList.filter(s => !localList.some(l => l.id === s.id))];
  savedSignatures = merged;

  if (!merged.length) {
    container.innerHTML = `<div class="empty-state">${translations[currentLanguage].emptyState}</div>`;
    return;
  }

  for (const sig of merged) {
    let imgData = null;

    if (sig.type === "text") {
      // Recreate typed signature image on the fly! Extremely light, syncs perfectly.
      const tc = document.createElement('canvas');
      tc.width = 300;
      tc.height = 80;
      const tctx = tc.getContext('2d');
      tctx.font = `36px '${sig.font}', Pacifico, Caveat, cursive`;
      tctx.fillStyle = sig.color || '#000000';
      tctx.textBaseline = 'middle';
      tctx.textAlign = 'center';
      tctx.fillText(sig.text, 150, 40);
      imgData = compressSignature(cropCanvas(tc));
      sig.imgData = imgData;
    } else {
      // Load drawing/uploaded image
      imgData = (await chrome.storage.local.get(['sigdata_' + sig.id]))['sigdata_' + sig.id]
             || (await chrome.storage.sync.get(['sigdata_' + sig.id]))['sigdata_' + sig.id];
      sig.imgData = imgData;
    }

    // If it's local only, and we are on a device without the image data
    if (!imgData) {
      if (sig.isLocalOnly) {
        // Render a placeholder explaining this is local to another machine
        const card = document.createElement('div');
        card.className = 'sig-card sig-card-local-disabled';
        const titleText = currentLanguage === 'he' ? '׳–׳׳™׳ ׳‘׳׳›׳©׳™׳¨ ׳”׳׳§׳•׳¨ ׳‘׳׳‘׳“' : 'Available on source device only';
        card.innerHTML = `
          <div class="sig-card-img-wrapper sig-card-local-disabled-wrapper">
            <span style="font-size:24px;">נ’»</span>
          </div>
          <div class="sig-card-info">
            <span class="sig-card-name">${sig.name} <span class="local-indicator" title="${titleText}">ג ן¸</span></span>
            <button class="sig-card-delete" data-id="${sig.id}">נ—‘ן¸</button>
          </div>`;
        card.querySelector('.sig-card-delete').onclick = async e => {
          e.stopPropagation();
          if (confirm(translations[currentLanguage].deleteConfirm.replace('{name}', sig.name))) {
            await deleteSig(sig.id);
          }
        };
        container.appendChild(card);
        continue;
      }
      continue;
    }

    const card = document.createElement('div');
    card.className = 'sig-card';
    const indicatorText = currentLanguage === 'he' ? '׳–׳׳™׳ ׳‘׳׳›׳©׳™׳¨ ׳–׳” ׳‘׳׳‘׳“' : 'Local machine only';
    const localIndicator = sig.isLocalOnly ? `<span class="local-indicator" title="${indicatorText}">נ’»</span>` : '';
    
    card.innerHTML = `
      <div class="sig-card-img-wrapper"><img src="${imgData}" alt="${sig.name}"></div>
      <div class="sig-card-info">
        <span class="sig-card-name">${sig.name} ${localIndicator}</span>
        <button class="sig-card-delete" data-id="${sig.id}">נ—‘ן¸</button>
      </div>`;

    card.onclick = e => {
      if (e.target.classList.contains('sig-card-delete')) return;
      placeSignature(sig);
    };

    card.querySelector('.sig-card-delete').onclick = async e => {
      e.stopPropagation();
      if (confirm(translations[currentLanguage].deleteConfirm.replace('{name}', sig.name))) {
        await deleteSig(sig.id);
      }
    };
    container.appendChild(card);
  }
}

async function deleteSig(id) {
  try {
    // Delete from sync list & data
    const syncR = await chrome.storage.sync.get(['signature_list']);
    if (syncR.signature_list) {
      const newList = syncR.signature_list.filter(s => s.id !== id);
      await chrome.storage.sync.set({ signature_list: newList });
      await chrome.storage.sync.remove(['sigdata_' + id]);
    }
    
    // Delete from local list & data
    const localR = await chrome.storage.local.get(['signature_list']);
    if (localR.signature_list) {
      const newList = localR.signature_list.filter(s => s.id !== id);
      await chrome.storage.local.set({ signature_list: newList });
      await chrome.storage.local.remove(['sigdata_' + id]);
    }

    loadSavedSignatures();
  } catch (e) {
    console.error("Delete signature error:", e);
  }
}

// ==================== PDF Loading ====================
function initDropZone() {
  const dz = document.getElementById('drop-zone'), fi = document.getElementById('pdf-file-input');
  dz.onclick = () => fi.click();
  fi.onchange = e => { if (e.target.files[0]) loadPdfFile(e.target.files[0]); };
  window.addEventListener('dragover', e => e.preventDefault());
  window.addEventListener('drop', e => e.preventDefault());
  dz.addEventListener('dragover', e => { e.preventDefault(); dz.classList.add('dragover'); });
  dz.addEventListener('dragleave', () => dz.classList.remove('dragover'));
  dz.addEventListener('drop', e => { e.preventDefault(); dz.classList.remove('dragover'); if(e.dataTransfer.files.length) loadPdfFile(e.dataTransfer.files[0]); });
}

function loadPdfFile(file) {
  pdfFileName = file.name;
  const reader = new FileReader();
  reader.onload = e => { pdfBytes = new Uint8Array(e.target.result); renderPdf(); };
  reader.readAsArrayBuffer(file);
}

async function loadPdfFromUrl(url) {
  document.getElementById('file-info').innerHTML = `<span>${translations[currentLanguage].loadingPdfText}</span>`;
  try {
    const resp = await fetch(url); if (!resp.ok) throw new Error("Network error");
    pdfBytes = new Uint8Array(await resp.arrayBuffer());
    try { pdfFileName = new URL(url).pathname.split('/').pop() || "document.pdf"; } catch { pdfFileName = "download.pdf"; }
    if (!pdfFileName.toLowerCase().endsWith('.pdf')) pdfFileName += '.pdf';
    renderPdf();
  } catch (e) {
    console.error("Fetch error:", e);
    document.getElementById('file-info').innerHTML = `<span style="color:var(--error-color);">${translations[currentLanguage].loadingError}</span>`;
    alert(translations[currentLanguage].loadPdfFailed);
  }
}

// ==================== PDF Rendering (Multi-page scrolling) ====================
async function renderPdf() {
  document.getElementById('drop-zone').style.display = 'none';
  document.getElementById('pages-container').style.display = 'flex';
  document.getElementById('page-controls').style.display = 'flex';
  document.getElementById('download-pdf').style.display = 'inline-flex';
  document.getElementById('file-info').innerHTML = `<span>${pdfFileName}</span>`;

  placedInstances = [];
  pageDimensions = [];
  
  const container = document.getElementById('pages-container');
  container.innerHTML = ''; // Clear old pages

  try {
    // Load with PDF.js
    pdfjsDoc = await pdfjsLib.getDocument({
      data: pdfBytes.slice(0),
      cMapUrl: 'https://cdn.jsdelivr.net/npm/pdfjs-dist@3.11.174/cmaps/',
      cMapPacked: true,
      standardFontDataUrl: 'https://cdn.jsdelivr.net/npm/pdfjs-dist@3.11.174/standard_fonts/',
      disableFontFace: true
    }).promise;

    totalPagesCount = pdfjsDoc.numPages;
    
    updatePageLabel();

    // Load PDF-lib for dimensions
    const pdfLibDoc = await PDFLib.PDFDocument.load(pdfBytes.slice(0));
    for (let i = 0; i < pdfLibDoc.getPageCount(); i++) {
      const pg = pdfLibDoc.getPage(i);
      const { width, height } = pg.getSize();
      pageDimensions.push({ width, height });
    }

    // Render pages sequentially
    for (let pageNum = 1; pageNum <= totalPagesCount; pageNum++) {
      await renderPage(pageNum);
    }

  } catch (err) {
    console.error("PDF load error:", err);
    alert(translations[currentLanguage].loadingPdfAlert);
  }
}

async function renderPage(pageNum) {
  const container = document.getElementById('pages-container');
  const pageIdx = pageNum - 1;

  // Create page DOM structure
  const pageContainer = document.createElement('div');
  pageContainer.className = 'page-container';
  pageContainer.id = `page-container-${pageIdx}`;
  pageContainer.dataset.pageIndex = pageIdx;

  const label = document.createElement('div');
  label.className = 'page-number-label';
  label.textContent = currentLanguage === 'he' ? `׳¢׳׳•׳“ ${pageNum} ׳׳×׳•׳ ${totalPagesCount}` : `Page ${pageNum} of ${totalPagesCount}`;
  pageContainer.appendChild(label);

  const renderArea = document.createElement('div');
  renderArea.className = 'page-render-area';
  renderArea.id = `page-render-area-${pageIdx}`;

  const canvas = document.createElement('canvas');
  canvas.id = `page-canvas-${pageIdx}`;
  canvas.style.display = 'none';
  renderArea.appendChild(canvas);

  const img = document.createElement('img');
  img.id = `page-image-${pageIdx}`;
  img.className = 'page-image';
  img.alt = `׳¢׳׳•׳“ ${pageNum}`;
  renderArea.appendChild(img);

  const overlay = document.createElement('div');
  overlay.id = `signature-overlay-${pageIdx}`;
  overlay.className = 'signature-overlay';
  overlay.dataset.pageIndex = pageIdx;
  renderArea.appendChild(overlay);

  pageContainer.appendChild(renderArea);
  container.appendChild(pageContainer);

  // Load and render using PDF.js
  const page = await pdfjsDoc.getPage(pageNum);
  const RENDER_SCALE = 1.8;
  const viewport = page.getViewport({ scale: RENDER_SCALE });

  canvas.width = viewport.width;
  canvas.height = viewport.height;
  const ctx = canvas.getContext('2d');

  await page.render({
    canvasContext: ctx,
    viewport: viewport,
    intent: 'display'
  }).promise;

  // Set as image source
  img.src = canvas.toDataURL('image/png');

  // Display size adjustments
  const displayW = viewport.width / RENDER_SCALE;
  const displayH = viewport.height / RENDER_SCALE;

  img.style.width = displayW + 'px';
  img.style.height = displayH + 'px';
  renderArea.style.width = displayW + 'px';
  renderArea.style.height = displayH + 'px';
  overlay.style.width = displayW + 'px';
  overlay.style.height = displayH + 'px';
}

// ==================== Scroll Detection ====================
function initScrollDetection() {
  const viewport = document.getElementById('pdf-viewport');
  viewport.addEventListener('scroll', () => {
    if (!pdfjsDoc) return;
    const pageIdx = getMostVisiblePage();
    const pageNumInput = document.getElementById('current-page-num');
    if (pageNumInput) pageNumInput.value = pageIdx + 1;
  });
}

function getMostVisiblePage() {
  const viewport = document.getElementById('pdf-viewport');
  const rect = viewport.getBoundingClientRect();
  const viewportCenter = rect.top + rect.height / 2;

  let closestPageIdx = 0;
  let closestDist = Infinity;

  const pageContainers = document.querySelectorAll('.page-container');
  pageContainers.forEach((container, idx) => {
    const r = container.getBoundingClientRect();
    const pageCenter = r.top + r.height / 2;
    const dist = Math.abs(viewportCenter - pageCenter);
    if (dist < closestDist) {
      closestDist = dist;
      closestPageIdx = idx;
    }
  });
  return closestPageIdx;
}

// ==================== Signature Placement ====================
function placeSignature(sig) {
  if (!pdfjsDoc) { alert(translations[currentLanguage].loadPdfFirst); return; }

  const pageIndex = getMostVisiblePage();
  const overlay = document.getElementById(`signature-overlay-${pageIndex}`);
  if (!overlay) return;

  const img = new Image(); img.src = sig.imgData;
  img.onload = () => {
    const aspect = img.naturalWidth / img.naturalHeight;
    const defaultW = 130, defaultH = defaultW / aspect;
    const oW = overlay.clientWidth, oH = overlay.clientHeight;

    const inst = {
      id: "placed_" + Date.now(),
      pageIndex: pageIndex,
      rx: ((oW - defaultW) / 2) / oW,
      ry: ((oH - defaultH) / 2) / oH,
      rw: defaultW / oW,
      rh: defaultH / oH,
      aspectRatio: aspect,
      rotation: 0,
      imgData: sig.imgData
    };
    placedInstances.push(inst);
    renderPlacedInstance(inst);
    selectInstance(inst.id);
  };
}

function renderPlacedInstance(inst) {
  const overlay = document.getElementById(`signature-overlay-${inst.pageIndex}`);
  if (!overlay) return;

  const oW = overlay.clientWidth, oH = overlay.clientHeight;

  const el = document.createElement('div');
  el.className = 'sig-instance'; el.id = inst.id;
  el.style.left = (inst.rx * oW) + 'px';
  el.style.top = (inst.ry * oH) + 'px';
  el.style.width = (inst.rw * oW) + 'px';
  el.style.height = (inst.rh * oH) + 'px';
  el.style.transform = `rotate(${inst.rotation}deg)`;

  el.innerHTML = `<img src="${inst.imgData}" draggable="false"><button class="delete-btn" title="${translations[currentLanguage].deleteTooltip}">ֳ—</button>
    <div class="rotate-line"></div><div class="rotate-handle" title="${translations[currentLanguage].snapTooltip}"></div>
    <div class="resize-handle top-left"></div><div class="resize-handle top-right"></div>
    <div class="resize-handle bottom-left"></div><div class="resize-handle bottom-right"></div>`;

  overlay.appendChild(el);
  setupInteraction(inst, el, overlay);
}

function selectInstance(id) {
  activeInstanceId = id;
  document.querySelectorAll('.sig-instance').forEach(el => el.classList.remove('active'));
  const el = document.getElementById(id); if (el) el.classList.add('active');
}

function setupInteraction(inst, el, overlay) {
  const delBtn = el.querySelector('.delete-btn');
  delBtn.onclick = e => { e.stopPropagation(); placedInstances = placedInstances.filter(i=>i.id!==inst.id); el.remove(); };

  // Dragging
  let dragging=false, sx=0, sy=0, sl=0, st=0;
  function startDrag(e) {
    dragging=true; sx=e.clientX; sy=e.clientY; sl=parseFloat(el.style.left)||0; st=parseFloat(el.style.top)||0;
    document.addEventListener('mousemove', onDrag); document.addEventListener('mouseup', endDrag);
    document.addEventListener('touchmove', onTouchDrag, {passive:false}); document.addEventListener('touchend', endDrag);
  }
  function onDrag(e) {
    if(!dragging) return;
    let nl = sl + (e.clientX-sx), nt = st + (e.clientY-sy);
    nl = Math.max(0, Math.min(nl, overlay.clientWidth - el.offsetWidth));
    nt = Math.max(0, Math.min(nt, overlay.clientHeight - el.offsetHeight));
    el.style.left = nl+'px'; el.style.top = nt+'px';
    inst.rx = nl / overlay.clientWidth; inst.ry = nt / overlay.clientHeight;
  }
  function onTouchDrag(e) { if(dragging) { onDrag(e.touches[0]); e.preventDefault(); } }
  function endDrag() { dragging=false; document.removeEventListener('mousemove',onDrag); document.removeEventListener('mouseup',endDrag); document.removeEventListener('touchmove',onTouchDrag); document.removeEventListener('touchend',endDrag); }

  el.addEventListener('mousedown', e => { if(e.target.classList.contains('resize-handle')||e.target.classList.contains('rotate-handle')||e.target.classList.contains('delete-btn')) return; selectInstance(inst.id); startDrag(e); });
  el.addEventListener('touchstart', e => { if(e.target.classList.contains('resize-handle')||e.target.classList.contains('rotate-handle')||e.target.classList.contains('delete-btn')) return; selectInstance(inst.id); startDrag(e.touches[0]); }, {passive:true});

  // Rotation logic
  const rotateHandle = el.querySelector('.rotate-handle');
  let rotating = false;
  let startAngle = 0;
  let startRotation = 0;

  function startRotate(e) {
    rotating = true;
    startRotation = inst.rotation || 0;

    const overlayRect = overlay.getBoundingClientRect();
    const centerX = overlayRect.left + (inst.rx + inst.rw / 2) * overlay.clientWidth;
    const centerY = overlayRect.top + (inst.ry + inst.rh / 2) * overlay.clientHeight;

    const clientX = e.clientX || e.touches[0].clientX;
    const clientY = e.clientY || e.touches[0].clientY;

    startAngle = Math.atan2(clientY - centerY, clientX - centerX);

    document.addEventListener('mousemove', onRotate);
    document.addEventListener('mouseup', endRotate);
    document.addEventListener('touchmove', onTouchRotate, {passive:false});
    document.addEventListener('touchend', endRotate);
  }

  function onRotate(e) {
    if (!rotating) return;

    const overlayRect = overlay.getBoundingClientRect();
    const centerX = overlayRect.left + (inst.rx + inst.rw / 2) * overlay.clientWidth;
    const centerY = overlayRect.top + (inst.ry + inst.rh / 2) * overlay.clientHeight;

    const clientX = e.clientX || (e.touches && e.touches[0] ? e.touches[0].clientX : 0);
    const clientY = e.clientY || (e.touches && e.touches[0] ? e.touches[0].clientY : 0);

    const currentAngle = Math.atan2(clientY - centerY, clientX - centerX);
    const deltaAngle = currentAngle - startAngle;

    let newRotation = startRotation + deltaAngle * (180 / Math.PI);

    // Snapping logic
    const snapThreshold = 5;
    const snapPoints = [0, 90, 180, 270, 360, -90, -180, -270];
    for (const snap of snapPoints) {
      if (Math.abs(newRotation - snap) < snapThreshold) {
        newRotation = snap;
        break;
      }
    }

    newRotation = (newRotation % 360 + 360) % 360;

    inst.rotation = newRotation;
    el.style.transform = `rotate(${newRotation}deg)`;
  }

  function onTouchRotate(e) { if(rotating) { onRotate(e.touches[0]); e.preventDefault(); } }
  function endRotate() { rotating=false; document.removeEventListener('mousemove', onRotate); document.removeEventListener('mouseup', endRotate); document.removeEventListener('touchmove', onTouchRotate); document.removeEventListener('touchend', endRotate); }

  rotateHandle.addEventListener('mousedown', e => { e.stopPropagation(); startRotate(e); });
  rotateHandle.addEventListener('touchstart', e => { e.stopPropagation(); startRotate(e.touches[0]); }, {passive:true});

  // Resizing logic
  el.querySelectorAll('.resize-handle').forEach(handle => {
    let resizing=false, rtype='', rsx=0, rsy=0, rsw=0, rsh=0, rsl=0, rst=0;
    function startResize(e) {
      resizing=true; rsx=e.clientX; rsy=e.clientY; rsw=el.offsetWidth; rsh=el.offsetHeight; rsl=parseFloat(el.style.left)||0; rst=parseFloat(el.style.top)||0;
      if(handle.classList.contains('bottom-right')) rtype='br'; else if(handle.classList.contains('bottom-left')) rtype='bl';
      else if(handle.classList.contains('top-right')) rtype='tr'; else rtype='tl';
      document.addEventListener('mousemove', onResize); document.addEventListener('mouseup', endResize);
      document.addEventListener('touchmove', onTouchResize, {passive:false}); document.addEventListener('touchend', endResize);
    }
    function onResize(e) {
      if(!resizing) return;
      const dx=e.clientX-rsx, asp=inst.aspectRatio;
      let nw=rsw, nh=rsh, nl=rsl, nt=rst;
      if(rtype==='br') { nw=rsw+dx; nh=nw/asp; }
      else if(rtype==='bl') { nw=rsw-dx; nh=nw/asp; nl=rsl+(rsw-nw); }
      else if(rtype==='tr') { nw=rsw+dx; nh=nw/asp; nt=rst-(nh-rsh); }
      else { nw=rsw-dx; nh=nw/asp; nl=rsl+(rsw-nw); nt=rst-(nh-rsh); }
      if(nw<25) return;
      if(nl<0||nt<0||nl+nw>overlay.clientWidth||nt+nh>overlay.clientHeight) return;
      el.style.width=nw+'px'; el.style.height=nh+'px'; el.style.left=nl+'px'; el.style.top=nt+'px';
      inst.rx=nl/overlay.clientWidth; inst.ry=nt/overlay.clientHeight; inst.rw=nw/overlay.clientWidth; inst.rh=nh/overlay.clientHeight;
    }
    function onTouchResize(e) { if(resizing){onResize(e.touches[0]); e.preventDefault();} }
    function endResize() { resizing=false; document.removeEventListener('mousemove',onResize); document.removeEventListener('mouseup',endResize); document.removeEventListener('touchmove',onTouchResize); document.removeEventListener('touchend',endResize); }
    handle.addEventListener('mousedown', e => { e.stopPropagation(); startResize(e); });
    handle.addEventListener('touchstart', e => { e.stopPropagation(); startResize(e.touches[0]); }, {passive:true});
  });
}

// ==================== Download Signed PDF ====================
document.getElementById('download-pdf').onclick = async () => {
  if (!pdfBytes) return;
  const btn = document.getElementById('download-pdf');
  const origText = btn.innerHTML; btn.disabled = true; btn.innerHTML = translations[currentLanguage].creatingFile;

  try {
    const pdfDoc = await PDFLib.PDFDocument.load(pdfBytes);
    const pages = pdfDoc.getPages();

    for (const inst of placedInstances) {
      const page = pages[inst.pageIndex];
      let imgDataUrl = inst.imgData;
      if (imgDataUrl.startsWith("data:image/webp")) imgDataUrl = await convertWebpToPng(imgDataUrl);
      const imgBytes = await fetch(imgDataUrl).then(r => r.arrayBuffer());
      const pngImage = await pdfDoc.embedPng(imgBytes);
      const { width: pW, height: pH } = page.getSize();

      const w = inst.rw * pW;
      const h = inst.rh * pH;
      const x_user = inst.rx * pW;
      const y_user = pH - (inst.ry * pH) - h;

      const rad = -inst.rotation * Math.PI / 180;
      const x = x_user + w/2 - (w/2) * Math.cos(rad) + (h/2) * Math.sin(rad);
      const y = y_user + h/2 - (w/2) * Math.sin(rad) - (h/2) * Math.cos(rad);

      page.drawImage(pngImage, { 
        x, 
        y, 
        width: w, 
        height: h,
        rotate: PDFLib.degrees(-inst.rotation)
      });
    }

    const modBytes = await pdfDoc.save();
    let outName = pdfFileName;
    if (outName.toLowerCase().endsWith('.pdf')) outName = outName.slice(0,-4) + "_signed.pdf";
    else outName += "_signed.pdf";

    if (window.FlutterJustSign) {
      let binary = '';
      const len = modBytes.byteLength;
      for (let i = 0; i < len; i++) {
        binary += String.fromCharCode(modBytes[i]);
      }
      const base64 = window.btoa(binary);
      window.FlutterJustSign.postMessage(JSON.stringify({
        action: 'share',
        fileName: outName,
        data: base64
      }));
    } else {
      const blob = new Blob([modBytes], { type: "application/pdf" });
      const a = document.createElement("a"); a.href = URL.createObjectURL(blob);
      a.download = outName; a.click();
      setTimeout(() => URL.revokeObjectURL(a.href), 500);
    }
  } catch (err) {
    console.error("Error signing PDF:", err);
    alert(translations[currentLanguage].signingError);
  } finally {
    btn.disabled = false; btn.innerHTML = origText;
  }
};

// Prevent native browser pinch-to-zoom and gesture-zoom on mobile devices
document.addEventListener('touchstart', (e) => {
  if (e.touches.length > 1) {
    e.preventDefault();
  }
}, { passive: false });

document.addEventListener('gesturestart', (e) => {
  e.preventDefault();
});

