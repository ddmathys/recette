import 'package:flutter/material.dart';

import '../habits.dart';
import '../meal_types.dart';
import '../models.dart';
import '../services/meal_log_service.dart';
import '../theme.dart';

/// Nombre d'habitudes visibles avant « Voir les autres ».
const _kTop = 3;

/// Écran « + » d'un créneau du dashboard : d'abord MES habitudes — tout ce
/// que j'ai déjà noté, quel que soit le créneau (le yaourt de la collation
/// sert aussi au petit-déj), celles de ce créneau en tête, les 3 premières
/// puis le reste à déplier. Chacune se note en 1 tap, ou avec des calories
/// saisies à la main (✎). La recherche fouille habitudes et recettes,
/// toujours avec kcal + macros. Mirrors AddToSlotSheet.tsx.
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

  /// Ouvre la fiche (ingrédients, étapes) par-dessus cet écran.
  final ValueChanged<Recipe> onViewRecipe;

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
    required this.onViewRecipe,
  });

  @override
  State<AddToSlotScreen> createState() => _AddToSlotScreenState();
}

class _AddToSlotScreenState extends State<AddToSlotScreen> {
  final _mealLogs = MealLogService();
  late final MealSlot _meta = mealSlot(widget.slot);
  late final List<(Habit, int)> _habits = slotHabits(widget.logs, widget.ownerUid, widget.slot);
  late final Map<String, Recipe> _byId = {for (final r in widget.recipes) r.id: r};
  late final Map<String, Recipe> _byName = {for (final r in widget.recipes) r.name.trim().toLowerCase(): r};
  final _searchCtrl = TextEditingController();
  String _search = '';
  bool _showAll = false;
  bool _manual = false;
  final _added = <(String, num)>[];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Recette d'une habitude : par son lien, sinon par le nom (les repas
  /// notés par photo ou description n'ont pas de recipeId mais portent
  /// souvent le nom exact d'une recette de la bibliothèque).
  Recipe? _recipeFor(Habit h) => (h.recipeId != null ? _byId[h.recipeId] : null) ?? _byName[h.label.toLowerCase()];

  int _doneCount(String label) => _added.where((a) => a.$1 == label).length;

  Future<void> _add(MealLogDraft draft, String source) => _mealLogs.addMealLog(
    draft,
    source: source,
    ownerUid: widget.ownerUid,
    ownerName: widget.ownerName,
    householdId: widget.householdId,
  );

  Future<void> _logHabit(Habit h, int count) async {
    await _add(h.toDraft(count, widget.slot, eatenAtFor(widget.day, widget.slot)), h.recipeId != null ? 'recipe' : 'manual');
    if (mounted) setState(() => _added.add((h.label, (h.kcal * count).round())));
  }

  Future<void> _logRecipe(Recipe r, double portions) async {
    final n = r.nutrition;
    if (n == null) {
      widget.onOpenRecipe(r);
      return;
    }
    await _add(
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
      'recipe',
    );
    if (mounted) setState(() => _added.add((r.name, (n.kcal * portions).round())));
  }

  Future<void> _logManual(String label, _Macros m) async {
    await _add(
      MealLogDraft(
        recipeId: null,
        label: label,
        mealType: widget.slot,
        eatenAt: eatenAtFor(widget.day, widget.slot),
        portionGrams: 0,
        kcal: m.kcal,
        proteinG: m.proteinG,
        carbsG: m.carbsG,
        fatG: m.fatG,
      ),
      'manual',
    );
    if (mounted) {
      setState(() {
        _added.add((label, m.kcal));
        _manual = false;
      });
    }
  }

  Widget _habitRow((Habit, int) e) => _HabitRow(
    key: ValueKey(e.$1.label.toLowerCase()),
    habit: e.$1,
    inSlot: e.$2,
    slotLabel: _meta.short.toLowerCase(),
    recipe: _recipeFor(e.$1),
    done: _doneCount(e.$1.label),
    onLog: _logHabit,
    onViewRecipe: widget.onViewRecipe,
  );

