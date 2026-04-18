import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Feature screens
import '../attendance/attendance_screen.dart';
import '../attendance/attendance_calendar_screen.dart';
import '../subjects/subjects_screen.dart';
import '../timetable/timetable_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _isSearching = false;

  /// 🎨 THEME COLORS
  static const Color primary = Color(0xFF1DB954);
  static const Color accent = Color(0xFF1DB954);
  static const Color background = Color.fromARGB(255, 0, 0, 0);
  static const Color surface = Color.fromARGB(255, 0, 0, 0);
  static const Color cardStart = Color(0xFF212121);
  static const Color cardEnd = Color(0xFF212121);
  static const Color border = Color(0xFF535353);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color disabled = Color(0xFF535353);
  static const Color error = Color(0xFFE57373);

  final List<Widget> _pages = [
    const AttendanceScreen(),
    const AttendanceCalendarScreen(),
    const SubjectsScreen(),
    const TimetableScreen(),
  ];

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSearching && _selectedIndex == 0,
      onPopInvoked: (didPop) {
        if (didPop) return;

        if (_isSearching) {
          setState(() => _isSearching = false);
          return;
        }

        if (_selectedIndex != 0) {
          setState(() => _selectedIndex = 0);
          return;
        }
      },
      child: Scaffold(
        backgroundColor: background,

        /// APP BAR
        appBar: AppBar(
          backgroundColor: background,
          surfaceTintColor: Colors.transparent,
          elevation: 0,

          leading: Padding(
            padding: const EdgeInsets.all(8),
            child: GestureDetector(
              onTap: () => context.push('/profile'),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: primary, width: 1.2),
                ),
                child: const CircleAvatar(
                  backgroundColor: background,
                  child: Icon(
                    Icons.person_outline,
                    color: textSecondary,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),

          /// ✅ ECHO TEXT NOW WHITE
          title: const Text(
            "ECHO",
            style: TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),

          actions: [
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: accent, size: 20),
              onPressed: () => _logout(context),
            ),

            const SizedBox(width: 8),
          ],
        ),

        /// BODY
        body: SafeArea(
          child: Column(
            children: [
              /// SEARCH BAR
              Container(
                color: background,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: TextField(
                  readOnly: true,
                  onTap: () => setState(() => _isSearching = true),
                  decoration: InputDecoration(
                    hintText: "Search system",

                    hintStyle: const TextStyle(
                      color: textSecondary,
                      fontSize: 14,
                    ),

                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: primary,
                      size: 22,
                    ),

                    filled: true,
                    fillColor: surface,

                    contentPadding: const EdgeInsets.symmetric(vertical: 0),

                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: border),
                    ),

                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: primary),
                    ),
                  ),
                ),
              ),

              Expanded(
                child: Stack(
                  children: [
                    _pages[_selectedIndex],

                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _isSearching
                          ? Container(
                              key: const ValueKey(1),
                              color: Colors.black.withOpacity(0.85),
                              child: _buildDashboardGrid(),
                            )
                          : const SizedBox(key: ValueKey(2)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        /// ✅ FAB ONLY ON ATTENDANCE SCREEN
        floatingActionButton: _selectedIndex == 0
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  /// 🤖 CHATBOT BUTTON (SMALL)
                  FloatingActionButton(
                    heroTag: "chatbot_fab",
                    mini: true,
                    backgroundColor: primary,
                    elevation: 4,
                    onPressed: () {
                      context.push('/chat');
                    },
                    child: const Icon(
                      Icons.smart_toy_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),

                  const SizedBox(height: 10),

                  /// 📊 SIMULATOR BUTTON (SMALL)
                  FloatingActionButton(
                    heroTag: "bunk_fab",
                    mini: true,
                    backgroundColor: accent,
                    elevation: 4,
                    onPressed: () {
                      context.push('/bunk');
                    },
                    child: const Icon(
                      Icons.calculate_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              )
            : null,

        /// BOTTOM NAVIGATION
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: border, width: 0.5)),
          ),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            type: BottomNavigationBarType.fixed,

            selectedItemColor: primary,
            unselectedItemColor: disabled,

            backgroundColor: background,
            elevation: 0,

            onTap: (index) {
              setState(() {
                _selectedIndex = index;
                _isSearching = false;
              });
            },

            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.today_outlined),
                label: "Today",
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.calendar_month_outlined),
                label: "Calendar",
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.auto_stories_outlined),
                label: "Subjects",
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.access_time_rounded),
                label: "Timetable",
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardGrid() {
    return GridView.count(
      padding: const EdgeInsets.all(24),
      crossAxisCount: 2,
      crossAxisSpacing: 18,
      mainAxisSpacing: 18,
      childAspectRatio: 1.2,
      children: [
        _dashboardCard("Subjects", Icons.menu_book_rounded, primary, 2),

        _dashboardCard("Timetable", Icons.calendar_today_rounded, accent, 3),

        _dashboardCard(
          "Attendance",
          Icons.check_circle_outline_rounded,
          const Color(0xFF7BD3A8),
          0,
        ),

        _dashboardCard(
          "Calendar",
          Icons.event_note_rounded,
          const Color(0xFF89B4FA),
          1,
        ),
      ],
    );
  }

  Widget _dashboardCard(String title, IconData icon, Color color, int index) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedIndex = index;
          _isSearching = false;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [cardStart, cardEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),

            const SizedBox(height: 10),

            Text(
              title,
              style: const TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationIcon(int count) {
    return Stack(
      children: [
        const Icon(
          Icons.notifications_none_rounded,
          color: textSecondary,
          size: 24,
        ),

        if (count > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: error,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
