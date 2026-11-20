import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mess_app/core/auth/session_manager.dart';
import 'package:mess_app/core/auth/user_session.dart';
import 'package:mess_app/core/localization/app_language.dart';
import 'package:mess_app/core/service_locator/di.dart';
import 'package:mess_app/data/models/tree_task_model.dart';
import 'package:mess_app/presentation/pages/tasks/tree_task_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const t = AppText(AppLanguage.english);
  const cases = [
    (
      name: 'available for self-planting or delegation',
      status: TaskStatus.pending,
      workerId: null,
      label: 'Plant myself',
    ),
    (
      name: 'resumable by the field admin',
      status: TaskStatus.assigned,
      workerId: null,
      label: 'Update Task',
    ),
    (
      name: 'assigned to a field volunteer',
      status: TaskStatus.assigned,
      workerId: 'worker',
      label: null,
    ),
    (
      name: 'planted by the field admin',
      status: TaskStatus.planted,
      workerId: null,
      label: 'Tree Details',
    ),
  ];

  for (final taskCase in cases) {
    testWidgets('field admin task ${taskCase.name}', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 920);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        'session_role': UserRole.volunteer.name,
        'session_user_id': 'field-admin',
        'session_user_name': 'Field Admin',
      });
      getIt.registerSingleton(SessionManager());
      addTearDown(() => getIt.unregister<SessionManager>());
      final now = DateTime(2026, 1, 1);
      await tester.pumpWidget(
        MaterialApp(
          home: TreeTaskDetailScreen(
            t: t,
            task: TreeTaskModel(
              id: 'planting-task',
              plotId: 'plot',
              species: 'Neem',
              latitude: 10,
              longitude: 76,
              volunteerId: taskCase.status == TaskStatus.pending
                  ? null
                  : 'field-admin',
              workerId: taskCase.workerId,
              taskStatus: taskCase.status,
              createdAt: now,
              updatedAt: now,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      for (final label in [t.plantMyself, t.updateTask, t.treeDetails]) {
        expect(
          find.text(label),
          label == taskCase.label ? findsOneWidget : findsNothing,
        );
      }
      if (taskCase.status == TaskStatus.pending) {
        expect(find.text(t.assignWorker), findsOneWidget);
      }
    });
  }
}
