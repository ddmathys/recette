import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../meal_types.dart';
import '../models.dart';
import '../services/ai_service.dart';
import '../services/meal_log_service.dart';
import '../services/recipe_service.dart';
import '../habits.dart';
import '../theme.dart';
import '../widgets/habits_list.dart';

/// "meal" = assiette photographiée (1 personne, pas d'étapes) ; "recipe" =
/// recette écrite ou existante (N personnes, étapes).
enum _Kind { meal, recipe }

enum _Stage { choose, describe, text, loading, result }

const _textSuggestions = ['Version plus légère', 'Sans gluten', 'Végétarien', 'Plus rapide'];
const _snackIdeas = [
  'Une pomme',
  'Un yaourt nature',
  'Un carré de chocolat',
  "Une poignée d'amandes",
  'Une banane',
  'Un café au lait',
  'Un biscuit',
  'Une barre de céréales',
];
const _mealSuggestions = ['Portion plus petite', 'Sans la sauce', "J'en ai mangé 2", 'Il y avait aussi du pain'];

Recipe? _recipeById(List<Recipe> recipes, String? id) {
  if (id == null) return null;
  for (final r in recipes) {
    if (r.id == id) return r;
  }
  return null;
}

/// Parcours "Ajouter un repas" : choix photo / texte, puis un écran de
/// résultat commun (calories réparties + ingrédients, et la recette si
/// écrite) qu'on peut itérer par IA avant de le noter comme mangé et/ou de
/// le garder dans la bibliothèque. Mirrors AddMealFlow.tsx on the web —
/// remplace CaptureScreen. `initialRecipe` saute direct au résultat.
/// `day` = jour affiché au dashboard (le repas est noté ce jour-là) ;
/// `snack` ouvre directement "Décrire" avec le type Collation.
class AddMealScreen extends StatefulWidget {
  final List<Recipe> recipes;
  final Recipe? initialRecipe;
  final String ownerUid;
  final String ownerName;
  final String householdId;
  final DateTime day;

  /// 'snack' / 'breakfast' : ouvre direct "Décrire" avec ce type et les
  /// habituels de ce type en premier.
  final String? preset;

  /// Journal de l'utilisateur, pour proposer ses habituels.
  final List<MealLog> logs;

  bool get snack => preset == 'snack';
  String? get presetType => preset == 'snack' ? 'collation' : (preset == 'breakfast' ? 'petit-dej' : null);

  const AddMealScreen({
    required this.day,
    this.preset,
    this.logs = const [],
    super.key,
    required this.recipes,
    this.initialRecipe,
    required this.ownerUid,
    required this.ownerName,
    required this.householdId,
  });

  @override
  State<AddMealScreen> createState() => _AddMealScreenState();
}

class _AddMealScreenState extends State<AddMealScreen> {
  final _ai = AiService();
  final _mealLogs = MealLogService();
  final _recipeService = RecipeService();
  final _queryCtrl = TextEditingController();
  final _describeCtrl = TextEditingController();
  final _instrCtrl = TextEditingController();
  final _scroll = ScrollController();

  late _Stage _stage = widget.initialRecipe != null ? _Stage.result : (widget.preset != null ? _Stage.describe : _Stage.choose);
  late final List<Habit> _habits = computeHabits(
    widget.logs,
    widget.ownerUid,
    mealType: widget.presetType,
    limit: widget.presetType != null ? 8 : 5,
  );
  late final bool _isToday = isSameDay(widget.day, DateTime.now());
  _Kind _kind = _Kind.recipe;
  String? _error;
  String _loadingLabel = '';
  int _persons = 2;

  XFile? _photoFile;
  String? _photoUrl;
  String? _suggestedPhoto;
  String? _source;

  RecipeDraft? _draft;
  String? _matchedRecipeId;
  String? _savedRecipeId;
  bool _iterating = false;
  String? _lastChange;
  late String _mealType = widget.presetType ?? guessMealType();
  double _portions = 1;
  bool _logged = false;
  String? _busy; // 'log' | 'save'

