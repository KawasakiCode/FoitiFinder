FoitiFinder
FoitiFinder is a modern social discovery application built with Flutter, designed to connect students with similar interests and lifestyles. It features a high-performance, physics-based card swipe interface, robust state management, and full internationalization support.

Features
Core Experience
Tinder-style Swipe Deck:

Physics-based animations (Drag, Rotation, and Velocity detection).

Infinite Scrolling: Implemented using a "Sliding Window" architecture to manage memory efficiently.

3-Directional Swipe: Like (Right), Pass (Left), and Super Like (Up).

Rewind Capability: Undo the last action with a history buffer.

Reactive UI:

Animated "Like/Pass" stamps that react to drag distance.

Custom AnimatedSwipeButton widgets with press-and-hold physics.

Background cards that interpolate position and scale based on user gesture.

Architecture & Foundation
Navigation:

IndexedStack Shell: Preserves state between tabs (Home, Search, Likes, Profile).

Smart Back Button: Custom PopScope logic to handle history navigation within tabs.

Settings & Preferences:

Dark/Light Mode: Fully custom Material 3 themes with "Electric Purple" branding.

Localization (i18n): Native support for English (en) and Greek (el) via .arb files.

Persistence: Saves user preferences (Theme, Language, Phone Verification) locally using SharedPreferences.

Authentication:

Firebase Auth integration (Email/Password and Phone OTP).

Automatic session restoration and verification checks.

🛠 Tech Stack
Frontend: Flutter (Dart)

State Management: Provider (MultiProvider pattern)

Backend (Auth): Firebase Authentication

Backend (Data): Python (FastAPI) + PostgreSQL (Planned)

Local Storage: SharedPreferences & File System

Key Packages
provider: State management.

firebase_auth & firebase_core: User management.

flutter_localizations: Internationalization.

auto_size_text: Responsive typography.

image_picker: Gallery/Camera access.

path_provider: Local file storage.

flutter_native_splash: Native startup screen.

Theme Customization
The app uses a strict styling system defined in main.dart to prevent default Material 3 color bleeding.

Brand Color: kBrandPurple (Defined in constants).

Splash Style: Uses InkRipple with custom opacity to prevent pixelation on dark backgrounds.


Getting Started

Clone the repository: https://github.com/KawasakiCode/FoitiFinder
Install dependancies: flutter pub get
Generate Translations: flutter gen-l10n
Setup Firebase: Add your google-services.json (Android) and GoogleService-Info.plist (iOS) to the respective folders.
Run the App: flutter run

