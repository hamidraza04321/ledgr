import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// "Continue with Google" button with a simple multicolour G mark.
class GoogleButton extends StatelessWidget {
  const GoogleButton({
    super.key,
    required this.onPressed,
    this.loading = false,
    this.label = 'Continue with Google',
  });

  final VoidCallback? onPressed;
  final bool loading;
  final String label;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: dark ? Colors.white : const Color(0xFF14161C),
        foregroundColor: dark ? const Color(0xFF14161C) : Colors.white,
        disabledBackgroundColor:
            (dark ? Colors.white : const Color(0xFF14161C)).withValues(alpha: 0.6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: dark ? const Color(0xFF14161C) : Colors.white,
              ),
            )
          else
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: ShaderMask(
                shaderCallback: (r) => const SweepGradient(
                  colors: [
                    Color(0xFF4285F4),
                    Color(0xFF34A853),
                    Color(0xFFFBBC05),
                    Color(0xFFEA4335),
                    Color(0xFF4285F4),
                  ],
                ).createShader(r),
                child: Text(
                  'G',
                  style: context.text.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
              ),
            ),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }
}
