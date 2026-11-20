import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mess_app/core/network/field_api_service.dart';
import 'package:mess_app/core/service_locator/di.dart';
import 'package:mess_app/presentation/pages/trees/field_campaigns_screen.dart';

class _CampaignApi extends Fake implements FieldApiService {
  final pages = <int>[];

  @override
  Future<List<Map<String, dynamic>>> listPlantationAllocations() async => [
    {
      'id': 'allocation',
      'programId': 'campaign',
      'programName': 'Mangrove restoration',
      'companyName': 'Example Company',
      'sponsored': 100,
      'campaignPlanted': 30,
      'campaignAllocated': 100,
      'region': 'Central Kerala',
      'plot': 'Nursery A',
      'species': 'Mangrove',
      'quantity': 100,
      'assigned': 30,
      'planted': 30,
      'canManage': false,
    },
  ];

  @override
  Future<List<Map<String, dynamic>>> listPlantationBatches() async => [
    {
      'id': 'batch',
      'programId': 'campaign',
      'allocationId': 'allocation',
      'region': 'Central Kerala',
      'plot': 'Nursery A',
      'volunteer': 'Field volunteer',
      'quantity': 30,
      'planted': 30,
    },
  ];

  @override
  Future<Map<String, dynamic>> batchTrees(String batchId, int page) async {
    expect(batchId, 'batch');
    pages.add(page);
    return {
      'total': 30,
      'pageSize': 24,
      'trees': [
        {
          'id': 'tree-$page',
          'treeId': 'tree-$page',
          'plotId': 'plot-a',
          'plotName': 'Nursery A',
          'regionName': 'Central Kerala',
          'species': 'Mangrove tree page $page',
          'plantedBy': 'Field volunteer',
          'lat': 10,
          'lng': 76,
          'category': 'corporate',
        },
      ],
    };
  }
}

void main() {
  testWidgets(
    'field campaigns open one allocation and load batch trees by page',
    (tester) async {
      tester.view.physicalSize = const Size(390, 980);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = _CampaignApi();
      getIt.registerSingleton<FieldApiService>(api);
      addTearDown(() => getIt.reset());
      await tester.pumpWidget(const MaterialApp(home: FieldCampaignsScreen()));
      await tester.pumpAndSettle();

      expect(find.textContaining('30 of 100 planted'), findsOneWidget);
      expect(api.pages, isEmpty);
      await tester.tap(find.text('Mangrove restoration'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Central Kerala · Nursery A'));
      await tester.pumpAndSettle();
      expect(find.text('70 trees left to assign'), findsOneWidget);
      expect(api.pages, isEmpty);

      await tester.tap(find.text('Field volunteer'));
      await tester.pumpAndSettle();
      expect(find.text('Mangrove tree page 1'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Mangrove tree page 2'), findsOneWidget);
      expect(api.pages, [1, 2]);
    },
  );
}
