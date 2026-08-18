import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/farm_record.dart';
import '../services/field_config_service.dart';

/// Live camera + on-device text recognition screen.
///
/// HOW THIS MEETS YOUR REQUIREMENT:
/// - Uses the device camera in a live preview (no photo file is ever saved
///   to disk), so there's no extra storage used per scan.
/// - Each camera frame is run through Google ML Kit's on-device text
///   recognizer. Recognized text is shown live, like a live caption.
/// - When text is detected, the user taps "Use this text" to lock it in,
///   edit it if needed, then continues to fill in the configured fields.
/// - Before saving, the user sees everything (tag number + all fields) on a
///   confirmation screen. Only after they confirm does it become a
///   FarmRecord that gets handed back to be saved to the database.
///
/// CHANGE FROM BEFORE: the "3 more fields" step used to be 3 hardcoded
/// TextFormFields (fieldOne/Two/Three). Now the fields shown are however
/// many labels an admin has configured in FieldConfigService — could be
/// 2, could be 6. See _RecordDetailsScreen below for how that works.
///
/// SETUP NOTE: ML Kit Text Recognition runs fully on-device — no internet
/// call, no per-scan cost, and nothing is uploaded. You'll need to add the
/// `camera` and `google_mlkit_text_recognition` packages (see pubspec.yaml
/// in the setup guide) and grant camera permission on the device.
class ScanScreen extends StatefulWidget {
  final String createdBy;

  const ScanScreen({super.key, required this.createdBy});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  CameraController? _cameraController;
  final TextRecognizer _textRecognizer = TextRecognizer();

