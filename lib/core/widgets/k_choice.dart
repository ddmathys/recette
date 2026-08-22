import 'package:flutter/material.dart';

import '../theme/kameo_colors.dart';

/// Une carte de choix : emoji, titre, sous-titre.
///
/// C'est la brique de tout l'onboarding — assez grande pour le pouce, assez
/// claire pour un enfant de huit ans.
class KChoice extends StatelessWidget {
  const KChoice({
    required this.emoji,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final String emoji;
  final String title;
  final String? subtitle;
  final String? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(KSpace.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KSpace.radiusCard),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(KSpace.radiusCard),
            border: Border.all(color: KColors.trait, width: 1.5),
          ),
          padding: const EdgeInsets.all(KSpace.md),
          child: Row(
            children: <Widget>[
              Text(emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: KSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: text.titleMedium),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: text.bodyMedium?.copyWith(
                          fontSize: 13,
                          color: KColors.encreDouce,
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: KColors.creuse,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    trailing!,
                    style: text.labelSmall?.copyWith(letterSpacing: 0.5),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
