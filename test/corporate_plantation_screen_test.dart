import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mess_app/core/auth/session_manager.dart';
import 'package:mess_app/core/network/field_api_service.dart';
import 'package:mess_app/core/network/field_sync_service.dart';
import 'package:mess_app/core/service_locator/di.dart';
import 'package:mess_app/presentation/pages/tasks/corporate_plantation_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PlantationApi implements FieldApiService {
  var online = false;
  var photoStorageOnline = false;
  final attachments = <String>[];
  final recorded = <String>[];
  var successfulUploads = 0;

  void _requireConnection() {
    if (!online) {
      throw DioException(
        requestOptions: RequestOptions(),
        type: DioExceptionType.connectionError,
      );
    }
  }

  @override
  Future<List<Map<String, dynamic>>> listPlantationBatches() async {
    _requireConnection();
    return [
      {..._batch, 'planted': recorded.length * 5},
    ];
  }

  @override
  Future<String> recordPlantationSession(
    String id,
    Map<String, dynamic> body,
  ) async {
    _requireConnection();
    expect(id, 'batch-1');
    expect(body['photoUrl'], isNull);
    recorded.add(body['submissionKey'] as String);
    return 'saved-session';
  }

  @override
  Future<String> uploadPlantationPhoto(List<int> bytes) async {
    expect(bytes, [1, 2, 3]);
    if (!photoStorageOnline) {
      final options = RequestOptions();
      throw DioException.badResponse(
        statusCode: 503,
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: 503),
      );
    }
    successfulUploads++;
    return '/api/v1/media/plantation_photo/photo-$successfulUploads';
  }

  @override
  Future<void> attachPlantationPhoto(
    String sessionId,
    String photoUrl, {
    String? capturedAt,
  }) async {
    expect(sessionId, 'saved-session');
    attachments.add(photoUrl);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FieldSync implements FieldSyncService {
  var pulls = 0;

  @override
  Future<void> pullAndApply() async {
    pulls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _batch = {
  'programName': 'Restoration project',
  'companyName': 'Example company',
  'plot': 'Existing nursery',
  'region': 'Central Kerala',
  'planted': 0,
  'quantity': 20,
};

void main() {
  for (final multiplePhotos in [false, true]) {
    testWidgets(
      multiplePhotos
          ? 'all session photos retry without recording the planting twice'
          : 'planting syncs after reconnect and a failed photo retries separately',
      (tester) async {
        const prefix = 'corporate-plantation.worker.worker-1.';
        const draftKey = '${prefix}draft.1.retry-id';
        const otherAccountDraft =
            'corporate-plantation.worker.worker-2.draft.1.other';
        final draft = jsonEncode({
          'batchId': 'batch-1',
          'payload': {'submissionKey': 'retry-id', 'quantity': 5},
          if (multiplePhotos)
            'photos': [
              {
                'image': base64Encode([1, 2, 3]),
                'capturedAt': '2026-11-21T01:00:00Z',
              },
              {
                'image': base64Encode([1, 2, 3]),
                'capturedAt': '2026-11-21T01:01:00Z',
              },
            ]
          else
            'photo': base64Encode([1, 2, 3]),
        });
        SharedPreferences.setMockInitialValues({
          'session_role': 'worker',
          'session_user_id': 'worker-1',
          'session_user_name': 'Planter',
          '${prefix}batches': jsonEncode([_batch]),
          draftKey: draft,
          otherAccountDraft: draft,
        });
        final api = _PlantationApi();
        final sync = _FieldSync();
        getIt.registerSingleton<SessionManager>(SessionManager());
        getIt.registerSingleton<FieldApiService>(api);
        getIt.registerSingleton<FieldSyncService>(sync);
        addTearDown(() => getIt.reset());
        final messenger = tester.binding.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
          (_) async => null,
        );

        await tester.pumpWidget(
          const MaterialApp(home: CorporatePlantationScreen()),
        );
        await tester.pumpAndSettle();
        expect(find.text('Restoration project'), findsOneWidget);
        expect(
          find.textContaining('1 planting sessions saved'),
          findsOneWidget,
        );
        expect(api.recorded, isEmpty);
        final preferences = await SharedPreferences.getInstance();
        expect(preferences.containsKey(draftKey), isTrue);

        api.online = true;
        await tester.tap(find.byTooltip('Refresh and send saved sessions'));
        await tester.pumpAndSettle();
        expect(api.recorded, ['retry-id']);
        expect(preferences.containsKey(draftKey), isTrue);
        expect(
          jsonDecode(preferences.getString(draftKey)!)['sessionId'],
          'saved-session',
        );
        expect(preferences.containsKey(otherAccountDraft), isTrue);
        expect(find.textContaining('5 of 20 planted'), findsOneWidget);
        final pendingMessage = multiplePhotos
            ? '2 planting photos pending'
            : '1 planting photo pending';
        expect(find.text(pendingMessage), findsOneWidget);
        expect(sync.pulls, 1);

        api.photoStorageOnline = true;
        await tester.tap(find.byTooltip('Refresh and send saved sessions'));
        await tester.pumpAndSettle();
        expect(api.recorded, ['retry-id']);
        expect(api.attachments, [
          '/api/v1/media/plantation_photo/photo-1',
          if (multiplePhotos) '/api/v1/media/plantation_photo/photo-2',
        ]);
        expect(preferences.containsKey(draftKey), isFalse);
        expect(find.text(pendingMessage), findsNothing);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
