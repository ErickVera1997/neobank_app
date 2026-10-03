import 'package:neobank_core/neobank_core.dart';
import 'package:shelf/shelf.dart';

import '../../app.dart';
import '../../services/insights_service.dart';
import '../http_helpers.dart';
import '../middleware.dart';

/// Configuración remota y personalización dinámica.
///
/// El backend decide qué módulos, ofertas y tema recibe cada usuario según su
/// segmento y las feature flags. Esto permite lanzar experiencias sin publicar
/// una nueva versión de la app (Server-Driven UI).
class ConfigHandler {
  const ConfigHandler(this.app);

  final AppContainer app;

  Future<Response> bootstrap(Request request) async {
    final user = currentUser(request);
    final flags = app.store.flagsForSegment(user.segment);
    final bootstrap = AppBootstrap(
      user: user,
      version: 'bootstrap-1',
      flags: flags,
      home: _buildHome(user, flags),
      offers: _offersFor(user),
      theme: _themeFor(user.segment),
      experimentBucket: user.segment == UserSegment.premium ? 'B' : 'A',
    );
    return jsonResponse(bootstrap.toJson());
  }

  List<HomeModule> _buildHome(User user, List<FeatureFlag> flags) {
    bool enabled(String key) =>
        flags.any((flag) => flag.key == key && flag.enabled);

    final modules = <HomeModule>[
      HomeModule(
        id: 'hero',
        type: HomeModuleType.heroBalance,
        priority: 10,
        title: 'Hola, ${user.firstName}',
        config: const {'showAvailable': true},
      ),
      const HomeModule(
        id: 'actions',
        type: HomeModuleType.quickActions,
        priority: 20,
        config: {
          'items': ['transfer', 'pay', 'topup', 'fx'],
        },
      ),
    ];

    if (enabled('early_salary') && user.segment == UserSegment.premium) {
      modules.add(
        const HomeModule(
          id: 'early_salary',
          type: HomeModuleType.promo,
          priority: 15,
          title: 'Adelanta tu salario',
          subtitle: 'Disponible hasta USD 5,000',
          config: {'action': 'early_salary'},
        ),
      );
    }
    if (enabled('assistant')) {
      modules.add(
        const HomeModule(
          id: 'assistant',
          type: HomeModuleType.assistant,
          priority: 25,
          title: 'Copiloto financiero',
          subtitle: 'Pregúntame por tus finanzas',
          config: {
            'examples': [
              '¿Cuál es mi saldo?',
              '¿Cuánto gasté este mes?',
              '¿Cuánto es 100 USD en EUR?',
            ],
          },
        ),
      );
    }
    if (enabled('fx_widget')) {
      modules.add(
        const HomeModule(
          id: 'fx',
          type: HomeModuleType.fxWidget,
          priority: 30,
          title: 'Conversión de divisas',
          config: {'defaultFrom': 'USD', 'defaultTo': 'EUR'},
        ),
      );
    }
    if (enabled('investments_module')) {
      modules.add(
        const HomeModule(
          id: 'investments',
          type: HomeModuleType.insights,
          priority: 35,
          title: 'Tu portafolio',
          config: {'action': 'investments'},
        ),
      );
    }
    if (enabled('insights')) {
      modules.add(
        const HomeModule(
          id: 'insights',
          type: HomeModuleType.insights,
          priority: 40,
          title: 'Insights del mes',
          config: {'action': 'insights'},
        ),
      );
    }
    if (enabled('offers_carousel')) {
      modules.add(
        const HomeModule(
          id: 'offers',
          type: HomeModuleType.offersCarousel,
          priority: 50,
          title: 'Para ti',
        ),
      );
    }
    modules.sort((a, b) => a.priority.compareTo(b.priority));
    return modules;
  }

  List<Offer> _segmentOffers(UserSegment segment) {
    final base = <Offer>[
      const Offer(
        id: 'cashback',
        title: '3% de cashback',
        description: 'En restaurantes y cafés este mes.',
        priority: 10,
        ctaLabel: 'Ver más',
        ctaAction: 'cashback',
      ),
      const Offer(
        id: 'goal',
        title: 'Crea tu meta de ahorro',
        description: 'Automatiza un ahorro semanal.',
        priority: 20,
        ctaLabel: 'Crear meta',
        ctaAction: 'savings_goal',
      ),
    ];
    switch (segment) {
      case UserSegment.premium:
        base.add(
          const Offer(
            id: 'travel',
            title: 'Seguro de viaje sin costo',
            description: 'Beneficio Premium para tu próxima aventura.',
            priority: 5,
            ctaLabel: 'Activar',
            ctaAction: 'travel_insurance',
          ),
        );
      case UserSegment.pyme:
        base.add(
          const Offer(
            id: 'payroll',
            title: 'Nómina para tu negocio',
            description: 'Paga a tu equipo en segundos.',
            priority: 5,
            ctaLabel: 'Conocer',
            ctaAction: 'payroll',
          ),
        );
      case UserSegment.youth:
        base.add(
          const Offer(
            id: 'student',
            title: 'Modo estudiante',
            description: 'Sin comisiones y con recompensas.',
            priority: 5,
            ctaLabel: 'Activar',
            ctaAction: 'student_mode',
          ),
        );
      case UserSegment.standard:
        break;
    }
    base.sort((a, b) => a.priority.compareTo(b.priority));
    return base;
  }

