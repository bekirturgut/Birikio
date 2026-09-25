import 'package:flutter/material.dart';
import 'data/store.dart';
import 'ui/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(BirikioApp(store: FinanceStore(), initialize: true));
}
