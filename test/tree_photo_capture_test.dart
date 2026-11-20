import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mess_app/core/localization/app_language.dart';
import 'package:mess_app/presentation/widgets/tree_photo_capture.dart';

void main() {
  const channel = MethodChannel('plugins.flutter.io/image_picker');
  const t = AppText(AppLanguage.english);

  for (final denied in [false, true]) {
    testWidgets(
      denied
          ? 'camera denial never opens another picker'
          : 'captures a camera photo',
      (tester) async {
        final calls = <MethodCall>[];
        final messenger = tester.binding.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (denied) throw PlatformException(code: 'camera_access_denied');
          return '/tmp/tree-photo.jpg';
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

        String? photoPath;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    photoPath = await captureTreePhoto(context, t);
                  },
                  child: Text(t.takePhoto),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text(t.takePhoto));
        await tester.pumpAndSettle();

        expect(calls.single.method, 'pickImage');
        expect(calls.single.arguments['source'], ImageSource.camera.index);
        expect(calls.single.arguments['requestFullMetadata'], isFalse);
        expect(photoPath, denied ? isNull : '/tmp/tree-photo.jpg');
        expect(
          find.text(t.treeCameraFailed),
          denied ? findsOneWidget : findsNothing,
        );
      },
    );
  }
}
