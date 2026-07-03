import 'package:flutter/widgets.dart';

import 'composer_pasted_image.dart';

class _NoopComposerPasteImageSubscription
    implements ComposerPasteImageSubscription {
  const _NoopComposerPasteImageSubscription();

  @override
  void cancel() {}
}

ComposerPasteImageSubscription listenForComposerPastedImages({
  required FocusNode focusNode,
  required ValueChanged<ComposerPastedImage> onImage,
}) {
  return const _NoopComposerPasteImageSubscription();
}
