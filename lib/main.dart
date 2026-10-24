import 'package:flutter/material.dart';

import 'app/boot.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dependencies = await LifeVaultDependencies.createProduction();
  runApp(LifeVaultApp(dependencies: dependencies));
}
