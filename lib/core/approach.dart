import 'package:flutter/material.dart';

class Approach {
  const Approach({
    required this.title,
    required this.useCase,
    required this.icon,
    required this.pageBuilder,
  });

  final String title;
  final String useCase;
  final IconData icon;
  final WidgetBuilder pageBuilder;
}