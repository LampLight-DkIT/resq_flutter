import 'package:flutter/material.dart';

class SocialLoginButton extends StatelessWidget {
  final Widget iconWidget;
  final String label;
  final Color textColor;
  final Color backgroundColor;
  final Color borderColor;
  final double borderRadius;
  final double paddingVertical;
  final double paddingHorizontal;
  final TextStyle? textStyle;
  final VoidCallback onPressed;

  const SocialLoginButton({
    super.key,
    required this.iconWidget,
    required this.label,
    required this.textColor,
    required this.backgroundColor,
    required this.borderColor,
    this.borderRadius = 8.0,
    this.paddingVertical = 12.0,
    this.paddingHorizontal = 16.0,
    this.textStyle,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: iconWidget,
        label: Text(
          label,
          style: textStyle ??
              TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          padding: EdgeInsets.symmetric(
            vertical: paddingVertical,
            horizontal: paddingHorizontal,
          ),
          side: BorderSide(color: borderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      ),
    );
  }
}
