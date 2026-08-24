import 'package:flutter/material.dart';

class NeuSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  const NeuSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: const Color(0xFF111116),
      borderRadius: borderRadius,
      border: Border.all(color: Colors.white.withValues(alpha: .035)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .72),
          offset: const Offset(8, 8),
          blurRadius: 16,
        ),
        BoxShadow(
          color: Colors.white.withValues(alpha: .045),
          offset: const Offset(-6, -6),
          blurRadius: 14,
        ),
      ],
    ),
    child: child,
  );
}

class NeuButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final EdgeInsetsGeometry padding;

  const NeuButton({
    super.key,
    required this.child,
    this.onPressed,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
  });

  @override
  State<NeuButton> createState() => _NeuButtonState();
}

class _NeuButtonState extends State<NeuButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTapDown:
          widget.onPressed == null
              ? null
              : (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp:
          widget.onPressed == null
              ? null
              : (_) {
                setState(() => _pressed = false);
                widget.onPressed!();
              },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: widget.padding,
        decoration: BoxDecoration(
          color:
              widget.onPressed == null
                  ? const Color(0xFF18181E)
                  : const Color(0xFF17151D),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: accent.withValues(alpha: .14)),
          boxShadow:
              _pressed
                  ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .65),
                      offset: const Offset(3, 3),
                      blurRadius: 7,
                    ),
                  ]
                  : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .72),
                      offset: const Offset(6, 6),
                      blurRadius: 12,
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: .035),
                      offset: const Offset(-4, -4),
                      blurRadius: 9,
                    ),
                  ],
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(
            color: widget.onPressed == null ? Colors.white38 : Colors.white,
            fontWeight: FontWeight.w700,
          ),
          child: Center(child: widget.child),
        ),
      ),
    );
  }
}

class NeuIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool active;
  const NeuIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121217),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .7),
            offset: const Offset(5, 5),
            blurRadius: 10,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: .035),
            offset: const Offset(-3, -3),
            blurRadius: 8,
          ),
        ],
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        color: active ? accent : Colors.white70,
      ),
    );
  }
}
