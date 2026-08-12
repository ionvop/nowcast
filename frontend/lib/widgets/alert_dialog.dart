import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Global alert dialog for errors/messages.
Future<void> showAppAlert(
  BuildContext context, {
  required String message,
  String title = 'Nowcast',
  VoidCallback? onOk,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        side: const BorderSide(color: AppTheme.cardBorder, width: 1),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      content: Text(message, style: const TextStyle(color: AppTheme.mutedGrey)),
      actions: [
        ElevatedButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            onOk?.call();
          },
          child: const Text('OK'),
        ),
      ],
    ),
  );
}