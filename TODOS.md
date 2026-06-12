# Backlog and TODOs

- [ ] **Cross-Device Cloud Sync for Signatures**
  - **Why:** Enable users to access their scanned/drawn signatures and stamps on both the Chrome Extension and the Flutter Mobile App seamlessly.
  - **Pros:** High user convenience; scanning a signature on a phone instantly makes it available for signing on a laptop.
  - **Cons:** Adds server, authentication, and privacy compliance overhead.
  - **Context:** Currently, storage is siloed: Chrome Extension uses `chrome.storage.sync` (limited to Chrome profiles), and the Flutter app uses native storage. To sync, we should integrate a lightweight, secure cloud storage layer (e.g., Firebase, Supabase, or private WebDAV/Nextcloud).
  - **Depends on:** Core mobile app and extension MVP release.
