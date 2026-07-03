// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import 'composer_pasted_image.dart';

class _WebComposerPasteImageSubscription
    implements ComposerPasteImageSubscription {
  _WebComposerPasteImageSubscription(this._listener) {
    html.document.addEventListener('paste', _listener);
  }

  final html.EventListener _listener;

  @override
  void cancel() {
    html.document.removeEventListener('paste', _listener);
  }
}

ComposerPasteImageSubscription listenForComposerPastedImages({
  required FocusNode focusNode,
  required ValueChanged<ComposerPastedImage> onImage,
}) {
  void listener(html.Event event) {
    if (!focusNode.hasFocus || event is! html.ClipboardEvent) return;
    final items = event.clipboardData?.items;
    if (items == null) return;

    final itemCount = items.length ?? 0;
    for (var index = 0; index < itemCount; index++) {
      final item = items[index];
      final mimeType = item.type?.toLowerCase() ?? '';
      if (!mimeType.startsWith('image/')) continue;

      final file = item.getAsFile();
      if (file == null) continue;
      event.preventDefault();

      final reader = html.FileReader();
      reader.onLoad.first.then((_) {
        final result = reader.result;
        Uint8List bytes;
        if (result is ByteBuffer) {
          bytes = Uint8List.view(result);
        } else if (result is Uint8List) {
          bytes = result;
        } else {
          return;
        }
        final extension = _extensionForMimeType(mimeType);
        final name = file.name.trim().isEmpty
            ? 'pasted-image.$extension'
            : file.name.trim();
        onImage(
          ComposerPastedImage(
            filename: name,
            mimeType: mimeType,
            dataBase64: base64Encode(bytes),
          ),
        );
      });
      reader.readAsArrayBuffer(file);
      return;
    }
  }

  return _WebComposerPasteImageSubscription(listener);
}

String _extensionForMimeType(String mimeType) {
  switch (mimeType) {
    case 'image/jpeg':
      return 'jpg';
    case 'image/webp':
      return 'webp';
    case 'image/gif':
      return 'gif';
    case 'image/png':
    default:
      return 'png';
  }
}