  @override
  Widget build(BuildContext context) {
    final isToday = isSameDay(widget.day, DateTime.now());
    final totalAdded = _added.fold<num>(0, (a, x) => a + x.$2);
    final q = _search.trim().toLowerCase();
    final foundHabits = q.isEmpty ? <(Habit, int)>[] : _habits.where((e) => e.$1.label.toLowerCase().contains(q)).toList();
    // Une recette déjà proposée comme habitude n'apparaît pas deux fois.
    final shownIds = {for (final e in foundHabits) _recipeFor(e.$1)?.id};
    final foundRecipes = q.isEmpty
        ? <Recipe>[]
        : (widget.recipes
              .where((r) => !shownIds.contains(r.id))
              .where((r) => r.name.toLowerCase().contains(q) || r.ingr.any((i) => i.name.toLowerCase().contains(q)))
              .toList()
            ..sort((a, b) {
              final c = (a.nutrition == null ? 1 : 0) - (b.nutrition == null ? 1 : 0);
              return c != 0 ? c : a.name.toLowerCase().compareTo(b.name.toLowerCase());
            }));
    final visible = _showAll ? _habits : _habits.take(_kTop).toList();

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
            TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Chercher dans mes habitudes et recettes…',
                prefixIcon: Icon(Icons.search, size: 20, color: AppColors.accent),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
            const SizedBox(height: 12),
            _Card(
              children: q.isNotEmpty
                  ? [
                      if (foundHabits.isEmpty && foundRecipes.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Rien ne correspond — essaie « Décrire » ou « À la main » ci-dessous.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.inkSoft, fontSize: 13),
                          ),
                        ),
                      if (foundHabits.isNotEmpty) ...[const _SectionTitle('MES HABITUDES'), ...foundHabits.map(_habitRow)],
                      if (foundRecipes.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        const _SectionTitle('DANS MES RECETTES'),
                        for (final r in foundRecipes)
                          _RecipeRow(
                            key: ValueKey(r.id),
                            recipe: r,
                            done: _doneCount(r.name),
                            onLog: (p) => _logRecipe(r, p),
                            onView: () => widget.onViewRecipe(r),
                          ),
                      ],
                    ]
                  : [
                      const _SectionTitle('MES HABITUDES'),
                      if (_habits.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            'Rien encore noté. Ajoute un premier repas ci-dessous : il apparaîtra ici pour être renoté en un tap.',
                            style: TextStyle(color: AppColors.inkSoft, fontSize: 13),
                          ),
                        )
                      else ...[
                        const Text(
                          "Touche la quantité : c'est noté. ✎ pour mettre tes propres calories.",
                          style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
                        ),
                        const SizedBox(height: 4),
                        ...visible.map(_habitRow),
                        if (_habits.length > _kTop)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: TextButton(
                              onPressed: () => setState(() => _showAll = !_showAll),
                              style: TextButton.styleFrom(backgroundColor: AppColors.surface2, foregroundColor: AppColors.inkSoft),
                              child: Text(
                                _showAll ? 'Réduire' : 'Voir mes ${_habits.length - _kTop} autres habitudes ▾',
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                      ],
                    ],
            ),
            const SizedBox(height: 12),

            // ── Autre chose ────────────────────────────────────────
            _Card(
              children: [
                const _SectionTitle('AUTRE CHOSE'),
                const SizedBox(height: 6),
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
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SmallTile(
                        emoji: '✍️',
                        title: 'Décrire',
                        subtitle: "l'IA estime",
                        color: AppColors.accent2.withValues(alpha: 0.12),
                        textColor: AppColors.ink,
                        onTap: widget.onDescribe,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SmallTile(
                        emoji: '🔢',
                        title: 'À la main',
                        subtitle: 'mes calories',
                        color: AppColors.herb.withValues(alpha: _manual ? 0.2 : 0.1),
                        textColor: AppColors.ink,
                        onTap: () => setState(() => _manual = !_manual),
                      ),
                    ),
                  ],
                ),
                if (_manual) _ManualEntry(onSave: _logManual),
              ],
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

