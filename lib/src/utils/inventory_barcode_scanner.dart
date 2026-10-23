import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Owns the camera controller used by inventory barcode entry points.
///
/// An empty formats list deliberately keeps every format supported by the
/// platform decoder, including QR codes and 1D inventory labels.
class InventoryBarcodeScanner with WidgetsBindingObserver {
  InventoryBarcodeScanner(this.flow)
      : controller = MobileScannerController(
          facing: CameraFacing.back,
          cameraResolution:
              !kIsWeb && defaultTargetPlatform == TargetPlatform.android
                  ? const Size(1920, 1080)
                  : null,
        ) {
    WidgetsBinding.instance.addObserver(this);
    controller.addListener(_logCameraState);
  }

  final String flow;
  final MobileScannerController controller;
  final Map<String, DateTime> _lastDetectionLogs = {};
  String? _lastCameraState;
  bool _isScannerVisible = false;
  bool _isDisposed = false;

  void setScannerVisible(bool visible) {
    _isScannerVisible = visible;
  }

  void logCapture(BarcodeCapture capture) {
    if (!kDebugMode) return;

    _logOncePerInterval(
      'callback',
      '[BarcodeScanner][$flow] detection callback fired '
          '(barcodes=${capture.barcodes.length})',
    );

    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue == null || rawValue.isEmpty) continue;

      _logOncePerInterval(
        '${barcode.format.name}:$rawValue',
        '[BarcodeScanner][$flow] decoded format=${barcode.format.name} '
            'rawValue=${_diagnosticValue(rawValue)}; '
            'camera=${controller.value.cameraDirection.name}',
      );
    }
  }

  void logLookup(String identifier) {
    if (kDebugMode) {
      debugPrint(
        '[BarcodeScanner][$flow] inventory lookup started '
        'identifier=${_diagnosticValue(identifier)}',
      );
    }
  }

  Widget buildError(BuildContext context, MobileScannerException error, _) {
    if (kDebugMode) {
      final details = error.errorDetails;
      _logOncePerInterval(
        'error:${error.errorCode.name}:${details?.code}',
        '[BarcodeScanner][$flow] camera error '
            'code=${error.errorCode.name} '
            'platformCode=${details?.code ?? 'n/a'}',
      );
    }

    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Camera unavailable. Check camera permission and try again.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }

  void _logCameraState() {
    if (!kDebugMode) return;

    final state = controller.value;
    final error = state.error;
    final signature = [
      state.isInitialized,
      state.isRunning,
      state.cameraDirection.name,
      state.availableCameras,
      error?.errorCode.name,
      error?.errorDetails?.code,
    ].join('|');
    if (signature == _lastCameraState) return;
    _lastCameraState = signature;

    debugPrint(
      '[BarcodeScanner][$flow] camera state '
      'initialized=${state.isInitialized} running=${state.isRunning} '
      'facing=${state.cameraDirection.name} '
      'availableCameras=${state.availableCameras ?? 'unknown'} '
      'error=${error?.errorCode.name ?? 'none'}',
    );
  }

  void _logOncePerInterval(String key, String message) {
    final now = DateTime.now();
    final lastLogged = _lastDetectionLogs[key];
    if (lastLogged != null &&
        now.difference(lastLogged) < const Duration(seconds: 5)) {
      return;
    }

    if (_lastDetectionLogs.length > 100) _lastDetectionLogs.clear();
    _lastDetectionLogs[key] = now;
    debugPrint(message);
  }

  String _diagnosticValue(String value) {
    final isSkuLike = RegExp(r'^[A-Z]{2}(?:-[A-Z0-9.]+)+$').hasMatch(value);
    return isSkuLike ? value : '<redacted length=${value.length}>';
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isScannerVisible || _isDisposed) return;

    switch (state) {
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        unawaited(_stopCamera());
        break;
      case AppLifecycleState.resumed:
        unawaited(_startCamera());
        break;
    }
  }

  Future<void> _stopCamera() async {
    try {
      await controller.stop();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[BarcodeScanner][$flow] camera stop failed: $error');
      }
    }
  }

  Future<void> _startCamera() async {
    try {
      await controller.start(cameraDirection: CameraFacing.back);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[BarcodeScanner][$flow] camera start failed: $error');
      }
    }
  }

  Future<void> dispose() async {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    controller.removeListener(_logCameraState);
    await _stopCamera();
    await controller.dispose();
  }
}
