import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'data/services/storage_service.dart';
import 'data/services/image_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await StorageService.instance.initialize();
  await ImageService.instance.initialize();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const ProviderScope(child: BookApp()));
}