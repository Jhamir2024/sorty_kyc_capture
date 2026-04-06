## 0.1.0

* Initial release.
* Document capture screen with ID-card overlay (ISO/IEC 7810 ratio).
* Selfie capture with real-time liveness detection via ML Kit (smile + blink).
* Automatic JPEG compression to ≤ 800 KB with EXIF stripping.
* Camera permission gate widget with retry and system settings fallback.
* Returns structured `KycResult(idFront, idBack, selfie)`.
