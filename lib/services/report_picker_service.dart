import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../config.dart';

class ReportFileResult {
  final Uint8List bytes;
  final String name;
  final int sizeBytes;
  final bool isImage;
  final String? path;

  const ReportFileResult({
    required this.bytes,
    required this.name,
    required this.sizeBytes,
    required this.isImage,
    this.path,
  });

  bool get isTooLarge => sizeBytes > AppConfig.maxReportSizeBytes;
}

class ReportPickerService {
  static final ImagePicker _imagePicker = ImagePicker();

  /// Picks a document or photo from device storage (PDF, JPG, PNG).
  /// Works seamlessly on Android, iOS, Desktop, and Web.
  static Future<ReportFileResult?> pickFromDevice() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      allowMultiple: false,
      withData: true, // Guarantees in-memory bytes on all platforms
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final platformFile = result.files.single;
    Uint8List? fileBytes = platformFile.bytes;

    if (fileBytes == null && platformFile.path != null) {
      // On desktop/mobile if withData was not loaded synchronously
      final xfile = XFile(platformFile.path!);
      fileBytes = await xfile.readAsBytes();
    }

    if (fileBytes == null) return null;

    final ext = platformFile.name.split('.').last.toLowerCase();
    final isImage = ['jpg', 'jpeg', 'png'].contains(ext);

    return ReportFileResult(
      bytes: fileBytes,
      name: platformFile.name,
      sizeBytes: fileBytes.lengthInBytes,
      isImage: isImage,
      path: platformFile.path,
    );
  }

  /// Captures a fresh photo of the blood report using the camera.
  static Future<ReportFileResult?> pickFromCamera() async {
    final photo = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );

    if (photo == null) return null;

    final bytes = await photo.readAsBytes();

    return ReportFileResult(
      bytes: bytes,
      name: photo.name.isNotEmpty ? photo.name : 'camera_report.jpg',
      sizeBytes: bytes.lengthInBytes,
      isImage: true,
      path: photo.path,
    );
  }
}
