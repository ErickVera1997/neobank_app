import '../json_utils.dart';
import 'user.dart';

/// Bandera de configuración remota que habilita/oculta capacidades.
class FeatureFlag {
  const FeatureFlag({
    required this.key,
    required this.enabled,
    this.variant,
    this.payload = const {},
  });

  final String key;
  final bool enabled;
  final String? variant;
  final Map<String, dynamic> payload;

  factory FeatureFlag.fromJson(Map<String, dynamic> json) => FeatureFlag(
        key: jsonString(json, 'key'),
        enabled: jsonBool(json, 'enabled'),
        variant: jsonStringOrNull(json, 'variant'),
        payload: jsonMap(json, 'payload'),
      );

  Map<String, dynamic> toJson() => {
        'key': key,
        'enabled': enabled,
        'variant': variant,
        'payload': payload,
      };
}

/// Tipo de módulo del home construido dinámicamente (Server-Driven UI).
enum HomeModuleType {
  heroBalance,
  quickActions,
  fxWidget,
  offersCarousel,
  insights,
  assistant,
  promo,
  custom;

  static HomeModuleType fromName(String? value) =>
      HomeModuleType.values.firstWhere(
        (type) => type.name == value,
        orElse: () => HomeModuleType.custom,
      );
}

/// Módulo de UI solicitado por el backend. Permite incorporar experiencias
/// sin publicar una nueva versión de la app.
class HomeModule {
  const HomeModule({
    required this.id,
    required this.type,
    required this.priority,
    this.title,
    this.subtitle,
    this.enabled = true,
    this.config = const {},
  });

  final String id;
  final HomeModuleType type;
  final int priority;
  final String? title;
  final String? subtitle;
  final bool enabled;
  final Map<String, dynamic> config;

  factory HomeModule.fromJson(Map<String, dynamic> json) => HomeModule(
        id: jsonString(json, 'id'),
        type: HomeModuleType.fromName(jsonStringOrNull(json, 'type')),
        priority: jsonInt(json, 'priority', fallback: 100),
        title: jsonStringOrNull(json, 'title'),
        subtitle: jsonStringOrNull(json, 'subtitle'),
        enabled: jsonBool(json, 'enabled', fallback: true),
        config: jsonMap(json, 'config'),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'priority': priority,
        'title': title,
        'subtitle': subtitle,
        'enabled': enabled,
        'config': config,
      };
}

/// Oferta/contenido personalizado para un segmento.
class Offer {
  const Offer({
    required this.id,
    required this.title,
    required this.description,
    required this.priority,
    this.imageUrl,
    this.ctaLabel,
    this.ctaAction,
  });

  final String id;
  final String title;
  final String description;
  final int priority;
  final String? imageUrl;
  final String? ctaLabel;
  final String? ctaAction;

  factory Offer.fromJson(Map<String, dynamic> json) => Offer(
        id: jsonString(json, 'id'),
        title: jsonString(json, 'title'),
        description: jsonString(json, 'description'),
        priority: jsonInt(json, 'priority', fallback: 100),
        imageUrl: jsonStringOrNull(json, 'imageUrl'),
        ctaLabel: jsonStringOrNull(json, 'ctaLabel'),
        ctaAction: jsonStringOrNull(json, 'ctaAction'),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'priority': priority,
        'imageUrl': imageUrl,
        'ctaLabel': ctaLabel,
        'ctaAction': ctaAction,
      };
}

/// Tokens de tema entregados por el backend para personalización visual.
class AppThemeConfig {
  const AppThemeConfig({
    this.brandName = 'Neobank',
    this.logoUrl,
    this.seedColorHex,
    this.mode,
  });

  final String brandName;
  final String? logoUrl;
  final String? seedColorHex;
  final String? mode;

  factory AppThemeConfig.fromJson(Map<String, dynamic> json) => AppThemeConfig(
        brandName: jsonString(json, 'brandName', fallback: 'Neobank'),
        logoUrl: jsonStringOrNull(json, 'logoUrl'),
        seedColorHex: jsonStringOrNull(json, 'seedColorHex'),
        mode: jsonStringOrNull(json, 'mode'),
      );

  Map<String, dynamic> toJson() => {
        'brandName': brandName,
        'logoUrl': logoUrl,
        'seedColorHex': seedColorHex,
        'mode': mode,
      };
}

/// Configuración inicial (bootstrap) que personaliza la experiencia.
class AppBootstrap {
  const AppBootstrap({
    required this.user,
    required this.version,
    required this.flags,
    required this.home,
    required this.offers,
    required this.theme,
    this.experimentBucket,
  });

  final User user;
  final String version;
  final List<FeatureFlag> flags;
  final List<HomeModule> home;
  final List<Offer> offers;
  final AppThemeConfig theme;
  final String? experimentBucket;

  bool flagEnabled(String key) =>
      flags.where((flag) => flag.key == key).any((flag) => flag.enabled);

  FeatureFlag? flag(String key) {
    for (final candidate in flags) {
      if (candidate.key == key) return candidate;
    }
    return null;
  }

  factory AppBootstrap.fromJson(Map<String, dynamic> json) => AppBootstrap(
        user: User.fromJson(jsonMap(json, 'user')),
        version: jsonString(json, 'version', fallback: '1'),
        flags: jsonList(json, 'flags')
            .map(FeatureFlag.fromJson)
            .toList(growable: false),
        home: jsonList(json, 'home')
            .map(HomeModule.fromJson)
            .toList(growable: false),
        offers: jsonList(json, 'offers')
            .map(Offer.fromJson)
            .toList(growable: false),
        theme: AppThemeConfig.fromJson(jsonMap(json, 'theme')),
        experimentBucket: jsonStringOrNull(json, 'experimentBucket'),
      );

  Map<String, dynamic> toJson() => {
        'user': user.toJson(),
        'version': version,
        'flags': flags.map((f) => f.toJson()).toList(growable: false),
        'home': home.map((h) => h.toJson()).toList(growable: false),
        'offers': offers.map((o) => o.toJson()).toList(growable: false),
        'theme': theme.toJson(),
        'experimentBucket': experimentBucket,
      };
}
