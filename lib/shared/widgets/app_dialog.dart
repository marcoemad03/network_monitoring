import 'package:flutter/material.dart';

class AppDialog {
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget content,
    String? confirmText,
    String? cancelText,
    VoidCallback? onConfirm,
    bool isDestructive = false,
    bool showCancel = true,
  }) {
    return showDialog<T>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: content,
        actions: [
          if (showCancel)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(cancelText ?? 'Cancel'),
            ),
          TextButton(
            onPressed: () {
              onConfirm?.call();
              Navigator.of(context).pop();
            },
            child: Text(
              confirmText ?? 'Confirm',
              style: TextStyle(
                color: isDestructive
                    ? Theme.of(context).colorScheme.error
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Future<bool?> confirm({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDestructive = false,
  }) {
    return show<bool>(
      context: context,
      title: title,
      content: Text(message),
      confirmText: confirmText,
      cancelText: cancelText,
      isDestructive: isDestructive,
    );
  }
}
