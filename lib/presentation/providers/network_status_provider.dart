// presentation/providers/network_status_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/app_exception.dart';

/// Tracks whether the app is currently offline.
///
/// Set to `true` when any provider catches a [NetworkException] on a
/// foreground (non-background-SWR) request. Reset to `false` when a
/// subsequent request succeeds.
///
/// Stale cached data is served transparently — the banner only appears when
/// a live request fails due to connectivity.
final networkStatusProvider =
    NotifierProvider<NetworkStatusNotifier, bool>(NetworkStatusNotifier.new);

class NetworkStatusNotifier extends Notifier<bool> {
  @override
  bool build() => false; // assume online at startup

  /// Call when a foreground request throws [NetworkException].
  void markOffline() {
    if (state != true) state = true;
  }

  /// Call when a foreground request succeeds after being offline.
  void markOnline() {
    if (state != false) state = false;
  }
}
