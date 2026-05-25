// core/utils/network_aware_call.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../error/app_exception.dart';
import '../../presentation/providers/network_status_provider.dart';

/// Executes [call] and updates [networkStatusProvider] based on the outcome.
///
/// - On [NetworkException]: marks offline and rethrows.
/// - On any other outcome (success or non-network error): marks online.
///
/// Use this wrapper in Riverpod notifier `build()` methods and mutation
/// methods for foreground (non-background-SWR) requests.
Future<T> networkAwareCall<T>(Ref ref, Future<T> Function() call) async {
  try {
    final result = await call();
    ref.read(networkStatusProvider.notifier).markOnline();
    return result;
  } on NetworkException {
    ref.read(networkStatusProvider.notifier).markOffline();
    rethrow;
  }
}
