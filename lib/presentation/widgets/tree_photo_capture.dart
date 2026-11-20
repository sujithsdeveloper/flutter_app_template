import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mess_app/core/localization/app_language.dart';
import 'package:mess_app/presentation/widgets/snackbar_helper.dart';

Future<String?> captureTreePhoto(BuildContext context, AppText t) async {
  final picker = ImagePicker();
  // The web picker can open a file chooser even with ImageSource.camera.
  if (kIsWeb || !picker.supportsImageSource(ImageSource.camera)) {
    SnackbarHelper.showError(
      context: context,
      message: t.treeCameraUnavailable,
    );
    return null;
  }

  try {
    final photo = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 72,
      maxWidth: 1280,
      requestFullMetadata: false,
    );
    return photo?.path;
  } on PlatformException {
    if (context.mounted) {
      SnackbarHelper.showError(context: context, message: t.treeCameraFailed);
    }
    return null;
  }
}
