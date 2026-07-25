import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:crop_image/crop_image.dart';
import 'package:path_provider/path_provider.dart';

class ImageCropPage extends StatefulWidget {
  final String imagePath;

  const ImageCropPage({
    super.key,
    required this.imagePath,
  });

  @override
  State<ImageCropPage> createState() => _ImageCropPageState();
}

class _ImageCropPageState extends State<ImageCropPage> {
  late final CropController _controller;
  bool _isCropping = false;
  double? _currentRatio = 1.0; // Default to 1:1 Square for profile photos

  @override
  void initState() {
    super.initState();
    _controller = CropController(
      aspectRatio: _currentRatio,
      defaultCrop: const Rect.fromLTRB(0.1, 0.1, 0.9, 0.9),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setAspectRatio(double? ratio) {
    setState(() {
      _currentRatio = ratio;
      _controller.aspectRatio = ratio;
    });
  }

  Future<void> _saveCroppedImage() async {
    setState(() => _isCropping = true);

    try {
      // 1. Get the cropped bitmap from controller
      final ui.Image bitmap = await _controller.croppedBitmap();

      // 2. Convert the bitmap to PNG ByteData
      final ByteData? byteData = await bitmap.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Failed to encode image to PNG.');
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // 3. Save the bytes to a temporary file
      final tempDir = await getTemporaryDirectory();
      final croppedPath = '${tempDir.path}/cropped_profile_${DateTime.now().millisecondsSinceEpoch}.png';
      final croppedFile = File(croppedPath);
      await croppedFile.writeAsBytes(pngBytes);

      if (!mounted) return;

      // 4. Return the cropped file path to the calling screen
      Navigator.of(context).pop(croppedPath);
    } catch (e) {
      debugPrint('Image crop processing failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to crop image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCropping = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Crop Photo',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.rotate_right_rounded, color: Colors.white, size: 28),
            tooltip: 'Rotate 90°',
            onPressed: () => _controller.rotateRight(),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Main Crop Area
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.center,
                  child: CropImage(
                    controller: _controller,
                    image: Image.file(
                      File(widget.imagePath),
                      fit: BoxFit.contain,
                    ),
                    gridColor: const Color(0xFFFE6A1C).withAlpha((0.8 * 255).round()),
                    gridCornerColor: const Color(0xFFFE6A1C),
                    gridCornerSize: 20,
                    gridThinWidth: 1,
                    gridThickWidth: 2,
                    scrimColor: Colors.black.withAlpha((0.65 * 255).round()),
                  ),
                ),
              ),

              // Aspect Ratio Selection Bar
              Container(
                color: const Color(0xFF121212),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildRatioButton(label: 'Free', ratio: null),
                      _buildRatioButton(label: '1:1 (Square)', ratio: 1.0),
                      _buildRatioButton(label: '4:3', ratio: 4.0 / 3.0),
                      _buildRatioButton(label: '16:9', ratio: 16.0 / 9.0),
                    ],
                  ),
                ),
              ),

              // Bottom Actions
              SafeArea(
                top: false,
                child: Container(
                  color: const Color(0xFF1E1E1E),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      // Cancel Button
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: Color(0xFF9C9C9C),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Save Button
                      Expanded(
                        child: FilledButton(
                          onPressed: _isCropping ? null : _saveCroppedImage,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFE6A1C),
                            disabledBackgroundColor: const Color(0xFFFFB085),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          child: const Text(
                            'Save',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Loading Overlay while cropping
          if (_isCropping)
            Container(
              color: Colors.black.withAlpha((0.7 * 255).round()),
              alignment: Alignment.center,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    color: Color(0xFFFE6A1C),
                    strokeWidth: 3,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Cropping & processing photo...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRatioButton({required String label, required double? ratio}) {
    final isSelected = _currentRatio == ratio;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => _setAspectRatio(ratio),
        backgroundColor: const Color(0xFF262626),
        selectedColor: const Color(0xFFFE6A1C),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFFC5C5C5),
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
        checkmarkColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? const Color(0xFFFE6A1C) : Colors.transparent,
          ),
        ),
      ),
    );
  }
}
