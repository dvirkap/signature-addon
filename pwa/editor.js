// ============================================================
// פשוט לחתום - Just sign - PWA Core Logic
// Dynamic bilingual (HE/EN) rendering, scrolling, touch rotation & resize.
// ============================================================

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

    themeChalkboard: "Classroom Chalkboard",
    themeDark: "Sleek Dark",
    dropZoneHeader: "Drag and drop PDF file here",
    dropZoneSub: "or click \"Load PDF\" in the top bar",
    langLabel: "Language:",
    exportSigs: "📤 Export Backup",
    importSigs: "📥 Import Backup",
    confirmImport: "Are you sure you want to import signatures from this file? Existing signatures with identical IDs will be overwritten.",
    importSuccess: "Signatures imported successfully!",
    importError: "Import failed! Verify the backup file format is correct."
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
  initPwaMenu();

  const params = new URLSearchParams(window.location.search);
  const pdfUrl = params.get('file');
  if (pdfUrl) loadPdfFromUrl(pdfUrl);
});

async function loadPdfJs() {
  pdfjsLib = window.pdfjsLib;
  pdfjsLib.GlobalWorkerOptions.workerSrc = 'libs/pdf.worker.min.js';
}
// ==================== Languages ====================
function initLanguages() {
  const select = document.getElementById('lang-select');
  if (!select) return;
  select.innerHTML = '';
  
  // Hebrew and English first
  const topCodes = ['he', 'en'];
  const otherCodes = Object.keys(appSupportedLanguages)
    .filter(code => !topCodes.includes(code));
    
  otherCodes.sort((a, b) => {
    const nameA = appSupportedLanguages[a] || '';
    const nameB = appSupportedLanguages[b] || '';
    return nameA.localeCompare(nameB);
  });
  
  const allCodes = [...topCodes, ...otherCodes];
  allCodes.forEach(code => {
    const opt = document.createElement('option');
    opt.value = code;
    opt.textContent = appSupportedLanguages[code] || code;
    select.appendChild(opt);
  });

  select.onchange = (e) => {
    const lang = e.target.value;
    currentLanguage = lang;
    localStorage.setItem('selected_lang', lang);
    applyLanguage(lang);
  };
  const savedLang = localStorage.getItem('selected_lang') || 'he';
  currentLanguage = savedLang;
  select.value = savedLang;
  applyLanguage(savedLang);
}

function applyLanguage(lang) {
  // Toggle layout direction
  document.documentElement.dir = lang === 'he' ? 'rtl' : 'ltr';
  document.documentElement.lang = lang;

  // Update translatable elements
  document.querySelectorAll('[data-i18n]').forEach(el => {
    const key = el.getAttribute('data-i18n');
    if (translations[lang] && translations[lang][key]) {
      if (translations[lang][key].includes('<strong') || translations[lang][key].includes('<input')) {
        el.innerHTML = translations[lang][key];
      } else {
        el.textContent = translations[lang][key];
      }
    }
  });

  // Update translatable placeholders
  document.querySelectorAll('[data-i18n-placeholder]').forEach(el => {
    const key = el.getAttribute('data-i18n-placeholder');
    if (translations[lang] && translations[lang][key]) {
      el.placeholder = translations[lang][key];
    }
  });

  loadSavedSignatures();
  updatePageLabel();
}

