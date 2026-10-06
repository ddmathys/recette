import 'package:flutter/material.dart';

import '../habits.dart';
import '../meal_types.dart';
import '../models.dart';
import '../services/meal_log_service.dart';
import '../theme.dart';
import '../widgets/habits_list.dart';

/// Écran « + » d'un créneau du dashboard : tout ce qu'on peut y mettre, du
/// plus rapide au plus long — les habituels déjà notés (1 tap), les
/// recettes de la bibliothèque (recherche + portion), puis photo /
/// description pour un plat inconnu. Chaque ajout est noté sur le jour
/// affiché au dashboard et dans ce créneau. Mirrors AddToSlotSheet.tsx.
class AddToSlotScreen extends StatefulWidget {
  final String slot;
  final DateTime day;
  final List<Recipe> recipes;
  final List<MealLog> logs;
  final String ownerUid;
  final String ownerName;
  final String householdId;

  /// Photo d'assiette → analyse IA, notée dans ce créneau.
  final VoidCallback onPhoto;

  /// Description libre → estimation IA, notée dans ce créneau.
  final VoidCallback onDescribe;

  /// Recette sans estimation : on passe par l'écran résultat complet.
  final ValueChanged<Recipe> onOpenRecipe;
  final VoidCallback onOpenLibrary;

  const AddToSlotScreen({
    super.key,
    required this.slot,
    required this.day,
    required this.recipes,
    required this.logs,
    required this.ownerUid,
    required this.ownerName,
    required this.householdId,
    required this.onPhoto,
    required this.onDescribe,
    required this.onOpenRecipe,
    required this.onOpenLibrary,
  });

  @override
  State<AddToSlotScreen> createState() => _AddToSlotScreenState();
}