  bool _isCameraReady = false;
  bool _isProcessingFrame = false;
  bool _isStreaming = true;
  bool _isFlashOn = false;
  String _liveDetectedText = '';
  DateTime _lastProcessed = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        backCamera,
        ResolutionPreset
            .medium, // medium is plenty for text and keeps frames light
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup
            .nv21, // forces single-plane NV21 output so ML Kit can read frames correctly
      );

      await controller.initialize();
      if (!mounted) return;

      setState(() {
        _cameraController = controller;
        _isCameraReady = true;
      });

      controller.startImageStream(_processCameraFrame);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera error: $e')),
      );
    }
  }

  Future<void> _processCameraFrame(CameraImage image) async {
    // Throttle so we are not running OCR on every single frame
    // (saves battery/CPU); roughly 2-3 times per second is plenty.
    final now = DateTime.now();
    if (_isProcessingFrame || !_isStreaming) return;
    if (now.difference(_lastProcessed) < const Duration(milliseconds: 400)) {
      return;
    }
    _lastProcessed = now;
    _isProcessingFrame = true;

    try {
      final inputImage = _convertToInputImage(image);
      if (inputImage != null) {
        final result = await _textRecognizer.processImage(inputImage);
        if (mounted) {
          setState(() => _liveDetectedText = result.text.trim());
        }
      }
    } catch (_) {
      // Silently ignore occasional frame conversion issues; next frame retries.
    } finally {
      _isProcessingFrame = false;
    }
  }

  InputImage? _convertToInputImage(CameraImage image) {
    final camera = _cameraController?.description;
    if (camera == null) return null;

    final rotation =
        InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
            InputImageRotation.rotation0deg;

    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat
            .nv21, // camera now always outputs nv21, so no need to detect
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  void _goToDetails(String tagNumber) {
    setState(() => _isStreaming = false);
    _cameraController?.stopImageStream();

    // Turn the flash off before leaving — it shouldn't stay lit while
    // the user is filling out the record details screen.
    if (_isFlashOn) {
      unawaited(_cameraController?.setFlashMode(FlashMode.off));
      setState(() => _isFlashOn = false);
    }

    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => RecordDetailsScreen(
          initialTagNumber: tagNumber,
          createdBy: widget.createdBy,
        ),
      ),
    )
        .then((result) {
      if (result != null && mounted) {
        Navigator.of(context).pop(result); // pass the saved record back to Home
      } else if (mounted) {
        // user backed out of details screen — resume scanning
        setState(() => _isStreaming = true);
        _cameraController?.startImageStream(_processCameraFrame);
      }
    });
  }

  void _useDetectedText() => _goToDetails(_liveDetectedText);

  void _enterManually() => _goToDetails('');

  Future<void> _toggleFlash() async {
    if (_cameraController == null || !_isCameraReady) return;
    try {
      final newMode = _isFlashOn ? FlashMode.off : FlashMode.torch;
      await _cameraController!.setFlashMode(newMode);
      setState(() => _isFlashOn = !_isFlashOn);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Flash error: $e')),
      );
    }
  }

  @override
  void dispose() {
    _cameraController?.setFlashMode(FlashMode.off);
    _cameraController?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Tag / Label'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: Icon(
              _isFlashOn ? Icons.flash_on : Icons.flash_off,
              color: _isFlashOn ? Colors.amber : Colors.white,
            ),
            tooltip: _isFlashOn ? 'Turn off flash' : 'Turn on flash',
            onPressed: _isCameraReady ? _toggleFlash : null,
          ),
        ],
      ),
      body: !_isCameraReady
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : Stack(
              children: [
                Positioned.fill(child: CameraPreview(_cameraController!)),
                // Dim overlay with a focus box, just to guide the user's aim
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: Container(
                        width: 280,
                        height: 120,
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: const Color.fromARGB(186, 102, 18, 15),
                              width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                      decoration: const BoxDecoration(
                        color: Colors.black87,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Detected text:',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _liveDetectedText.isEmpty
                                ? 'Point the camera at the tag or label...'
                                : _liveDetectedText,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 18),
                          ElevatedButton.icon(
                            onPressed: _liveDetectedText.isEmpty
                                ? null
                                : _useDetectedText,
                            icon: const Icon(Icons.check),
                            label: const Text('Use this text'),
                          ),
                          const SizedBox(height: 10),
                          TextButton.icon(
                            onPressed: _enterManually,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white70,
                            ),
                            icon: const Icon(Icons.keyboard),
                            label: const Text('Or Enter Manually'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Step 2: collect the configured fields + show a confirmation before saving.
///
/// CHANGE FROM BEFORE: instead of 3 fixed TextEditingControllers, we build
/// one controller PER LABEL in FieldConfigService.instance.fieldLabels.
/// If an admin adds/removes fields in the Tags Editor, this screen
/// automatically shows the right number of inputs next time it opens —
/// no code change needed.
class RecordDetailsScreen extends StatefulWidget {
  final String initialTagNumber;
  final String createdBy;

  const RecordDetailsScreen({
    super.key,
    required this.initialTagNumber,
    required this.createdBy,
  });

  @override
  State<RecordDetailsScreen> createState() => _RecordDetailsScreenState();
}

class _RecordDetailsScreenState extends State<RecordDetailsScreen> {
  late final TextEditingController _tagController =
      TextEditingController(text: widget.initialTagNumber);
  late final List<String> _fieldLabels =
      FieldConfigService.instance.fieldLabels;
  late final List<TextEditingController> _fieldControllers =
      _fieldLabels.map((_) => TextEditingController()).toList();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _tagController.dispose();
    for (final c in _fieldControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _showConfirmationAndSave() async {
    if (!_formKey.currentState!.validate()) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Record'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ConfirmRow(label: 'Tag / Scanned No.', value: _tagController.text),
            for (var i = 0; i < _fieldLabels.length; i++)
              _ConfirmRow(
                  label: _fieldLabels[i], value: _fieldControllers[i].text),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Edit'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm & Save'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final record = FarmRecord(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        tagNumber: _tagController.text.trim(),
        fieldValues: _fieldControllers.map((c) => c.text.trim()).toList(),
        createdBy: widget.createdBy,
        createdAt: DateTime.now(),
      );
      // TODO: This is where you call your database write, e.g.:
      // await FirebaseFirestore.instance.collection('records').doc(record.id).set(record.toMap());
      Navigator.of(context)
          .pop(record); // returns record to ScanScreen -> HomeScreen
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Record')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _tagController,
                decoration: const InputDecoration(
                  labelText: 'Tag / Scanned Number',
                  prefixIcon: Icon(Icons.qr_code),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              // One TextFormField per configured field label.
              for (var i = 0; i < _fieldLabels.length; i++) ...[
                TextFormField(
                  controller: _fieldControllers[i],
                  decoration: InputDecoration(labelText: _fieldLabels[i]),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 14),
              ],
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: _showConfirmationAndSave,
                child: const Text('Review & Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  final String label;
  final String value;
  const _ConfirmRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          children: [
            TextSpan(
                text: '$label: ',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: value.isEmpty ? '(empty)' : value),
          ],
        ),
      ),
    );
  }
}