function updatePageLabel() {
  const container = document.getElementById('page-num-container-label');
  if (!container) return;
  const pageIdx = getMostVisiblePage();
  if (pdfjsDoc) {
    container.innerHTML = translations[currentLanguage].pageOf
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
    localStorage.setItem('selected_theme', t);
  };
  const t = localStorage.getItem('selected_theme') || 'light';
  select.value = t;
  document.body.className = 'theme-' + t;
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

// ==================== PWA Mobile Drawer Toggle ====================
function initPwaMenu() {
  const menuToggle = document.getElementById('menu-toggle');
  const sidebar = document.getElementById('sidebar');
  const overlay = document.getElementById('sidebar-overlay');

  if (menuToggle && sidebar && overlay) {
    const toggle = () => {
      sidebar.classList.toggle('active');
      overlay.classList.toggle('active');
    };
    const close = () => {
      sidebar.classList.remove('active');
      overlay.classList.remove('active');
    };
    menuToggle.onclick = toggle;
    overlay.onclick = close;

    // Auto close menu drawer when picking a signature or changing tab on mobile
    document.addEventListener('click', (e) => {
      if (window.innerWidth <= 768) {
        if (e.target.closest('.sig-card') || e.target.closest('.sub-tab-btn')) {
          close();
        }
      }
    });
  }
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
  if (r.width > 0) {
    drawCanvas.width = r.width;
  }
  drawCanvas.height = 150;
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
  // Compress as WebP with 0.4 quality (supports transparency, small file size)
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
    const defaultName = currentLanguage === 'he' ? "חתימה מצוירת" : "Drawn Signature";
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
    const fallbackText = currentLanguage === 'he' ? "החתימה שלי" : "My Signature";
    const t = typeInput.value.trim() || fallbackText; 
    document.querySelectorAll('.font-preview-card .preview-text').forEach(el => { el.textContent=t; el.style.color=selectedTypeColor; }); 
  }
  document.querySelectorAll('.font-preview-card').forEach(card => {
    card.onclick = () => { document.querySelectorAll('.font-preview-card').forEach(c=>c.classList.remove('active')); card.classList.add('active'); selectedFontFamily=card.dataset.font; };
  });
  document.getElementById('btn-save-type').onclick = async () => {
    const text = typeInput.value.trim(); if (!text) { alert(currentLanguage==='he'?"אנא הקלד טקסט לחתימה!":"Please type text!"); return; }
    const defaultName = currentLanguage === 'he' ? "חתימה מוקלדת" : "Typed Signature";
    const name = document.getElementById('type-name').value.trim() || defaultName;
    const tc = document.createElement('canvas'); tc.width=600; tc.height=150; const tctx=tc.getContext('2d');
    tctx.font = `64px '${selectedFontFamily}', cursive`; tctx.fillStyle = selectedTypeColor; tctx.textBaseline='middle'; tctx.textAlign='center';
    tctx.fillText(text, 300, 75);
    await saveSignatureToStorage({ id:"sig_"+Date.now(), name, imgData: compressSignature(cropCanvas(tc)), type:"text", text: text, color: selectedTypeColor, font: selectedFontFamily });
    typeInput.value=""; document.getElementById('type-name').value=""; document.getElementById('tab-my-signatures').click();
  };

  // Upload image
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
    const defaultName = currentLanguage === 'he' ? "חתימה שהועלתה" : "Uploaded Signature";
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
    const listJson = localStorage.getItem('signature_list');
    const list = listJson ? JSON.parse(listJson) : [];

    if (list.length >= 15) {
      alert(translations[currentLanguage].maxQuota);
      return;
    }

    const newEntry = {
      id: sig.id,
      name: sig.name,
      type: sig.type
    };

    if (sig.type === "text") {
      newEntry.text = sig.text;
      newEntry.color = sig.color;
      newEntry.font = sig.font;
    } else {
      localStorage.setItem('sigdata_' + sig.id, JSON.stringify(sig.imgData));
    }

    list.push(newEntry);
    localStorage.setItem('signature_list', JSON.stringify(list));

    loadSavedSignatures();
  } catch (e) {
    console.error("Storage save error:", e);
    alert(currentLanguage === 'he' ? "שגיאה בשמירת החתימה." : "Error saving signature.");
  }
}

