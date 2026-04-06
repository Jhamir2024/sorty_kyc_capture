# sorty_kyc_capture

A Flutter package that provides the full UX flow for **KYC (Know Your Customer)** identity verification — including document capture, liveness selfie detection, and automatic image compression — ready to integrate with AWS Rekognition or any face-matching backend.

## Features

- **Document capture** — Full-screen camera with an ID-card shaped overlay (ISO/IEC 7810 ratio) and alignment guides.
- **Liveness selfie** — Front camera with real-time face detection via `google_mlkit_face_detection`. Capture is only enabled when exactly one face is detected AND the user smiles (probability > 0.7) or blinks, preventing photo spoofing.
- **Auto image compression** — All captured images are compressed to JPEG ≤ 800 KB using `flutter_image_compress`, ideal for S3 uploads or REST APIs.
- **Permission handling** — Built-in camera permission gate widget with retry and system settings fallback.
- **Structured result** — Returns a `KycResult(idFront, idBack, selfie)` with all three compressed `File` objects.

## Installation

```yaml
dependencies:
  sorty_kyc_capture: ^0.1.0
```

## Native setup

### Android — `AndroidManifest.xml`
```xml
<uses-permission android:name="android.permission.CAMERA" />
```
Set `minSdkVersion 21` in `android/app/build.gradle`.

### iOS — `Info.plist`
```xml
<key>NSCameraUsageDescription</key>
<string>Required for identity verification (KYC).</string>
```
Set `platform :ios, '14.0'` in your `Podfile`.

## Usage

```dart
import 'package:sorty_kyc_capture/sorty_kyc_capture.dart';

Navigator.of(context).push(MaterialPageRoute(
  builder: (_) => KycFlowScreen(
    onComplete: (KycResult result) async {
      // All files are JPEG, ≤ 800 KB, EXIF stripped
      print(result.idFront.path);  // compressed ID front
      print(result.idBack.path);   // compressed ID back
      print(result.selfie.path);   // liveness-verified selfie

      // Upload to your backend / S3, then:
      await result.dispose(); // deletes temp files
    },
    onCancel: () => Navigator.of(context).pop(),
  ),
));
```

## Flow

```
KycFlowScreen
  ├── Step 1 → IdCaptureScreen  ("Frente del documento")
  ├── Step 2 → IdCaptureScreen  ("Reverso del documento")
  └── Step 3 → SelfieCaptureScreen  (liveness required)
                    ↓
               KycResult(idFront, idBack, selfie)
```

## Liveness detection logic

| Signal | Threshold | Purpose |
|---|---|---|
| `smilingProbability` | > 0.70 | Active liveness (user must act) |
| `leftEyeOpenProbability` or `rightEyeOpenProbability` | < 0.25 | Passive liveness (blink detection) |
| Face count | == 1 | Prevents multi-face bypass |

Processing is throttled to one frame every 150 ms to avoid overloading mid-range devices.

## AWS Rekognition integration

Once you receive the `KycResult`, your backend should:

1. Upload the three files to a temporary S3 bucket.
2. Call `rekognition:CompareFaces(source=selfie, target=idFront)` — validate `Similarity >= 95`.
3. Call `rekognition:DetectText(image=idFront)` to extract document data (name, ID number, DOB).
4. Delete the S3 objects after verification.

## Dependencies

| Package | Purpose |
|---|---|
| `camera` | Full camera hardware control |
| `google_mlkit_face_detection` | On-device face & liveness detection |
| `flutter_image_compress` | JPEG compression |
| `permission_handler` | Runtime camera permission |
| `path_provider` | Temp directory for output files |

## License

MIT
