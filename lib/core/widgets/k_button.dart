import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/kameo_colors.dart';

/// Le bouton Kameo : plein, arrondi, avec l'ombre portée qui s'écrase à
/// l'appui. C'est ce retour tactile qui donne le côté « jeu ».
class KButton extends StatefulWidget {
  const KButton({
    required this.label,
    required this.onPressed,
    this.color = KColors.corail,
    this.shadow = KColors.corailOmbre,
    this.enabled = true,
    this.ghost = false,
    super.key,
  });

  /// La variante discrète : bordure, pas de fond, pas d'ombre portée.
  ///
  /// Elle sert aux actions secondaires qui doivent rester de vrais boutons —
  /// « je préfère commencer au début » n'est pas un lien gris (doc 03 §4.3).
  const KButton.ghost({
    required this.label,
    required this.onPressed,
    this.enabled = true,
    super.key,
  }) : color = KColors.trait,
       shadow = KColors.creuse,
       ghost = true;

  /// La variante d'action positive (valider, continuer le voyage).
  const KButton.go({
    required this.label,
    required this.onPressed,
    this.enabled = true,
    super.key,
  }) : color = KColors.lagon,
       shadow = KColors.lagonOmbre,
       ghost = false;

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color shadow;
  final bool enabled;
  final bool ghost;

  @override
  State<KButton> createState() => _KButtonState();
}

class _KButtonState extends State<KButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final bool active = widget.enabled && widget.onPressed != null;
    return Semantics(
      button: true,
      enabled: active,
      label: widget.label,
      child: GestureDetector(
        onTapDown: active ? (_) => setState(() => _down = true) : null,
        onTapCancel: active ? () => setState(() => _down = false) : null,
        onTap: active
            ? () {
                setState(() => _down = false);
                HapticFeedback.lightImpact();
                widget.onPressed!.call();
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          transform: Matrix4.translationValues(0, _down && !widget.ghost ? 3 : 0, 0),
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 18),
          decoration: BoxDecoration(
            color: active ? widget.color : KColors.trait,
            borderRadius: BorderRadius.circular(KSpace.radius),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: active ? widget.shadow : KColors.creuse,
                offset: Offset(0, _down ? 1 : 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              widget.label,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
