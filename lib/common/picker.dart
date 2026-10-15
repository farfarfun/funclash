import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:funclash/common/common.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class Picker {
  Future<PlatformFile?> pickerFile() async {
    return FilePicker.pickFile(initialDirectory: await appPath.downloadDirPath);
  }

  Future<Uri?> saveFile(String fileName, Uint8List bytes) async {
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      initialDirectory: await appPath.downloadDirPath,
      bytes: bytes,
    );
    if (system.isDesktop && uri != null && uri.scheme == 'file') {
      await safeWritePathAsBytes(uri.toFilePath(), bytes);
    }
    return uri;
  }

  Future<Uri?> saveFileWithPath(String fileName, String localPath) async {
    final bytes = await readPathAsBytesOrEmpty(localPath);
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      initialDirectory: await appPath.downloadDirPath,
      bytes: bytes,
    );
    await safeDeletePath(localPath);
    return uri;
  }

  Future<String?> pickerConfigQRCode() async {
    final xFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (xFile == null) {
      return null;
    }
    // Not through a throwaway MobileScannerController: disposing one clears
    // the platform scan window of a scanner page that is still open.
    final capture = await MobileScannerPlatform.instance.analyzeImage(
      xFile.path,
      formats: const [BarcodeFormat.qrCode],
    );
    final url = profileUrlFromQrCodes(
      capture?.barcodes.map((barcode) => barcode.rawValue) ?? const [],
    );
    if (url == null) {
      throw MessageException(currentAppLocalizations.pleaseUploadValidQrcode);
    }
    return url;
  }
}

extension PlatformFileExt on PlatformFile {
  Future<Uint8List> readBytes() {
    return readAsBytes();
  }
}

final picker = Picker();
