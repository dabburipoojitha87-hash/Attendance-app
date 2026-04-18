import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/router/app_router.dart';
import 'firebase_options.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Supabase.initialize(
    url: 'https://xqbmhaaaqcoaqdeibpma.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhxYm1oYWFhcWNvYXFkZWlicG1hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ2MTQzMTksImV4cCI6MjA5MDE5MDMxOX0.2VDgJ4JhQ833zHf9cB5wwGqbBB3aNj3reYD8GD3sreE',
  );
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Echo Attendance',
      theme: ThemeData(
        primaryColor: const Color(0xFF1DB954),
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF1DB954),
          surface: Color(0xFF121212),
        ),
      ),
      routerConfig: router,
    );
  }
}
