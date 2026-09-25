import 'package:equatable/equatable.dart';

sealed class ConnectivityState extends Equatable {
  const ConnectivityState();
}

/// The device has at least one active network interface (WiFi / mobile data).
final class ConnectivityOnline extends ConnectivityState {
  const ConnectivityOnline();
  @override
  List<Object?> get props => [];
}

/// No active network interface is available.
final class ConnectivityOffline extends ConnectivityState {
  const ConnectivityOffline();
  @override
  List<Object?> get props => [];
}
