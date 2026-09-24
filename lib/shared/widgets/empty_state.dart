import 'package:flutter/material.dart';
import 'package:meetmind/shared/theme/mawid_mark.dart';

/// حالة "فاضية" موحّدة (لا مواعيد، لا نتائج بحث...) — تستخدم علامة
/// "موعد" داخل دائرة ناعمة بدل أيقونة عامة، مع دخول خفيف (fade + scale)
/// بدل الظهور المفاجئ.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.scale(scale: 0.9 + (0.1 * t), child: child),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: MawidMark(
                  size: 40,
                  letterColor: cs.onPrimaryContainer,
                  ringColor: cs.onPrimaryContainer.withValues(alpha: 0.4),
                  dotColor: cs.tertiary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
