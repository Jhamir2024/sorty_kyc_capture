# Native Setup — sorty_kyc_capture

## Android — `android/app/src/main/AndroidManifest.xml`

```xml
<uses-permission android:name="android.permission.CAMERA" />
```

En `android/app/build.gradle`, asegúrate de:
```groovy
android {
    defaultConfig {
        minSdkVersion 21   // requerido por camera + mlkit
    }
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }
}
```

Para `flutter_image_compress` en Android agrega en `android/app/proguard-rules.pro`:
```
-keep class com.tencent.mmkv.** { *; }
```

## iOS — `ios/Runner/Info.plist`

```xml
<key>NSCameraUsageDescription</key>
<string>Sorty necesita acceso a la cámara para verificar tu identidad (KYC).</string>
```

En `ios/Podfile` asegúrate de:
```ruby
platform :ios, '14.0'   # mínimo para google_mlkit_face_detection
```

## Consumo del paquete en el proyecto raíz

En `sorty/mobile/pubspec.yaml`:
```yaml
dependencies:
  sorty_kyc_capture:
    path: ../packages/sorty_kyc_capture
```

## Uso típico

```dart
import 'package:sorty_kyc_capture/sorty_kyc_capture.dart';

Navigator.of(context).push(MaterialPageRoute(
  builder: (_) => KycFlowScreen(
    onComplete: (KycResult result) async {
      // result.idFront, result.idBack, result.selfie son File JPEG ≤ 800 KB
      // Subir a S3 / enviar a tu API con AWS Rekognition
      await uploadToS3(result.idFront, key: 'kyc/${userId}/id_front.jpg');
      await uploadToS3(result.idBack,  key: 'kyc/${userId}/id_back.jpg');
      await uploadToS3(result.selfie,  key: 'kyc/${userId}/selfie.jpg');

      // Liberar archivos temporales
      await result.dispose();

      Navigator.of(context).pop();
    },
    onCancel: () => Navigator.of(context).pop(),
  ),
));
```
