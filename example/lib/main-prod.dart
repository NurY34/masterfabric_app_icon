import 'package:flutter/material.dart';
import 'app.dart';

void main() async {
  const config = AppConfig(
    flavor: 'prod',
    appName: 'Example',
    primaryColor: Colors.deepPurple,
  );

  await initializeApp(config);
  runApp(MyApp(config: config));
}