class _Macros {
  int kcal, proteinG, carbsG, fatG;
  _Macros(this.kcal, this.proteinG, this.carbsG, this.fatG);
}

String _macroLine(num kcal, num p, num g, num l) => '${kcal.round()} kcal · P ${p.round()} · G ${g.round()} · L ${l.round()}';

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
  );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      text,
      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.inkSoft),
    ),
  );
}

class _QtyButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool active;
  const _QtyButton(this.label, this.onTap, {this.active = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(38, 36),
        padding: EdgeInsets.zero,
        foregroundColor: active ? AppColors.accent : AppColors.ink,
        side: BorderSide(color: active ? AppColors.accent : AppColors.line, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
    ),
  );
}

Widget _doneBadge(int done) => done > 0
    ? Padding(
        padding: const EdgeInsets.only(right: 2),
        child: Text(
          done > 1 ? '✓×$done' : '✓',
          style: const TextStyle(color: AppColors.herb, fontWeight: FontWeight.w800, fontSize: 12.5),
        ),
      )
    : const SizedBox.shrink();

/// Une habitude : macros à l'unité, lien vers sa recette, ×1–×3, et ✎ pour
/// corriger les calories avant de noter (le repas noté porte alors ces
/// valeurs, que l'habitude reprend la fois suivante).
class _HabitRow extends StatefulWidget {
  final Habit habit;
  final int inSlot;
  final String slotLabel;
  final Recipe? recipe;
  final int done;
  final Future<void> Function(Habit, int) onLog;
  final ValueChanged<Recipe> onViewRecipe;

  const _HabitRow({
    super.key,
    required this.habit,
    required this.inSlot,
    required this.slotLabel,
    required this.recipe,
    required this.done,
    required this.onLog,
    required this.onViewRecipe,
  });

  @override
  State<_HabitRow> createState() => _HabitRowState();
}

class _HabitRowState extends State<_HabitRow> {
  bool _editing = false;
  bool _busy = false;
  late final _Macros _m = _Macros(
    widget.habit.kcal.round(),
    widget.habit.proteinG.round(),
    widget.habit.carbsG.round(),
    widget.habit.fatG.round(),
  );

