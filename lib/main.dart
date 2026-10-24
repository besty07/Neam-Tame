import 'package:flutter/material.dart';

import 'app/boot.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LifeVaultDependencies dependencies;
  try {
    dependencies = await LifeVaultDependencies.createProduction();
  } on Object {
    dependencies = LifeVaultDependencies.createDefault();
  }
  runApp(LifeVaultApp(dependencies: dependencies));
}
