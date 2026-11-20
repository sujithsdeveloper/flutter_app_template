import 'package:mess_app/core/network/field_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mess_app/core/service_locator/di.dart';
import 'package:mess_app/data/models/tree_model.dart';
import 'package:mess_app/data/repositories/tree_repository.dart';
import 'package:mess_app/presentation/blocs/dashboard/dashboard_cubit.dart';
import 'package:mess_app/presentation/blocs/dashboard/dashboard_state.dart';
import 'package:mess_app/presentation/pages/trees/field_trees_screen.dart';

void main() {
  testWidgets('field admins see regions, plots, and each planter', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 840);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    getIt.registerSingleton<TreeRepository>(_InventoryRepository());
    getIt.registerSingleton<FieldApiService>(_NoCampaignsApi());
    addTearDown(() async {
      await getIt.unregister<TreeRepository>();
      await getIt.unregister<FieldApiService>();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<DashboardCubit>.value(
          value: _Dashboard(),
          child: const Scaffold(body: FieldTreesScreen(active: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Planted trees (2)'), findsOneWidget);
    expect(find.text('North Kerala'), findsOneWidget);
    expect(find.text('South Kerala'), findsOneWidget);
    expect(find.text('North Orchard'), findsOneWidget);
    expect(find.text('South Orchard'), findsOneWidget);
    expect(find.textContaining('Planted by: Anu'), findsOneWidget);
    expect(find.textContaining('Planted by: Dev'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _Dashboard extends Fake implements DashboardCubit {
  @override
  DashboardState get state => DashboardState.initial();

  @override
  Stream<DashboardState> get stream => const Stream.empty();
}

class _InventoryRepository extends Fake implements TreeRepository {
  @override
  Future<List<TreeModel>> getFieldInventory() async {
    final date = DateTime(2026, 1, 1);
    return [
      for (final (region, planter) in [('North', 'Anu'), ('South', 'Dev')])
        TreeModel(
          id: '$region-tree',
          plotId: '$region-plot',
          plotName: '$region Orchard',
          regionName: '$region Kerala',
          plantedBy: planter,
          species: 'Neem',
          latitude: 10,
          longitude: 76,
          plantingDate: date,
          createdAt: date,
          updatedAt: date,
        ),
    ];
  }
}

class _NoCampaignsApi extends Fake implements FieldApiService {
  @override
  Future<List<Map<String, dynamic>>> listPlantationAllocations() async => [];
}
