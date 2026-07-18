import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';

extension ContextExtensions on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => theme.textTheme;
  ColorScheme get colorScheme => theme.colorScheme;
  MediaQueryData get mediaQuery => MediaQuery.of(this);
  Size get screenSize => mediaQuery.size;
  bool get isDesktop => screenSize.width >= 900;
  bool get isTablet => screenSize.width >= 600 && screenSize.width < 900;
  bool get isMobile => screenSize.width < 600;
  double get screenWidth => screenSize.width;
  double get screenHeight => screenSize.height;

  AppLocalizations get l10n => AppLocalizations.of(this);

  void showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? colorScheme.error : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void showSuccessSnackBar(String message) {
    showSnackBar(message);
  }

  void showErrorSnackBar(String message) {
    showSnackBar(message, isError: true);
  }

  Future<T?> showAppDialog<T>({
    required String title,
    required String message,
    String? confirmText,
    String? cancelText,
    bool isDestructive = false,
  }) {
    return showDialog<T>(
      context: this,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(cancelText ?? 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              confirmText ?? 'Confirm',
              style: TextStyle(
                color: isDestructive ? colorScheme.error : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