  Future<void> _log(int count) async {
    final h = widget.habit;
    setState(() => _busy = true);
    try {
      await widget.onLog(
        _editing ? h.withMacros(kcal: _m.kcal, proteinG: _m.proteinG, carbsG: _m.carbsG, fatG: _m.fatG) : h,
        count,
      );
      if (mounted) setState(() => _editing = false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.habit;
    final r = widget.recipe;
    final line = _editing
        ? _macroLine(_m.kcal, _m.proteinG, _m.carbsG, _m.fatG)
        : _macroLine(h.kcal, h.proteinG, h.carbsG, h.fatG);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(h.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5), maxLines: 2),
                    Text(
                      '$line / unité',
                      style: const TextStyle(fontSize: 11, color: AppColors.inkSoft),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        Text(
                          widget.inSlot > 0 ? '${widget.inSlot}× au ${widget.slotLabel}' : 'noté ${h.times}×',
                          style: const TextStyle(fontSize: 10.5, color: AppColors.inkSoft),
                        ),
                        if (r != null)
                          GestureDetector(
                            onTap: () => widget.onViewRecipe(r),
                            child: const Text(
                              ' · 📖 Recette',
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.accent),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              _doneBadge(widget.done),
              for (final n in const [1, 2, 3]) _QtyButton('×$n', _busy ? null : () => _log(n)),
              _QtyButton('✎', () => setState(() => _editing = !_editing), active: _editing),
            ],
          ),
          if (_editing)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _MacroInputs(value: _m, onChanged: () => setState(() {})),
                  const SizedBox(height: 6),
                  const Text(
                    'Par unité — touche ×1, ×2 ou ×3 pour noter avec ces valeurs.',
                    style: TextStyle(fontSize: 11, color: AppColors.inkSoft),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Une recette trouvée par la recherche : macros par portion, ½/×1/×2.
class _RecipeRow extends StatefulWidget {
  final Recipe recipe;
  final int done;
  final Future<void> Function(double) onLog;
  final VoidCallback onView;

  const _RecipeRow({super.key, required this.recipe, required this.done, required this.onLog, required this.onView});

  @override
  State<_RecipeRow> createState() => _RecipeRowState();
}

class _RecipeRowState extends State<_RecipeRow> {
  bool _busy = false;

  Future<void> _log(double p) async {
    setState(() => _busy = true);
    try {
      await widget.onLog(p);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.recipe.nutrition;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.recipe.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5), maxLines: 2),
                Text(
                  n != null
                      ? '${_macroLine(n.kcal, n.proteinG, n.carbsG, n.fatG)} / portion'
                      : "pas encore d'estimation — « Estimer » la calcule",
                  style: const TextStyle(fontSize: 11, color: AppColors.inkSoft),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                GestureDetector(
                  onTap: widget.onView,
                  child: const Text(
                    '📖 Recette',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.accent),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          _doneBadge(widget.done),
          if (n != null)
            for (final p in const [0.5, 1.0, 2.0]) _QtyButton(p == 0.5 ? '½' : '×${p.round()}', _busy ? null : () => _log(p))
          else
            OutlinedButton(
              onPressed: () => widget.onLog(1),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 36),
                foregroundColor: AppColors.inkSoft,
                side: const BorderSide(color: AppColors.line, width: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              child: const Text('Estimer', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
            ),
        ],
      ),
    );
  }
}

/// Kcal + macros saisis à la main. Modifie `value` en place.
class _MacroInputs extends StatelessWidget {
  final _Macros value;
  final VoidCallback onChanged;
  const _MacroInputs({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget field(String label, int initial, void Function(int) set) => Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: TextFormField(
          initialValue: initial > 0 ? '$initial' : '',
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: label, isDense: true),
          style: const TextStyle(fontSize: 14),
          onChanged: (v) {
            set(double.tryParse(v.trim().replaceAll(',', '.'))?.round() ?? 0);
            onChanged();
          },
        ),
      ),
    );
    return Row(
      children: [
        field('Kcal', value.kcal, (v) => value.kcal = v),
        field('Prot. g', value.proteinG, (v) => value.proteinG = v),
        field('Gluc. g', value.carbsG, (v) => value.carbsG = v),
        field('Lip. g', value.fatG, (v) => value.fatG = v),
      ],
    );
  }
}

/// Saisie libre : un nom + ses calories, sans IA. Une fois noté, il
/// rejoint « Mes habitudes ».
class _ManualEntry extends StatefulWidget {
  final Future<void> Function(String, _Macros) onSave;
  const _ManualEntry({required this.onSave});

  @override
  State<_ManualEntry> createState() => _ManualEntryState();
}

class _ManualEntryState extends State<_ManualEntry> {
  final _label = TextEditingController();
  final _m = _Macros(0, 0, 0, 0);
  bool _busy = false;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await widget.onSave(_label.text.trim(), _m);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ok = _label.text.trim().isNotEmpty && _m.kcal > 0;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _label,
            decoration: const InputDecoration(hintText: 'Ex. Yaourt nature', isDense: true),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          _MacroInputs(value: _m, onChanged: () => setState(() {})),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: !ok || _busy ? null : _save,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.herb, foregroundColor: Colors.white),
            child: Text(_m.kcal > 0 ? 'Noter · ${_m.kcal} kcal' : 'Noter', style: const TextStyle(fontWeight: FontWeight.w800)),
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
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 6),
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textColor)),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: textColor == Colors.white ? Colors.white70 : AppColors.inkSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
