import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class ConfigOptionsScreen extends StatelessWidget {
  const ConfigOptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(context.l10n.get('configMgmt')),
    );
  }
}
