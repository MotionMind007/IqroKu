# IqroKu

Flutter prototype for the IqroKu mobile app: Iqro learning, Juz Amma, Qur'an reading, prayer times, qibla direction, child profiles, and learning progress.

## Run

```powershell
cd d:\MotionMind\iqroku\iqroku_app
flutter pub get
flutter run
```

For a quick web preview:

```powershell
flutter run -d chrome
```

For Android debug APK:

```powershell
flutter build apk --debug
```

The debug APK is generated at:

```text
build\app\outputs\flutter-apk\app-debug.apk
```

## Current Scope

- Mobile-first app shell with bottom navigation.
- Home dashboard with prayer countdown, shortcuts, and continue-learning cards.
- Iqro learning page with book tabs, page grid, audio controls, and learning status buttons.
- Qur'an/Juz Amma page with reading list, memorization mode, and reader preview.
- Activity page for prayer times and qibla direction.
- Child profile page with progress summary and learning notes.

## Project Structure

```text
lib/
  app/        App shell and shared app state.
  core/       Theme tokens and reusable UI chrome.
  data/       Dummy repository used by the prototype.
  features/   Feature screens: home, learning, quran, activity, profile.
  models/     Domain models for Iqro, Qur'an, prayer, profile, and progress.
```
