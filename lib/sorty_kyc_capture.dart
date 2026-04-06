/// Sorty KYC Capture — Internal package.
///
/// Entry point: [KycFlowScreen]
/// Returns: [KycResult] with idFront, idBack, selfie as compressed Files.
library sorty_kyc_capture;

export 'src/kyc_flow_screen.dart';
export 'src/models/kyc_result.dart';
export 'src/screens/id_capture_screen.dart';
export 'src/screens/selfie_capture_screen.dart';
export 'src/utils/image_compressor.dart';
export 'src/utils/permission_manager.dart';
