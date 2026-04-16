import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/ai/ai_chat_screen.dart';
import '../../features/ai/chat_screen.dart';
import '../../features/attendance/attendance_calendar_screen.dart';
import '../../features/attendance/attendance_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/signup_screen.dart';

import '../../features/home/home_screen.dart';
import '../../features/profile/edit_profile_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/profile/profile_setup_screen.dart';
import '../../features/stimulator/bunk_calculator_screen.dart';
import '../../features/subjects/subjects_screen.dart';
import '../../features/subjects/add_subject_screen.dart';
import '../../features/timetable/timetable_screen.dart';
import '../../features/timetable/add_timetable_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/profile-setup',
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/subjects',
        builder: (context, state) => const SubjectsScreen(),
      ),
      GoRoute(
        path: '/add-subject',
        builder: (context, state) => const AddSubjectScreen(),
      ),
      GoRoute(
        path: '/timetable',
        builder: (context, state) => const TimetableScreen(),
      ),
      GoRoute(
        path: '/add-timetable',
        builder: (context, state) => const AddTimetableScreen(),
      ),
      GoRoute(
        path: '/attendance',
        builder: (context, state) => const AttendanceScreen(),
      ),

      GoRoute(
        path: '/attendance-calendar',
        builder: (context, state) => const AttendanceCalendarScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),

      GoRoute(
        path: '/edit-profile',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/bunk',
        builder: (context, state) => const BunkCalculatorScreen(),
      ),
      GoRoute(
        path: '/ai_chat',
        builder: (context, state) => const AIChatScreen(),
      ),
      GoRoute(path: '/chat', builder: (context, state) => const ChatScreen()),
    ],
  );
});