class _AddToSlotScreenState extends State<AddToSlotScreen> {
  final _mealLogs = MealLogService();
  late final MealSlot _meta = mealSlot(widget.slot);
  late final List<Habit> _habits = computeHabits(widget.logs, widget.ownerUid, mealType: widget.slot, limit: 6);
  final _searchCtrl = TextEditingController();
  String _search = '';
  bool _showAll = false;
  final _added = <(String, num)>[];
  String? _busy;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Les recettes du créneau d'abord (petit-déjeuner le matin, apéro ou
  /// dessert pour une collation…), puis par ordre alphabétique.
  List<Recipe> get _list {
    final q = _search.trim().toLowerCase();
    final list = widget.recipes.where((r) {
      if (q.isEmpty) return true;
      return r.name.toLowerCase().contains(q) || r.ingr.any((i) => i.name.toLowerCase().contains(q));
    }).toList();
    list.sort((a, b) {
      double score(Recipe r) => (_meta.cats.contains(r.cat) ? 0 : 1) + (r.nutrition != null ? 0 : 0.5);
      final c = score(a).compareTo(score(b));
      return c != 0 ? c : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  Future<void> _logHabit(Habit h, int count) async {
    await _mealLogs.addMealLog(
      h.toDraft(count, widget.slot, eatenAtFor(widget.day, widget.slot)),
      source: h.recipeId != null ? 'recipe' : 'manual',
      ownerUid: widget.ownerUid,
      ownerName: widget.ownerName,
      householdId: widget.householdId,
    );
    if (mounted) setState(() => _added.add((h.label, (h.kcal * count).round())));
  }

  Future<void> _logRecipe(Recipe r, double portions) async {
    final n = r.nutrition;
    if (n == null) {
      widget.onOpenRecipe(r);
      return;
    }
    setState(() => _busy = r.id);
    try {
      await _mealLogs.addMealLog(
        MealLogDraft(
          recipeId: r.id,
          label: r.name,
          mealType: widget.slot,
          eatenAt: eatenAtFor(widget.day, widget.slot),
          portionGrams: (n.gramsPerServing * portions).round(),
          kcal: (n.kcal * portions).round(),
          proteinG: (n.proteinG * portions).round(),
          carbsG: (n.carbsG * portions).round(),
          fatG: (n.fatG * portions).round(),
          count: portions == 1 ? null : portions,
        ),
        source: 'recipe',
        ownerUid: widget.ownerUid,
        ownerName: widget.ownerName,
        householdId: widget.householdId,
      );
      if (mounted) setState(() => _added.add((r.name, (n.kcal * portions).round())));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isToday = isSameDay(widget.day, DateTime.now());
    final list = _list;
    final shown = _showAll ? list : list.take(6).toList();
    final totalAdded = _added.fold<num>(0, (a, x) => a + x.$2);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: _meta.color.withValues(alpha: 0.14), shape: BoxShape.circle),
              child: Text(_meta.emoji, style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(_meta.label, overflow: TextOverflow.ellipsis)),
          ],
        ),
        actions: [
          if (!isToday)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                label: Text('📅 ${dayLabel(widget.day)}'),
                backgroundColor: AppColors.gold.withValues(alpha: 0.15),
                labelStyle: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700),
                side: BorderSide.none,
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            HabitsList(habits: _habits, onLog: _logHabit),

            // ── Depuis mes recettes ────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'DEPUIS MES RECETTES',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.inkSoft),
                      ),
                      GestureDetector(
                        onTap: widget.onOpenLibrary,
                        child: const Text(
                          'Tout voir ›',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.accent),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Chercher une recette, un ingrédient…',
                      prefixIcon: Icon(Icons.search, size: 20, color: AppColors.accent),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                  const SizedBox(height: 4),
                  if (list.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        widget.recipes.isEmpty
                            ? 'Aucune recette encore — ajoute-les depuis « Mes recettes ».'
                            : 'Aucune recette ne correspond.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.inkSoft, fontSize: 13),
                      ),
                    )
                  else
                    for (final r in shown)
                      _RecipeRow(
                        recipe: r,
                        addedTimes: _added.where((a) => a.$1 == r.name).length,
                        busy: _busy != null,
                        onLog: (p) => _logRecipe(r, p),
                        onOpen: () => widget.onOpenRecipe(r),
                      ),
                  if (!_showAll && list.length > 6)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextButton(
                        onPressed: () => setState(() => _showAll = true),
                        style: TextButton.styleFrom(backgroundColor: AppColors.surface2, foregroundColor: AppColors.inkSoft),
                        child: Text('Voir les ${list.length - 6} autres', style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Autre chose ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'AUTRE CHOSE',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _SmallTile(
                          emoji: '📸',
                          title: 'Photo',
                          subtitle: 'de mon assiette',
                          color: AppColors.accent,
                          textColor: Colors.white,
                          onTap: widget.onPhoto,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SmallTile(
                          emoji: '✍️',
                          title: 'Décrire',
                          subtitle: '« 2 crêpes, un café »',
                          color: AppColors.accent2.withValues(alpha: 0.12),
                          textColor: AppColors.ink,
                          onTap: widget.onDescribe,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      // Récapitulatif collant : ce que ce passage a ajouté.
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: const BoxDecoration(
            color: AppColors.bg,
            border: Border(top: BorderSide(color: AppColors.line)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _added.isEmpty
                    ? const Text(
                        "Touche une quantité : c'est noté tout de suite.",
                        style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
                      )
                    : Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '✓ ${_added.length} ajout${_added.length > 1 ? "s" : ""}',
                              style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.herb),
                            ),
                            const TextSpan(text: ' · '),
                            TextSpan(
                              text: '${totalAdded.round()} kcal',
                              style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800),
                            ),
                          ],
                          style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _added.isEmpty ? AppColors.surface : AppColors.herb,
                  foregroundColor: _added.isEmpty ? AppColors.ink : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(_added.isEmpty ? 'Fermer' : 'Terminé', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecipeRow extends StatelessWidget {
  final Recipe recipe;
  final int addedTimes;
  final bool busy;
  final ValueChanged<double> onLog;
  final VoidCallback onOpen;

  const _RecipeRow({
    required this.recipe,
    required this.addedTimes,
    required this.busy,
    required this.onLog,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final n = recipe.nutrition;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(recipe.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5), maxLines: 2),
                Text(
                  n != null
                      ? '${n.kcal.round()} kcal / portion · P ${n.proteinG.round()} · G ${n.carbsG.round()} · L ${n.fatG.round()}'
                      : "pas encore d'estimation — touche pour la calculer",
                  style: const TextStyle(fontSize: 11, color: AppColors.inkSoft),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (addedTimes > 0 && !busy)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: AppColors.herb.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
              child: Text(
                addedTimes > 1 ? '✓ Ajouté ×$addedTimes' : '✓ Ajouté',
                style: const TextStyle(color: AppColors.herb, fontWeight: FontWeight.w800, fontSize: 12.5),
              ),
            )
          else if (n != null)
            Row(
              children: [
                for (final p in const [0.5, 1.0, 2.0])
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: OutlinedButton(
                      onPressed: busy ? null : () => onLog(p),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(40, 38),
                        padding: EdgeInsets.zero,
                        foregroundColor: AppColors.ink,
                        side: const BorderSide(color: AppColors.line, width: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      ),
                      child: Text(
                        p == 0.5 ? '½' : '×${p.round()}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ),
                  ),
              ],
            )
          else
            OutlinedButton(
              onPressed: onOpen,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 38),
                foregroundColor: AppColors.inkSoft,
                side: const BorderSide(color: AppColors.line, width: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              child: const Text('Ouvrir', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
            ),
        ],
      ),
    );
  }
}

class _SmallTile extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const _SmallTile({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 6),
              Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textColor)),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11.5, color: textColor == Colors.white ? Colors.white70 : AppColors.inkSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
