import 'package:flutter/material.dart';
import '../models.dart';
import '../theme.dart';

class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final bool isFav;
  final VoidCallback onOpen;
  final VoidCallback onToggleFav;

  const RecipeCard({
    super.key,
    required this.recipe,
    required this.isFav,
    required this.onOpen,
    required this.onToggleFav,
  });

  @override
  Widget build(BuildContext context) {
    final cat = categoryFor(recipe.cat);
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: cat.color),
                  if (recipe.photoUrl != null)
                    Image.network(
                      recipe.photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Center(child: Icon(cat.icon, color: Colors.white, size: 32)),
                    )
                  else
                    Center(child: Icon(cat.icon, color: Colors.white, size: 32)),
                  if (recipe.ownerName != null)
                    Positioned(
                      left: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          recipe.ownerName!,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  Positioned(
                    right: 6,
                    top: 6,
                    child: GestureDetector(
                      onTap: onToggleFav,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.28),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          color: Colors.white,
                          size: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.ink),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 11, color: AppColors.inkSoft),
                      const SizedBox(width: 3),
                      Text('${recipe.time} min', style: const TextStyle(fontSize: 11, color: AppColors.inkSoft, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 6),
                      Text('·', style: TextStyle(color: AppColors.inkSoft.withValues(alpha: 0.6))),
                      const SizedBox(width: 6),
                      Text('${recipe.servings} pers.', style: const TextStyle(fontSize: 11, color: AppColors.inkSoft, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      if (recipe.veg)
                        const Icon(Icons.eco, size: 14, color: AppColors.herb),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
