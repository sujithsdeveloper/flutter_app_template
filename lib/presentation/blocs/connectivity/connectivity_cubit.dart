import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mess_app/core/constants/app_logger.dart';

import 'connectivity_state.dart';

/// Listens to the system connectivity stream and emits [ConnectivityOnline] /
/// [ConnectivityOffline]. Any screen that needs to react to network changes
/// (e.g. showing a banner or disabling the sync button) should consume this
/// Cubit instead of calling [Connectivity] directly.
class ConnectivityCubit extends Cubit<ConnectivityState> {
  ConnectivityCubit() : super(const ConnectivityOffline()) {
    _init();
  }

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;

  Future<void> _init() async {
    try {
      final initial = await _connectivity.checkConnectivity();
      _emitFromResults(initial);
    } catch (_) {
      emit(const ConnectivityOffline());
    }

    _sub = _connectivity.onConnectivityChanged.listen(
      _emitFromResults,
      onError: (_) => emit(const ConnectivityOffline()),
    );
  }

  void _emitFromResults(List<ConnectivityResult> results) {
    final isOnline = results.any((r) => r != ConnectivityResult.none);
    AppLogger.request(
      '[ConnectivityCubit] ${isOnline ? 'Online → ${results.first.name}' : 'Offline'}',
    );
    emit(isOnline ? const ConnectivityOnline() : const ConnectivityOffline());
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
