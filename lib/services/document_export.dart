import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('com.bekirturgut.birikio/documents');

Future<bool> saveDocument({
  required String name,
  required String mimeType,
  required Uint8List bytes,
}) async {
  if (Platform.isAndroid) {
    return await _channel.invokeMethod<bool>('saveDocument', {
          'name': name,
          'mimeType': mimeType,
          'bytes': bytes,
        }) ??
        false;
  }
  final location = await getSaveLocation(suggestedName: name);
  if (location == null) return false;
  await XFile.fromData(
    bytes,
    name: name,
    mimeType: mimeType,
  ).saveTo(location.path);
  return true;
}
