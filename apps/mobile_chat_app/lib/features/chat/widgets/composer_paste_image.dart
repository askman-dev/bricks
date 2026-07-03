import 'package:flutter/widgets.dart';

import 'composer_paste_image_stub.dart'
    if (dart.library.html) 'composer_paste_image_web.dart' as impl;
import 'composer_pasted_image.dart';

ComposerPasteImageSubscription listenForComposerPastedImages({
  required FocusNode focusNode,
  required ValueChanged<ComposerPastedImage> onImage,
}) {
  return impl.listenForComposerPastedImages(
    focusNode: focusNode,
    onImage: onImage,
  );
}