async function loadSavedSignatures() {
  const container = document.getElementById('signatures-list');
  if (!container) return;
  container.innerHTML = '';

  const listJson = localStorage.getItem('signature_list');
  const list = listJson ? JSON.parse(listJson) : [];
  savedSignatures = list;

  if (!list.length) {
    container.innerHTML = `<div class="empty-state">${translations[currentLanguage].emptyState}</div>`;
    return;
  }

  for (const sig of list) {
    let imgData = null;

    if (sig.type === "text") {
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
      const dataJson = localStorage.getItem('sigdata_' + sig.id);
      imgData = dataJson ? JSON.parse(dataJson) : null;
      sig.imgData = imgData;
    }

    if (!imgData) continue;

    const card = document.createElement('div');
    card.className = 'sig-card';
    card.innerHTML = `
      <div class="sig-card-img-wrapper"><img src="${imgData}" alt="${sig.name}"></div>
      <div class="sig-card-info">
        <span class="sig-card-name">${sig.name}</span>
        <button class="sig-card-delete" data-id="${sig.id}">🗑️</button>
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
    const listJson = localStorage.getItem('signature_list');
    if (listJson) {
      const list = JSON.parse(listJson);
      const newList = list.filter(s => s.id !== id);
      localStorage.setItem('signature_list', JSON.stringify(newList));
    }
    localStorage.removeItem('sigdata_' + id);
    loadSavedSignatures();
  } catch (e) {
    console.error("Delete signature error:", e);
  }
}

// ==================== Local backup Import / Export ====================
document.getElementById('btn-export-sigs').onclick = () => {
  const exportData = {
    signature_list: savedSignatures,
    sigdata: {}
  };
  
  savedSignatures.forEach(sig => {
    if (sig.type !== "text") {
      const data = localStorage.getItem('sigdata_' + sig.id);
      if (data) exportData.sigdata[sig.id] = JSON.parse(data);
    }
  });

  const blob = new Blob([JSON.stringify(exportData, null, 2)], { type: "application/json" });
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = `just_sign_signatures_${Date.now()}.json`;
  a.click();
  setTimeout(() => URL.revokeObjectURL(a.href), 500);
};

document.getElementById('btn-import-sigs').onclick = () => {
  document.getElementById('import-sigs-input').click();
};

document.getElementById('import-sigs-input').onchange = (e) => {
  const file = e.target.files[0];
  if (!file) return;

  const reader = new FileReader();
  reader.onload = async (evt) => {
    try {
      const importData = JSON.parse(evt.target.result);
      if (!importData.signature_list || !Array.isArray(importData.signature_list)) {
        throw new Error("Invalid format");
      }

      if (confirm(translations[currentLanguage].confirmImport)) {
        const listJson = localStorage.getItem('signature_list');
        const list = listJson ? JSON.parse(listJson) : [];
        
        importData.signature_list.forEach(newSig => {
          const idx = list.findIndex(item => item.id === newSig.id);
          if (idx !== -1) {
            list[idx] = newSig;
          } else {
            list.push(newSig);
          }
          
          if (importData.sigdata && importData.sigdata[newSig.id]) {
            localStorage.setItem('sigdata_' + newSig.id, JSON.stringify(importData.sigdata[newSig.id]));
          }
        });
        
        localStorage.setItem('signature_list', JSON.stringify(list));
        alert(translations[currentLanguage].importSuccess);
        loadSavedSignatures();
      }
    } catch (err) {
      console.error(err);
      alert(translations[currentLanguage].importError);
    }
    e.target.value = '';
  };
  reader.readAsText(file);
};
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
  container.innerHTML = '';

  try {
    pdfjsDoc = await pdfjsLib.getDocument({
      data: pdfBytes.slice(0),
      cMapUrl: 'https://cdn.jsdelivr.net/npm/pdfjs-dist@3.11.174/cmaps/',
      cMapPacked: true,
      standardFontDataUrl: 'libs/standard_fonts/',
      disableFontFace: true
    }).promise;

    totalPagesCount = pdfjsDoc.numPages;
    updatePageLabel();

    const pdfLibDoc = await PDFLib.PDFDocument.load(pdfBytes.slice(0));
    for (let i = 0; i < pdfLibDoc.getPageCount(); i++) {
      const pg = pdfLibDoc.getPage(i);
      const { width, height } = pg.getSize();
      pageDimensions.push({ width, height });
    }

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

  const pageContainer = document.createElement('div');
  pageContainer.className = 'page-container';
  pageContainer.id = `page-container-${pageIdx}`;
  pageContainer.dataset.pageIndex = pageIdx;

  const label = document.createElement('div');
  label.className = 'page-number-label';
  label.textContent = currentLanguage === 'he' ? `עמוד ${pageNum} מתוך ${totalPagesCount}` : `Page ${pageNum} of ${totalPagesCount}`;
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
  img.alt = `עמוד ${pageNum}`;
  renderArea.appendChild(img);

  const overlay = document.createElement('div');
  overlay.id = `signature-overlay-${pageIdx}`;
  overlay.className = 'signature-overlay';
  overlay.dataset.pageIndex = pageIdx;
  renderArea.appendChild(overlay);

  pageContainer.appendChild(renderArea);
  container.appendChild(pageContainer);

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

  img.src = canvas.toDataURL('image/png');

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

  el.innerHTML = `<img src="${inst.imgData}" draggable="false"><button class="delete-btn" title="${translations[currentLanguage].deleteTooltip}">×</button>
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
// ==================== Touch/Pointer Interactions & Export compilation ====================
function setupInteraction(inst, el, overlay) {
  const delBtn = el.querySelector('.delete-btn');
  delBtn.onpointerdown = e => e.stopPropagation();
  delBtn.onclick = e => { e.stopPropagation(); placedInstances = placedInstances.filter(i=>i.id!==inst.id); el.remove(); };

  // ================= DRAG LOGIC =================
  let dragStartPointer = null;
  let dragStartPos = { left: 0, top: 0 };

  el.onpointerdown = e => {
    if (e.target.classList.contains('resize-handle') || e.target.classList.contains('rotate-handle') || e.target.classList.contains('delete-btn')) return;
    e.stopPropagation();
    selectInstance(inst.id);
    el.setPointerCapture(e.pointerId);
    dragStartPointer = { x: e.clientX, y: e.clientY };
    dragStartPos = { left: parseFloat(el.style.left)||0, top: parseFloat(el.style.top)||0 };
  };

  el.onpointermove = e => {
    if (!dragStartPointer) return;
    e.stopPropagation();
    const dx = e.clientX - dragStartPointer.x;
    const dy = e.clientY - dragStartPointer.y;
    let nl = dragStartPos.left + dx;
    let nt = dragStartPos.top + dy;
    nl = Math.max(0, Math.min(nl, overlay.clientWidth - el.offsetWidth));
    nt = Math.max(0, Math.min(nt, overlay.clientHeight - el.offsetHeight));
    el.style.left = nl + 'px';
    el.style.top = nt + 'px';
    inst.rx = nl / overlay.clientWidth;
    inst.ry = nt / overlay.clientHeight;
  };

  el.onpointerup = el.onpointercancel = e => {
    if (dragStartPointer) {
      el.releasePointerCapture(e.pointerId);
      dragStartPointer = null;
    }
  };

  // ================= ROTATION LOGIC =================
  const rotateHandle = el.querySelector('.rotate-handle');
  let rotateStartPointer = null;
  let rotateStartAngle = 0;
  let rotateStartRotation = 0;

  rotateHandle.onpointerdown = e => {
    e.stopPropagation();
    rotateHandle.setPointerCapture(e.pointerId);
    rotateStartRotation = inst.rotation || 0;
    
    const rect = overlay.getBoundingClientRect();
    const centerX = rect.left + (inst.rx + inst.rw / 2) * overlay.clientWidth;
    const centerY = rect.top + (inst.ry + inst.rh / 2) * overlay.clientHeight;
    
    rotateStartAngle = Math.atan2(e.clientY - centerY, e.clientX - centerX);
    rotateStartPointer = true;
  };

  rotateHandle.onpointermove = e => {
    if (!rotateStartPointer) return;
    e.stopPropagation();
    const rect = overlay.getBoundingClientRect();
    const centerX = rect.left + (inst.rx + inst.rw / 2) * overlay.clientWidth;
    const centerY = rect.top + (inst.ry + inst.rh / 2) * overlay.clientHeight;
    
    const currentAngle = Math.atan2(e.clientY - centerY, e.clientX - centerX);
    const deltaAngle = currentAngle - rotateStartAngle;
    let newRotation = rotateStartRotation + deltaAngle * (180 / Math.PI);

    const snapThreshold = 6;
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
  };

  rotateHandle.onpointerup = rotateHandle.onpointercancel = e => {
    if (rotateStartPointer) {
      rotateHandle.releasePointerCapture(e.pointerId);
      rotateStartPointer = null;
    }
  };

  // ================= RESIZING LOGIC =================
  el.querySelectorAll('.resize-handle').forEach(handle => {
    let resizeStartPointer = null;
    let resizeStartLayout = { left: 0, top: 0, width: 0, height: 0 };
    let rtype = '';

    handle.onpointerdown = e => {
      e.stopPropagation();
      handle.setPointerCapture(e.pointerId);
      resizeStartPointer = { x: e.clientX, y: e.clientY };
      resizeStartLayout = {
        left: parseFloat(el.style.left)||0,
        top: parseFloat(el.style.top)||0,
        width: el.offsetWidth,
        height: el.offsetHeight
      };
      
      if (handle.classList.contains('bottom-right')) rtype = 'br';
      else if (handle.classList.contains('bottom-left')) rtype = 'bl';
      else if (handle.classList.contains('top-right')) rtype = 'tr';
      else rtype = 'tl';
    };

    handle.onpointermove = e => {
      if (!resizeStartPointer) return;
      e.stopPropagation();
      const dx = e.clientX - resizeStartPointer.x;
      const asp = inst.aspectRatio;
      
      let nw = resizeStartLayout.width;
      let nh = resizeStartLayout.height;
      let nl = resizeStartLayout.left;
      let nt = resizeStartLayout.top;

      if (rtype === 'br') {
        nw = resizeStartLayout.width + dx;
        nh = nw / asp;
      } else if (rtype === 'bl') {
        nw = resizeStartLayout.width - dx;
        nh = nw / asp;
        nl = resizeStartLayout.left + (resizeStartLayout.width - nw);
      } else if (rtype === 'tr') {
        nw = resizeStartLayout.width + dx;
        nh = nw / asp;
        nt = resizeStartLayout.top - (nh - resizeStartLayout.height);
      } else { // tl
        nw = resizeStartLayout.width - dx;
        nh = nw / asp;
        nl = resizeStartLayout.left + (resizeStartLayout.width - nw);
        nt = resizeStartLayout.top - (nh - resizeStartLayout.height);
      }

      if (nw < 25) return;
      if (nl < 0 || nt < 0 || nl + nw > overlay.clientWidth || nt + nh > overlay.clientHeight) return;

      el.style.width = nw + 'px';
      el.style.height = nh + 'px';
      el.style.left = nl + 'px';
      el.style.top = nt + 'px';

      inst.rx = nl / overlay.clientWidth;
      inst.ry = nt / overlay.clientHeight;
      inst.rw = nw / overlay.clientWidth;
      inst.rh = nh / overlay.clientHeight;
    };

    handle.onpointerup = handle.onpointercancel = e => {
      if (resizeStartPointer) {
        handle.releasePointerCapture(e.pointerId);
        resizeStartPointer = null;
      }
    };
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
    const blob = new Blob([modBytes], { type: "application/pdf" });
    const a = document.createElement("a"); a.href = URL.createObjectURL(blob);
    let outName = pdfFileName;
    if (outName.toLowerCase().endsWith('.pdf')) outName = outName.slice(0,-4) + "_signed.pdf";
    else outName += "_signed.pdf";
    a.download = outName; a.click();
    setTimeout(() => URL.revokeObjectURL(a.href), 500);
  } catch (err) {
    console.error("Error signing PDF:", err);
    alert(translations[currentLanguage].signingError);
  } finally {
    btn.disabled = false; btn.innerHTML = origText;
  }
};

// ==================== Android/PWA Launch Queue Handler (Open With integration) ====================
if ('launchQueue' in window) {
  window.launchQueue.setConsumer(async (launchParams) => {
    try {
      if (launchParams.files && launchParams.files.length > 0) {
        const fileHandle = launchParams.files[0];
        const file = await fileHandle.getFile();
        loadPdfFile(file);
      }
    } catch (err) {
      console.error("Error handling launch file:", err);
    }
  });
}

// Prevent native browser pinch-to-zoom and gesture-zoom on mobile devices
document.addEventListener('touchstart', (e) => {
  if (e.touches.length > 1) {
    e.preventDefault();
  }
}, { passive: false });

document.addEventListener('gesturestart', (e) => {
  e.preventDefault();
});

