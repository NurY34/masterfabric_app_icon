import 'package:flutter/material.dart';
import 'app.dart';

void main() async {
  const config = AppConfig(
    flavor: 'dev',
    appName: 'Example Dev',
    primaryColor: Colors.blue,
  );

  await initializeApp(config);
  runApp(MyApp(config: config));
}

