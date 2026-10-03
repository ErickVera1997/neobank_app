import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neobank_core/neobank_core.dart';

import '../../../core/error/app_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../data/config_repository.dart';

/// Carga y refresca el bootstrap (Server-Driven UI) del usuario actual.
class BootstrapController extends AsyncNotifier<BootstrapResult> {
  @override
  Future<BootstrapResult> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return BootstrapResult.unauthenticated();
    return ref.read(configRepositoryProvider).bootstrap();
  }

  Future<void> refresh() async {
    if (ref.read(currentUserIdProvider) == null) {
      state = AsyncData(BootstrapResult.unauthenticated());
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(configRepositoryProvider).bootstrap(),
    );
  }
}

final bootstrapProvider =
    AsyncNotifierProvider<BootstrapController, BootstrapResult>(
  BootstrapController.new,
  retry: (retryCount, error) {
    if (error is AppException && error.kind == AppErrorKind.unauthorized) {
      return null;
    }
    return ProviderContainer.defaultRetry(retryCount, error);
  },
);

final themeConfigProvider = Provider<AppThemeConfig>((ref) {
  if (ref.watch(currentUserIdProvider) == null) {
    return const AppThemeConfig();
  }
  return ref.watch(bootstrapProvider).value?.bootstrap.theme ??
      const AppThemeConfig();
});

/// Módulos del home habilitados, ordenados por prioridad.
final homeModulesProvider = Provider<List<HomeModule>>((ref) {
  final modules =
      ref.watch(bootstrapProvider).value?.bootstrap.home ?? const <HomeModule>[];
  final enabled = modules.where((module) => module.enabled).toList();
  enabled.sort((a, b) => a.priority.compareTo(b.priority));
  return enabled;
});

final offersProvider = Provider<List<Offer>>((ref) {
  final offers =
      ref.watch(bootstrapProvider).value?.bootstrap.offers ?? const <Offer>[];
  final sorted = [...offers]..sort((a, b) => a.priority.compareTo(b.priority));
  return sorted;
});

final featureFlagsProvider = Provider<List<FeatureFlag>>(
  (ref) => ref.watch(bootstrapProvider).value?.bootstrap.flags ?? const [],
);

final experimentBucketProvider = Provider<String?>(
  (ref) => ref.watch(bootstrapProvider).value?.bootstrap.experimentBucket,
);
