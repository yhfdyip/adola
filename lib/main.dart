import 'package:flutter/widgets.dart';

import 'app/adola_app.dart';
import 'core/services/library_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LibraryService.instance.ensureInitialized();
  registerGlobalErrorHandlers();
  runApp(const AdolaApp());
}