  /// Combina ofertas de segmento con ofertas generadas por comportamiento.
  List<Offer> _offersFor(User user) {
    final offers = <Offer>[
      ..._behaviorOffers(user),
      ..._segmentOffers(user.segment),
    ];
    offers.sort((a, b) => a.priority.compareTo(b.priority));
    return offers;
  }

  /// Ofertas derivadas de los hábitos reales del usuario (dinámicas).
  List<Offer> _behaviorOffers(User user) {
    try {
      final insights = app.insights.monthly(user.id);
      final offers = <Offer>[];
      if (insights.byCategory.isNotEmpty) {
        final top = insights.byCategory.first;
        final label = InsightsService.categoryLabel(top.category);
        offers.add(
          Offer(
            id: 'dyn_top_${top.category}',
            title: _behaviorTitle(top.category),
            description: 'Detectamos que tu mayor gasto es $label '
                '(${top.amount.format()} este mes). '
                '${_behaviorTip(top.category)}',
            priority: 1,
            ctaLabel: 'Preguntar al copiloto',
            ctaAction: '¿Cuánto gasté en ${top.category}?',
          ),
        );
      }
      if (insights.changeVsPrevious > 0.1) {
        final percent = (insights.changeVsPrevious * 100).round();
        offers.add(
          Offer(
            id: 'dyn_budget',
            title: 'Tu gasto subió $percent%',
            description: 'Define un presupuesto y te avisamos al acercarte '
                'al límite.',
            priority: 2,
            ctaLabel: 'Ver análisis',
            ctaAction: 'Muéstrame mi análisis del mes',
          ),
        );
      } else if (insights.income.minorUnits > 0 && insights.savingsRate < 0.1) {
        offers.add(
          Offer(
            id: 'dyn_savings',
            title: 'Ahorra de forma automática',
            description: 'Tu tasa de ahorro es '
                '${(insights.savingsRate * 100).round()}%. Podemos apartar '
                'el 10% de tus ingresos.',
            priority: 2,
            ctaLabel: '¿Cómo van mis ahorros?',
            ctaAction: '¿Cómo van mis ahorros?',
          ),
        );
      }
      if (insights.topMerchants.isNotEmpty) {
        final merchant = insights.topMerchants.first;
        offers.add(
          Offer(
            id: 'dyn_loyalty',
            title: 'Premia tu lealtad en ${merchant.merchant}',
            description: 'Acumulas ${merchant.amount.format()} aquí este mes.',
            priority: 3,
            ctaLabel: 'Ver mis movimientos',
            ctaAction: 'Muéstrame mis últimos movimientos',
          ),
        );
      }
      return offers;
    } catch (_) {
      return const [];
    }
  }

  String _behaviorTitle(String category) => switch (category) {
        'groceries' => 'Cashback en tu supermercado',
        'dining' => 'Recompensas en restaurantes',
        'transport' => 'Ahorra en tus traslados',
        'utilities' => 'Optimiza tus servicios',
        'entertainment' => 'Disfruta con descuentos',
        'shopping' => 'Compras inteligentes',
        'health' => 'Bienestar con beneficios',
        'housing' => 'Tu vivienda, mejor',
        _ => 'Beneficio según tus hábitos',
      };

  String _behaviorTip(String category) => switch (category) {
        'groceries' => 'Tu tarjeta acumula 3% en compras del día a día.',
        'dining' => '3% de cashback en restaurantes este mes.',
        'transport' => 'Convierte tus puntos en saldo para combustible.',
        'utilities' => 'Domicilia tus pagos y evita comisiones.',
        'entertainment' => '2x1 en plataformas de streaming aliadas.',
        'shopping' => 'Cuotas sin interés en comercios aliados.',
        'health' => 'Descuentos en farmacias y seguros.',
        'housing' => 'Financia mejoras con tasa preferencial.',
        _ => 'Conoce los beneficios de tu segmento.',
      };

  AppThemeConfig _themeFor(UserSegment segment) {
    final seed = switch (segment) {
      UserSegment.youth => '#00C2A8',
      UserSegment.standard => '#0F62FE',
      UserSegment.premium => '#1B1B3A',
      UserSegment.pyme => '#0B7285',
    };
    return AppThemeConfig(
      brandName: 'Neobank',
      seedColorHex: seed,
      mode: 'system',
    );
  }
}
