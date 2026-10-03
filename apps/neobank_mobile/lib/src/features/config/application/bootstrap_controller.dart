import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neobank_core/neobank_core.dart';

import '../../auth/application/auth_controller.dart';
import '../data/config_repository.dart';

/// Carga y refresca el bootstrap (Server-Driven UI) del usuario actual.
class BootstrapController extends AsyncNotifier<BootstrapResult> {
  @override
  Future<BootstrapResult> build() async {
    ref.watch(currentUserIdProvider);
    return ref.read(configRepositoryProvider).bootstrap();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(configRepositoryProvider).bootstrap(),
    );
  }
}

final bootstrapProvider =
    AsyncNotifierProvider<BootstrapController, BootstrapResult>(
  BootstrapController.new,
);

final themeConfigProvider = Provider<AppThemeConfig>((ref) {
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
