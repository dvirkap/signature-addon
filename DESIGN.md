# Design System & Interface Guidelines

This document defines the design tokens, typography, responsive breakpoints, layout conventions, and touch ergonomics for **פשוט לחתום - Just Sign** (hybrid Flutter app and Chrome Extension).

## 1. Color System (Themes)

Colors are managed via CSS variables under four semantic themes.

### Light Theme (`.theme-light`)
- **Background (Dark):** `#f8fafc` (Soft gray-blue)
- **Background (Panel):** `#ffffff` (Pure white)
- **Primary Text:** `#0f172a` (Slate 900)
- **Secondary Text:** `#475569` (Slate 600)
- **Border Color:** `#e2e8f0` (Slate 200)
- **Input Background:** `#f1f5f9` (Slate 100)
- **Accent Color:** `#4f46e5` (Indigo 600)
- **Accent Hover:** `#4338ca` (Indigo 700)
- **Success Color:** `#10b981` (Emerald)
- **Error Color:** `#ef4444` (Rose)

### Warm Theme (`.theme-warm`)
- **Background (Dark):** `#fbfbf8` (Soft warm paper ivory)
- **Background (Panel):** `#fcfcf9` (Warm white)
- **Primary Text:** `#2e2a25` (Dark charcoal brown)
- **Secondary Text:** `#5e5950` (Muted brown)
- **Border Color:** `#e9e6dc` (Warm gray)
- **Input Background:** `#f5f2ea` (Warm ivory)
- **Accent Color:** `#b45309` (Amber 700)
- **Accent Hover:** `#92400e` (Amber 800)

### Chalkboard Theme (`.theme-chalkboard`)
- **Background (Dark):** `#1b2824` (Dark forest/slate chalkboard)
- **Background (Panel):** `#0f1816` (Deep charcoal chalkboard)
- **Primary Text:** `#e6f1ed` (Pastel green-white)
- **Secondary Text:** `#b5c8c1` (Brightened muted chalk green - *WCAG 2.1 AA Compliant, contrast > 4.5:1*)
- **Border Color:** `#2b3d38` (Border green)
- **Input Background:** `#1b2824` (Chalkboard slate)
- **Accent Color:** `#10b981` (Chalk mint green)
- **Accent Hover:** `#059669` (Emerald green)

### Dark Theme (`.theme-dark`)
- **Background (Dark):** `#0f172a` (Deep slate dark background)
- **Background (Panel):** `#1e293b` (Dark slate panel)
- **Primary Text:** `#f8fafc` (White)
- **Secondary Text:** `#94a3b8` (Gray-blue slate)
- **Border Color:** `#334155` (Slate border)
- **Input Background:** `#0f172a` (Input slate)
- **Accent Color:** `#38bdf8` (Sky blue)
- **Accent Hover:** `#0ea5e9` (Light blue)

---

## 2. Typography

We use modern typography optimized for readability and scanning.

- **Primary Font Family:** `'Assistant', sans-serif` (Excellent Hebrew & Latin legibility).
- **Scale:**
  - **Large Titles (`h1`):** `24px` / Semibold / tracking `-0.5px`
  - **Section Titles (`h2`):** `18px` / Bold
  - **Body Text:** `16px` / Regular (Never use body text < 16px to prevent zoom on focus and preserve accessibility).
  - **Muted Labels:** `14px` / Semibold

---

## 3. Responsive Breakpoints & Mobile Layout

To support the hybrid nature of the app (Chrome Extension, Mobile WebView, PWA), layout structures adapt automatically.

| Device Viewport | Sidebar | Navigation Toolbar | Bottom Drawer |
|-----------------|---------|--------------------|---------------|
| **Desktop / Tablet (`>= 768px`)** | Visible | Top Bar Navigation | Embedded |
| **Mobile (`< 768px`)** | Hidden | 56px Bottom Navigation Bar | Slide-Up Drawer |

### Bottom Navigation Toolbar (Mobile-first)
- **Height:** `56px`
- **Position:** Fixed bottom
- **Actions:** Load Document, Signatures (Drawer toggle), Scan Stamp, Export Document.

### Slide-Up Bottom Drawer
- Holds saved signatures and stamps.
- Employs a quick-swipe slide gesture to open/close.

---

## 4. Touch Ergonomics & Gestures

Mobile interaction is critical for document signing. We enforce the following physical constraints:

### Touch Targets
- **Interactive Buttons:** Minimum height of `44px` (Apple/Android accessibility guidelines).
- **Resize Handles (Stamps):** Enforce `44x44px` touch targets using transparent padding. The user sees a small `8x8px` handle circle, but the touch zone extends to `44x44px` to avoid missing targets.
- **Rotate Handle (Stamps):** Positioned at the top of the selected stamp, utilizing a similar `44x44px` touch area.

### Gestures & Collision Bounds
- **Pinch-to-Zoom:** Allowed on the document canvas at any time.
- **Active Stamp Dragging:** While dragging or resizing a signature/stamp, Pinch-to-Zoom is temporarily locked/suspended to prevent accidental page movement.
- **Page Boundary Lock:** Stamps cannot be dragged out of the active PDF page viewport boundaries. Drag coordinates are clamped within the active page.
- **Active Page Glow Highlight:** The active/under-drag page gets a subtle colored glow border to indicate where the stamp will land.

---

## 5. Performance & Mobile Optimization

- **Lazy Rendering:** To prevent Out-Of-Memory (OOM) crashes on low-end mobile devices, pages are rendered lazily via an `IntersectionObserver`. Pages only construct canvas render-loops when scrolling within `100px` of the viewport.
