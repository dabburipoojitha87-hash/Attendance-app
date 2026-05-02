# Attendify

Attendify is a comprehensive, modern Flutter application designed to track and manage student attendance efficiently. It offers a suite of tools including subject management, timetable scheduling, attendance simulation, and AI-powered insights.

## Features

- **Authentication**: Secure user login and registration powered by Firebase Auth.
- **Attendance Tracking**: Keep precise records of your attendance across different subjects.
- **Subject Management**: Add and manage subjects, set required attendance criteria, and monitor individual subject status.
- **Timetable**: View and manage your daily and weekly class schedules.
- **Attendance Simulator**: Forecast your future attendance percentage based on upcoming classes and hypothetical attendance scenarios.
- **AI Integration**: AI-driven insights and assistance for better academic planning.
- **Profile Management**: Customize user details and application settings.

## Tech Stack

- **Framework**: [Flutter](https://flutter.dev/)
- **State Management**: [Riverpod](https://riverpod.dev/)
- **Routing**: [GoRouter](https://pub.dev/packages/go_router)
- **Backend & Database**: [Supabase](https://supabase.com/)
- **Authentication**: [Firebase Auth](https://firebase.google.com/products/auth)
- **UI Components**: [Table Calendar](https://pub.dev/packages/table_calendar)

## Getting Started

### Prerequisites

- Flutter SDK (version ^3.10.8 or higher)
- Dart SDK
- Firebase project configured
- Supabase project configured

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/dabburipoojitha87-hash/Attendance-app.git
   cd attendify
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Configure Firebase and Supabase environment variables according to your project settings.

4. Run the app:
   ```bash
   flutter run
   ```

## Project Structure

The application follows a feature-first architecture, organizing code into domain-specific modules under `lib/features/`:

- `ai/`: AI insights and assistance.
- `attendance/`: Core logic for tracking attendance.
- `auth/`: Authentication flow.
- `home/`: Main dashboard views.
- `profile/`: User profile and settings.
- `stimulator/`: Tools to simulate and plan future attendance.
- `subjects/`: Managing academic subjects.
- `timetable/`: Schedule management.

