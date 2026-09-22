import 'package:flutter/material.dart';
import '../models.dart';
import '../theme.dart';

class FieldLabel extends StatelessWidget {
  final String text;
  const FieldLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.inkSoft, letterSpacing: .4)),
    );
  }
}

/// Name/category/time/difficulty/servings/veg/ingredients/steps — the part
/// of the recipe form shared between CaptureScreen and EditRecipeScreen.
/// Photo handling stays in each caller since the two flows attach it
/// differently (new doc vs. existing one).
class RecipeCoreFields extends StatelessWidget {
  final RecipeDraft draft;
  final VoidCallback onChanged;
  const RecipeCoreFields({super.key, required this.draft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FieldLabel('Nom du plat'),
        TextFormField(
          key: ValueKey('name-${draft.hashCode}'),
          initialValue: draft.name,
          onChanged: (v) => draft.name = v,
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const FieldLabel('Catégorie'),
              DropdownButtonFormField<String>(
                initialValue: kCategories.any((c) => c.key == draft.cat) ? draft.cat : kCategories.first.key,
                items: [for (final c in kCategories) DropdownMenuItem(value: c.key, child: Text(c.label, overflow: TextOverflow.ellipsis))],
                onChanged: (v) {
                  draft.cat = v ?? draft.cat;
                  onChanged();
                },
              ),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const FieldLabel('Temps (min)'),
              TextFormField(
                key: ValueKey('time-${draft.hashCode}'),
                initialValue: '${draft.time}',
                keyboardType: TextInputType.number,
                onChanged: (v) => draft.time = int.tryParse(v) ?? draft.time,
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const FieldLabel('Difficulté'),
              DropdownButtonFormField<String>(
                initialValue: kDifficulties.contains(draft.diff) ? draft.diff : kDifficulties.first,
                items: [for (final d in kDifficulties) DropdownMenuItem(value: d, child: Text(d))],
                onChanged: (v) {
                  draft.diff = v ?? draft.diff;
                  onChanged();
                },
              ),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const FieldLabel('Personnes'),
              TextFormField(
                key: ValueKey('servings-${draft.hashCode}'),
                initialValue: '${draft.servings}',
                keyboardType: TextInputType.number,
                onChanged: (v) => draft.servings = int.tryParse(v) ?? draft.servings,
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        StatefulBuilder(builder: (context, setLocal) {
          return CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: draft.veg,
            onChanged: (v) => setLocal(() => draft.veg = v ?? false),
            title: const Text('Recette végétarienne'),
            controlAffinity: ListTileControlAffinity.leading,
          );
        }),
        const SizedBox(height: 8),
        const FieldLabel('Ingrédients'),
        _IngredientList(draft: draft, onChanged: onChanged),
        const SizedBox(height: 18),
        const FieldLabel('Étapes'),
        _StepList(draft: draft, onChanged: onChanged),
        const SizedBox(height: 18),
        NutritionFields(draft: draft, onChanged: onChanged),
      ],
    );
  }
}

/// Kcal/macros/weight per serving — editable estimate, mirrors the
/// "Nutrition (par portion)" section in ../../src/components/RecipeCoreFields.tsx.
class NutritionFields extends StatelessWidget {
  final RecipeDraft draft;
  final VoidCallback onChanged;
  const NutritionFields({super.key, required this.draft, required this.onChanged});

  void _update(String field, num value) {
    final n = draft.nutrition;
    draft.nutrition = NutritionEstimate(
      kcal: field == 'kcal' ? value : (n?.kcal ?? 0),
      proteinG: field == 'proteinG' ? value : (n?.proteinG ?? 0),
      carbsG: field == 'carbsG' ? value : (n?.carbsG ?? 0),
      fatG: field == 'fatG' ? value : (n?.fatG ?? 0),
      gramsPerServing: field == 'gramsPerServing' ? value : (n?.gramsPerServing ?? 0),
      estimatedBy: 'manual',
    );
    onChanged();
  }

  Widget _field(String label, num? value, String key) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label),
        TextFormField(
          key: ValueKey('nutrition-$key-${draft.hashCode}'),
          initialValue: '${value ?? ''}',
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(isDense: true),
          onChanged: (v) => _update(key, num.tryParse(v) ?? 0),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = draft.nutrition;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            FieldLabel('Nutrition (par portion)'),
            if (n?.estimatedBy == 'ai') ...[
              const SizedBox(width: 6),
              const Text('— estimation IA, modifiable', style: TextStyle(fontSize: 10.5, color: AppColors.inkSoft)),
            ],
          ],
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(width: 90, child: _field('Poids (g)', n?.gramsPerServing, 'gramsPerServing')),
            SizedBox(width: 90, child: _field('Kcal', n?.kcal, 'kcal')),
            SizedBox(width: 90, child: _field('Protéines (g)', n?.proteinG, 'proteinG')),
            SizedBox(width: 90, child: _field('Glucides (g)', n?.carbsG, 'carbsG')),
            SizedBox(width: 90, child: _field('Lipides (g)', n?.fatG, 'fatG')),
          ],
        ),
      ],
    );
  }
}

class _IngredientList extends StatelessWidget {
  final RecipeDraft draft;
  final VoidCallback onChanged;
  const _IngredientList({required this.draft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < draft.ingr.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    initialValue: draft.ingr[i].name,
                    decoration: const InputDecoration(hintText: 'ingrédient', isDense: true),
                    onChanged: (v) => draft.ingr[i] = Ingredient(name: v, qty: draft.ingr[i].qty),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: draft.ingr[i].qty,
                    decoration: const InputDecoration(hintText: 'quantité', isDense: true),
                    onChanged: (v) => draft.ingr[i] = Ingredient(name: draft.ingr[i].name, qty: v),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    draft.ingr.removeAt(i);
                    onChanged();
                  },
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              draft.ingr.add(const Ingredient(name: '', qty: ''));
              onChanged();
            },
            icon: const Icon(Icons.add, size: 16),
            label: const Text('ajouter un ingrédient'),
          ),
        ),
      ],
    );
  }
}

class _StepList extends StatelessWidget {
  final RecipeDraft draft;
  final VoidCallback onChanged;
  const _StepList({required this.draft, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < draft.steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text('${i + 1}', style: const TextStyle(color: AppColors.inkSoft, fontFamily: 'monospace')),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: draft.steps[i],
                    maxLines: null,
                    decoration: const InputDecoration(hintText: 'étape de préparation', isDense: true),
                    onChanged: (v) => draft.steps[i] = v,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    draft.steps.removeAt(i);
                    onChanged();
                  },
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              draft.steps.add('');
              onChanged();
            },
            icon: const Icon(Icons.add, size: 16),
            label: const Text('ajouter une étape'),
          ),
        ),
      ],
    );
  }
}