  @override
  void initState() {
    super.initState();
    final r = widget.initialRecipe;
    if (r != null) {
      _draft = RecipeDraft(
        name: r.name,
        cat: r.cat,
        time: r.time,
        diff: r.diff,
        servings: r.servings,
        veg: r.veg,
        ingr: [...r.ingr],
        steps: [...r.steps],
        nutrition: r.nutrition,
      );
      _matchedRecipeId = r.id;
      _savedRecipeId = r.id;
    }
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    _describeCtrl.dispose();
    _instrCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _msg(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> _takePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choisir depuis la galerie'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final file = await ImagePicker().pickImage(source: source, maxWidth: 2400, imageQuality: 85);
    if (file == null) return;
    setState(() {
      _error = null;
      _kind = _Kind.meal;
      _photoFile = file;
      _stage = _Stage.loading;
      _loadingLabel = "J'analyse ton assiette…";
    });
    try {
      final url = await _mealLogs.uploadMealPhoto(widget.ownerUid, file);
      _photoUrl = url;
      final a = await _ai.analyzeMealPhoto(url, widget.recipes);
      final matched = _recipeById(widget.recipes, a.matchedRecipeId);
      NutritionEstimate? nutrition;
      if (a.kcal != null && a.portionGrams != null) {
        nutrition = NutritionEstimate(
          kcal: a.kcal!,
          proteinG: a.proteinG ?? 0,
          carbsG: a.carbsG ?? 0,
          fatG: a.fatG ?? 0,
          gramsPerServing: a.portionGrams!,
          estimatedBy: 'ai',
        );
      }
      if (!mounted) return;
      setState(() {
        _matchedRecipeId = matched?.id;
        _savedRecipeId = matched?.id;
        _draft = RecipeDraft(
          name: (a.label?.trim().isNotEmpty ?? false) ? a.label!.trim() : 'Mon repas',
          cat: a.cat ?? 'viande',
          time: 0,
          servings: 1,
          veg: a.veg,
          ingr: a.ingr,
          steps: [],
          nutrition: nutrition,
        );
        if (a.mealType != null && kMealTypes.any((m) => m.$1 == a.mealType)) _mealType = a.mealType!;
        _stage = _Stage.result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _msg(e);
        _stage = _Stage.choose;
      });
    }
  }

  Future<void> _searchRecipe() async {
    final q = _queryCtrl.text.trim();
    if (q.isEmpty) {
      setState(() => _error = 'Écris le repas que tu veux, par exemple « crêpes ».');
      return;
    }
    FocusScope.of(context).unfocus();
    final isLink = RegExp(r'^https?://\S+$', caseSensitive: false).hasMatch(q);
    setState(() {
      _error = null;
      _kind = _Kind.recipe;
      _stage = _Stage.loading;
      _loadingLabel = 'Je prépare la recette pour $_persons personne${_persons > 1 ? "s" : ""}…';
    });
    try {
      final res = isLink ? await _ai.generate(link: q, servings: _persons) : await _ai.generate(text: q, servings: _persons);
      if (!mounted) return;
      setState(() {
        _draft = res.draft;
        if (_draft!.name.trim().isEmpty) _draft!.name = q;
        _draft!.ingr = _draft!.ingr.where((i) => i.name.trim().isNotEmpty).toList();
        _draft!.steps = _draft!.steps.where((s) => s.trim().isNotEmpty).toList();
        _source = isLink ? q : null;
        _suggestedPhoto = res.ogImage;
        _matchedRecipeId = null;
        _savedRecipeId = null;
        _stage = _Stage.result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _msg(e);
        _stage = _Stage.text;
      });
    }
  }

  Future<void> _describeMeal() async {
    final q = _describeCtrl.text.trim();
    if (q.isEmpty) {
      setState(
        () => _error = widget.snack
            ? 'Écris ce que tu as pris, par exemple « une pomme ».'
            : 'Écris ce que tu as mangé, par exemple « crêpes et poulet sauce soja ».',
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _kind = _Kind.meal;
      _stage = _Stage.loading;
      _loadingLabel = "J'estime ce que tu as mangé…";
    });
    try {
      final d = await _ai.describeMeal(q);
      if (!mounted) return;
      setState(() {
        _draft = d;
        _matchedRecipeId = null;
        _savedRecipeId = null;
        _stage = _Stage.result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _msg(e);
        _stage = _Stage.describe;
      });
    }
  }

  Future<void> _iterate(String text) async {
    final instr = text.trim();
    final draft = _draft;
    if (instr.isEmpty || draft == null) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _iterating = true;
      _error = null;
    });
    try {
      final next = await _ai.edit(draft, instr, meal: _kind == _Kind.meal);
      next.ingr = next.ingr.where((i) => i.name.trim().isNotEmpty).toList();
      next.steps = _kind == _Kind.meal ? [] : next.steps.where((s) => s.trim().isNotEmpty).toList();
      if (_kind == _Kind.meal) next.servings = 1;
      if (!mounted) return;
      setState(() {
        _draft = next;
        // Le contenu a changé : ce n'est plus la recette enregistrée/reconnue.
        _savedRecipeId = null;
        _matchedRecipeId = null;
        _logged = false;
        _lastChange = instr;
        _instrCtrl.clear();
      });
      _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    } catch (e) {
      if (mounted) setState(() => _error = _msg(e));
    } finally {
      if (mounted) setState(() => _iterating = false);
    }
  }

  Future<void> _logMeal() async {
    final draft = _draft;
    if (draft == null) return;
    setState(() {
      _busy = 'log';
      _error = null;
    });
    try {
      final n = draft.nutrition;
      num scaled(num? v) => ((v ?? 0) * _portions).round();
      await _mealLogs.addMealLog(
        MealLogDraft(
          recipeId: _savedRecipeId,
          label: draft.name,
          mealType: _mealType,
          eatenAt: eatenAtFor(widget.day, _mealType),
          portionGrams: scaled(n?.gramsPerServing),
          kcal: scaled(n?.kcal),
          proteinG: scaled(n?.proteinG),
          carbsG: scaled(n?.carbsG),
          fatG: scaled(n?.fatG),
          count: _portions == 1 ? null : _portions,
        ),
        photoUrl: _photoUrl,
        source: _photoUrl != null ? 'photo' : (_savedRecipeId != null ? 'recipe' : 'manual'),
        ownerUid: widget.ownerUid,
        ownerName: widget.ownerName,
        householdId: widget.householdId,
      );
      if (mounted) setState(() => _logged = true);
    } catch (_) {
      if (mounted) setState(() => _error = "L'enregistrement du repas a échoué, réessaie.");
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _saveRecipe() async {
    final draft = _draft;
    if (draft == null) return;
    setState(() {
      _busy = 'save';
      _error = null;
    });
    try {
      if (draft.time <= 0) draft.time = 15;
      final id = await _recipeService.addRecipe(
        draft,
        source: _source,
        photoUrl: _photoFile == null ? _suggestedPhoto : null,
        ownerUid: widget.ownerUid,
        ownerName: widget.ownerName,
        householdId: widget.householdId,
      );
      if (_photoFile != null) {
        // Copie propre de la photo pour la recette : la photo du journal a
        // son propre cycle de vie (supprimée avec le repas).
        try {
          await _recipeService.uploadRecipePhoto(id, _photoFile!);
        } catch (_) {}
      }
      if (mounted) setState(() => _savedRecipeId = id);
    } catch (_) {
      if (mounted) setState(() => _error = "L'enregistrement de la recette a échoué, réessaie.");
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_stage) {
      _Stage.choose => 'Ajouter un repas',
      _Stage.describe => widget.snack ? 'Ajouter un en-cas' : (widget.preset == 'breakfast' ? 'Ajouter un petit-déj' : "Ce que j'ai mangé"),
      _Stage.text => 'Trouver une recette',
      _Stage.loading => 'Un instant…',
      _Stage.result => _draft?.name ?? 'Résultat',
    };
    final backToChoose = widget.preset == null && (_stage == _Stage.text || _stage == _Stage.describe);
    return PopScope(
      canPop: !backToChoose,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && backToChoose) setState(() => _stage = _Stage.choose);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(title, overflow: TextOverflow.ellipsis),
          actions: [
            if (!_isToday)
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
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              ...switch (_stage) {
                _Stage.choose => _buildChoose(),
                _Stage.describe => _buildDescribe(),
                _Stage.text => _buildText(),
                _Stage.loading => _buildLoading(),
                _Stage.result => _buildResult(),
              },
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildChoose() => [
    _BigChoice(
      emoji: '📸',
      title: 'Prendre une photo',
      subtitle: 'Ton assiette (1 personne) → calories détaillées et ingrédients',
      primary: true,
      onTap: _takePhoto,
    ),
    const SizedBox(height: 12),
    _BigChoice(
      emoji: '✍️',
      title: "Décrire ce que j'ai mangé",
      subtitle: 'Un ou plusieurs plats, ex. « crêpes et poulet sauce soja » → calories et ingrédients',
      onTap: () => setState(() {
        _error = null;
        _stage = _Stage.describe;
      }),
    ),
    const SizedBox(height: 12),
    HabitsList(habits: _habits, onLog: _logHabit, showType: true),
    _BigChoice(
      emoji: '📖',
      title: 'Trouver une recette',
      subtitle: 'Un plat, pour le nombre de personnes choisi → recette complète et ingrédients',
      onTap: () => setState(() {
        _error = null;
        _stage = _Stage.text;
      }),
    ),
  ];

  Future<void> _logHabit(Habit h, int count) async {
    final type = widget.presetType ?? h.mealType;
    await _mealLogs.addMealLog(
      h.toDraft(count, type, eatenAtFor(widget.day, type)),
      source: h.recipeId != null ? 'recipe' : 'manual',
      ownerUid: widget.ownerUid,
      ownerName: widget.ownerName,
      householdId: widget.householdId,
    );
  }

  List<Widget> _buildDescribe() => [
    if (widget.preset != null) HabitsList(habits: _habits, onLog: _logHabit),
    Text(
      (widget.preset != null && _habits.isNotEmpty ? 'Autre chose ? ' : '') + (widget.snack ? "Qu'as-tu pris ?" : "Qu'as-tu mangé ?"),
      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
    ),
    const SizedBox(height: 8),
    TextField(
      controller: _describeCtrl,
      autofocus: _habits.isEmpty || widget.preset == null,
      minLines: 2,
      maxLines: 4,
      style: const TextStyle(fontSize: 17),
      decoration: InputDecoration(
        hintText: widget.snack
            ? 'ex : une pomme et 3 carrés de chocolat'
            : (widget.preset == 'breakfast'
                  ? 'ex : café au lait, 2 tartines beurre-confiture'
                  : 'ex : 2 crêpes et du poulet sauce soja avec du riz'),
      ),
    ),
    if (widget.snack) ...[
      const SizedBox(height: 16),
      const Text(
        'Idées — touche pour ajouter',
        style: TextStyle(color: AppColors.inkSoft, fontWeight: FontWeight.w600, fontSize: 13),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final idea in _snackIdeas)
            ActionChip(
              label: Text('+ $idea'),
              onPressed: () {
                final cur = _describeCtrl.text.trim();
                _describeCtrl.text = cur.isEmpty ? idea : '$cur, ${idea.toLowerCase()}';
              },
            ),
        ],
      ),
    ],
    const SizedBox(height: 24),
    SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: _describeMeal,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Text('Estimer les calories', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      ),
    ),
  ];

  List<Widget> _buildText() => [
    const Text('Quel repas ?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
    const SizedBox(height: 8),
    TextField(
      controller: _queryCtrl,
      autofocus: true,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _searchRecipe(),
      style: const TextStyle(fontSize: 17),
      decoration: const InputDecoration(hintText: 'ex : crêpes, lasagnes, un lien de recette…'),
    ),
    const SizedBox(height: 20),
    const Text('Pour combien de personnes ?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
    const SizedBox(height: 8),
    _Stepper(
      value: _persons.toDouble(),
      min: 1,
      max: 20,
      step: 1,
      suffix: _persons > 1 ? 'personnes' : 'personne',
      onChanged: (v) => setState(() => _persons = v.round()),
    ),
    const SizedBox(height: 24),
    SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: _searchRecipe,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Text('Trouver la recette', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      ),
    ),
  ];

  List<Widget> _buildLoading() => [
    const SizedBox(height: 60),
    if (_photoFile != null)
      Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: FutureBuilder(
            future: _photoFile!.readAsBytes(),
            builder: (_, snap) => snap.hasData
                ? Image.memory(snap.data!, width: 160, height: 160, fit: BoxFit.cover)
                : const SizedBox(width: 160, height: 160),
          ),
        ),
      ),
    const SizedBox(height: 20),
    const Center(child: CircularProgressIndicator()),
    const SizedBox(height: 16),
    Center(
      child: Text(_loadingLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
    ),
  ];

  List<Widget> _buildResult() {
    final draft = _draft!;
    final matched = _recipeById(widget.recipes, _matchedRecipeId);
    final isMeal = _kind == _Kind.meal;
    final suggestions = isMeal ? _mealSuggestions : ['Pour ${draft.servings + 2} personnes', ..._textSuggestions];
    return [
      if (_photoFile != null)
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: FutureBuilder(
            future: _photoFile!.readAsBytes(),
            builder: (_, snap) => snap.hasData
                ? Image.memory(snap.data!, height: 190, width: double.infinity, fit: BoxFit.cover)
                : const SizedBox(height: 190),
          ),
        )
      else if (_suggestedPhoto != null)
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Image.network(
            _suggestedPhoto!,
            height: 190,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      const SizedBox(height: 12),
      Text(
        isMeal ? 'CE QUE TU AS MANGÉ · 1 PERSONNE' : 'RECETTE POUR ${draft.servings} PERSONNE${draft.servings > 1 ? "S" : ""}',
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.inkSoft, letterSpacing: 0.8),
      ),
      const SizedBox(height: 8),
      if (_lastChange != null) ...[_Banner(text: '✓ Adapté : « $_lastChange »', color: AppColors.herb), const SizedBox(height: 10)],
      if (matched != null) ...[
        _Banner(text: 'Ça ressemble à « ${matched.name} », déjà dans tes recettes.', color: AppColors.ink),
        const SizedBox(height: 10),
      ],
      _NutritionCard(nutrition: draft.nutrition, perLabel: isMeal ? 'dans ton assiette' : 'par personne'),
      const SizedBox(height: 12),
      _Section(
        title: isMeal ? 'CE QUE TU AS MANGÉ' : 'INGRÉDIENTS',
        child: draft.ingr.isEmpty
            ? const Text('Aucun ingrédient détecté.', style: TextStyle(color: AppColors.inkSoft))
            : Column(
                children: [
                  for (var i = 0; i < draft.ingr.length; i++) ...[
                    if (i > 0) const Divider(height: 1, color: AppColors.line),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(child: Text(draft.ingr[i].name, style: const TextStyle(fontSize: 15))),
                          Text(
                            draft.ingr[i].qty,
                            style: const TextStyle(color: AppColors.inkSoft, fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
      ),
      if (draft.steps.isNotEmpty) ...[
        const SizedBox(height: 12),
        _Section(
          title: 'PRÉPARATION',
          child: Column(
            children: [
              for (var i = 0; i < draft.steps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: AppColors.accent,
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(draft.steps[i], style: const TextStyle(height: 1.4, fontSize: 15))),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 12),
      _Section(
        title: 'ADAPTER',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final s in suggestions) ActionChip(label: Text(s), onPressed: _iterating ? null : () => _iterate(s))],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _instrCtrl,
                    enabled: !_iterating,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _iterate,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: isMeal ? "ex : c'était du riz complet" : "ex : remplace le lait par du lait d'avoine",
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _iterating
                    ? const SizedBox(
                        width: 44,
                        height: 44,
                        child: Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2.5)),
                      )
                    : IconButton.filled(
                        style: IconButton.styleFrom(backgroundColor: AppColors.ink),
                        onPressed: () => _iterate(_instrCtrl.text),
                        icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                      ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _Section(
        title: 'ET MAINTENANT ?',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in kMealTypes)
                  ChoiceChip(
                    label: Text(m.$2),
                    selected: _mealType == m.$1,
                    selectedColor: AppColors.accent,
                    labelStyle: TextStyle(color: _mealType == m.$1 ? Colors.white : AppColors.ink),
                    onSelected: (_) => setState(() => _mealType = m.$1),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  isMeal ? 'Assiettes' : 'Portions',
                  style: const TextStyle(color: AppColors.inkSoft, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 10),
                _Stepper(value: _portions, min: 0.5, max: 10, step: 0.5, onChanged: (v) => setState(() => _portions = v)),
                const Spacer(),
                Text(
                  '${((draft.nutrition?.kcal ?? 0) * _portions).round()} kcal',
                  style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _logged || _busy != null ? null : _logMeal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _logged ? AppColors.herb : null,
                  disabledForegroundColor: _logged ? Colors.white : null,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  _logged
                      ? '✓ Ajouté à ${_isToday ? 'ta journée' : dayLabel(widget.day).toLowerCase()}'
                      : (_busy == 'log'
                            ? 'Enregistrement…'
                            : (_isToday ? "J'ai mangé ça" : "J'ai mangé ça ${dayLabel(widget.day).toLowerCase()}")),
                  style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: _savedRecipeId != null || _busy != null ? null : _saveRecipe,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.ink,
                  disabledForegroundColor: _savedRecipeId != null ? AppColors.herb : null,
                  side: BorderSide(color: _savedRecipeId != null ? AppColors.herb : AppColors.line, width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  _savedRecipeId != null ? '✓ Dans mes recettes' : (_busy == 'save' ? 'Enregistrement…' : 'Garder dans mes recettes'),
                  style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Terminé')),
          ],
        ),
      ),
    ];
  }
}

class _BigChoice extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final bool primary;
  final VoidCallback onTap;
  const _BigChoice({required this.emoji, required this.title, required this.subtitle, required this.onTap, this.primary = false});

  @override
  Widget build(BuildContext context) {
    final fg = primary ? Colors.white : AppColors.ink;
    return Material(
      color: primary ? AppColors.accent : AppColors.surface,
      borderRadius: BorderRadius.circular(24),
      elevation: primary ? 4 : 1,
      shadowColor: primary ? AppColors.accent.withValues(alpha: 0.5) : Colors.black12,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 38)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: fg),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(fontSize: 13, color: primary ? Colors.white70 : AppColors.inkSoft)),
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

class _Stepper extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final double step;
  final String? suffix;
  final ValueChanged<double> onChanged;
  const _Stepper({required this.value, required this.min, required this.max, required this.step, required this.onChanged, this.suffix});

  @override
  Widget build(BuildContext context) {
    final label = value == value.roundToDouble() ? value.round().toString() : value.toString();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          onPressed: value <= min ? null : () => onChanged((value - step).clamp(min, max)),
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 40,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
        ),
        IconButton.filledTonal(
          onPressed: value >= max ? null : () => onChanged((value + step).clamp(min, max)),
          icon: const Icon(Icons.add),
        ),
        if (suffix != null) ...[const SizedBox(width: 8), Text(suffix!, style: const TextStyle(color: AppColors.inkSoft))],
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.inkSoft, letterSpacing: 0.8),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final String text;
  final Color color;
  const _Banner({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Calories + répartition protéines/glucides/lipides (grammes et part des
/// calories) — identique pour photo et texte.
class _NutritionCard extends StatelessWidget {
  final NutritionEstimate? nutrition;
  final String perLabel;
  const _NutritionCard({required this.nutrition, required this.perLabel});

  @override
  Widget build(BuildContext context) {
    final n = nutrition;
    if (n == null) {
      return const _Section(
        title: 'CALORIES',
        child: Text("Pas d'estimation disponible — utilise « Adapter » pour la demander.", style: TextStyle(color: AppColors.inkSoft)),
      );
    }
    final macros = [
      ('Protéines', n.proteinG, n.proteinG * 4, const Color(0xFFE5484D)),
      ('Glucides', n.carbsG, n.carbsG * 4, const Color(0xFFFFC93C)),
      ('Lipides', n.fatG, n.fatG * 9, const Color(0xFF17A2B8)),
    ];
    final total = macros.fold<num>(0, (a, m) => a + m.$3);
    final safeTotal = total > 0 ? total : 1;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${n.kcal.round()}',
                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'kcal $perLabel',
                  style: const TextStyle(color: AppColors.inkSoft, fontWeight: FontWeight.w600),
                ),
              ),
              if (n.gramsPerServing > 0)
                Text('≈ ${n.gramsPerServing.round()} g', style: const TextStyle(color: AppColors.inkSoft, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  for (final m in macros)
                    if (m.$3 > 0)
                      Expanded(
                        flex: ((m.$3 / safeTotal) * 1000).round().clamp(1, 1000),
                        child: Container(color: m.$4),
                      ),
                  if (total == 0) Expanded(child: Container(color: AppColors.surface2)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < macros.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(radius: 4, backgroundColor: macros[i].$4),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                macros[i].$1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, color: AppColors.inkSoft, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${macros[i].$2.round()} g',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, fontFamily: 'monospace'),
                        ),
                        Text(
                          '${((macros[i].$3 / safeTotal) * 100).round()} %',
                          style: const TextStyle(fontSize: 11, color: AppColors.inkSoft),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
