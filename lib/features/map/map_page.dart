import 'package:flutter/material.dart';
import 'package:kameo_engine/kameo_engine.dart';

import '../../core/kameo_scope.dart';
import '../../core/session.dart';
import '../../core/theme/kameo_colors.dart';
import '../../core/widgets/k_button.dart';
import 'city_sheet.dart';
import 'country_map.dart';

/// L'écran signature : la carte du voyage.
///
/// C'est lui qui doit donner envie sans explication. Villes validées, ville en
/// cours, villes verrouillées, itinéraire, et le bandeau de passeport toujours
/// visible.
class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    final KameoSession session = KameoScope.of(context);
    final Country? country = session.country;
    final TextTheme text = Theme.of(context).textTheme;

    if (country == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final City? current = session.currentCity;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(KSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('TON VOYAGE', style: text.labelSmall),
                        Text(
                          '${country.shortName} · Tour ${session.currentTour}',
                          style: text.headlineMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: KSpace.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: KColors.creuse,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text('✨ ${session.xp} XP', style: text.labelSmall),
                  ),
                ],
              ),
              const SizedBox(height: KSpace.md),
              _MapCard(country: country, session: session),
              const SizedBox(height: KSpace.md),
              _PassportStrip(country: country, session: session),
              const SizedBox(height: KSpace.md),
              if (current != null)
                _CurrentStep(
                  city: current,
                  onOpen: () => CitySheet.show(context, current),
                ),
              const SizedBox(height: KSpace.md),
              Container(
                padding: const EdgeInsets.all(KSpace.md),
                decoration: BoxDecoration(
                  color: KColors.creuse,
                  borderRadius: BorderRadius.circular(KSpace.radiusCard),
                ),
                child: Row(
                  children: <Widget>[
                    Text(country.flag, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: KSpace.sm),
                    Expanded(
                      child: Text(
                        country.note,
                        style: text.bodyMedium?.copyWith(fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapCard extends StatelessWidget {
  const _MapCard({required this.country, required this.session});

  final Country country;
  final KameoSession session;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(KSpace.sm),
      decoration: BoxDecoration(
        color: KColors.creuse,
        borderRadius: BorderRadius.circular(KSpace.radiusCard),
        border: Border.all(color: KColors.trait),
      ),
      child: AspectRatio(
        aspectRatio: 1,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final Size size = Size(
              constraints.maxWidth,
              constraints.maxHeight,
            );
            return Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned.fill(
                  child: CustomPaint(
                    painter: CountryMapPainter(
                      country: country,
                      doneCount: session.stamps.length,
                    ),
                  ),
                ),
                for (final City city in country.cities)
                  _CityPin(
                    city: city,
                    size: size,
                    done: session.isDone(city),
                    current: session.currentCity?.id == city.id,
                    locked: session.isLocked(city),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CityPin extends StatelessWidget {
  const _CityPin({
    required this.city,
    required this.size,
    required this.done,
    required this.current,
    required this.locked,
  });

  final City city;
  final Size size;
  final bool done;
  final bool current;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    const double dot = 22;
    final double cx = city.position.x / 100 * size.width;
    final double cy = city.position.y / 100 * size.height;
    final Color fill = done
        ? KColors.lagon
        : current
            ? KColors.corail
            : KColors.traitFort;
    final bool labelAbove = city.labelOffset < 0;

    return Positioned(
      left: cx - 50,
      top: cy - (labelAbove ? 30 : dot / 2),
      width: 100,
      child: Column(
        children: <Widget>[
          if (labelAbove) _label(context),
          Semantics(
            button: !locked,
            label: '${city.name}, ${city.theme}',
            child: GestureDetector(
              onTap: locked ? null : () => CitySheet.show(context, city),
              child: Container(
                width: dot,
                height: dot,
                decoration: BoxDecoration(
                  color: fill,
                  shape: BoxShape.circle,
                  border: Border.all(color: KColors.creme, width: 2.5),
                  boxShadow: current
                      ? <BoxShadow>[
                          BoxShadow(
                            color: KColors.corail.withValues(alpha: 0.35),
                            blurRadius: 12,
                            spreadRadius: 4,
                          ),
                        ]
                      : null,
                ),
                child: done
                    ? const Icon(Icons.check, size: 13, color: Colors.white)
                    : locked
                        ? const Icon(Icons.lock, size: 11, color: Colors.white)
                        : null,
              ),
            ),
          ),
          if (!labelAbove) _label(context),
        ],
      ),
    );
  }

  Widget _label(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: city.labelOffset < 0 ? 3 : 0, top: 3),
        child: Text(
          city.name,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 12,
                color: locked ? KColors.encreDouce : KColors.encre,
              ),
        ),
      );
}

class _PassportStrip extends StatelessWidget {
  const _PassportStrip({required this.country, required this.session});

  final Country country;
  final KameoSession session;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KSpace.md,
        vertical: KSpace.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(KSpace.radiusCard),
        border: Border.all(color: KColors.trait),
      ),
      child: Row(
        children: <Widget>[
          Text('TOUR ${session.currentTour}', style: text.labelSmall),
          const SizedBox(width: KSpace.sm),
          // Le nombre de villes va grandir : on met les pastilles à l'échelle
          // plutôt que de laisser la rangée déborder.
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                children: <Widget>[
                  for (final City c in country.cities)
                    Padding(
                      padding: const EdgeInsets.only(right: 5),
                      child: Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: session.isDone(c)
                              ? KColors.soleil.withValues(alpha: 0.28)
                              : null,
                          border: Border.all(
                            color: session.isDone(c)
                                ? KColors.soleil
                                : KColors.traitFort,
                            width: session.isDone(c) ? 2 : 1.2,
                          ),
                        ),
                        child: session.isDone(c)
                            ? Text(
                                c.emoji,
                                style: const TextStyle(fontSize: 10),
                              )
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: KSpace.xs),
          Text(
            '${session.stamps.length}/${country.cities.length}',
            style: text.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _CurrentStep extends StatelessWidget {
  const _CurrentStep({required this.city, required this.onOpen});

  final City city;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(KSpace.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(KSpace.radiusCard),
        border: Border.all(color: KColors.trait),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('ÉTAPE EN COURS', style: text.labelSmall),
          const SizedBox(height: KSpace.xs),
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(city.name, style: text.headlineMedium),
                    Text(
                      city.theme,
                      style: text.bodyMedium?.copyWith(
                        fontSize: 13,
                        color: KColors.encreDouce,
                      ),
                    ),
                  ],
                ),
              ),
              Text(city.emoji, style: const TextStyle(fontSize: 34)),
            ],
          ),
          const SizedBox(height: KSpace.md),
          KButton(label: 'Découvrir la ville', onPressed: onOpen),
        ],
      ),
    );
  }
}
