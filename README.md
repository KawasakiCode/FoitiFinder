## FoitiFinder

**FoitiFinder** is a modern social discovery application built with Flutter, designed to connect people. It features a high-performance, physics-based card swipe interface, robust state management, and full internationalization support.

### 🎥 Demo

[![Watch the FoitiFinder demo](https://img.youtube.com/vi/nyg57k5ma9A/hqdefault.jpg)](https://youtu.be/nyg57k5ma9A) 

> ▶️ **[Watch the full demo on YouTube](https://youtu.be/nyg57k5ma9A)**

### Key Features

#### Core Experience
* **Tinder-style Swipe Deck:** Implements physics-based animations (Drag, Rotation, and Velocity detection) for a fluid user experience.
* **Infinite Scrolling:** Utilizes a "Sliding Window" architecture to manage memory efficiently while browsing users.
* **3-Directional Swipe:** Supports **Like** (Right), **Pass** (Left), and **Super Like** (Up).
* **Rewind Capability:** Includes a history buffer to undo the last action.

#### Reactive UI
* **Dynamic Feedback:** Animated "Like/Pass" stamps that react instantly to drag distance.
* **Interactive Controls:** Custom `AnimatedSwipeButton` widgets with press-and-hold physics.
* **Interpolation:** Background cards that interpolate position and scale based on user gestures.

---

### Architecture & Foundation

* **Navigation:**
    * **IndexedStack Shell:** Preserves state between tabs (Home, Likes, Profile) without rebuilding.
    * **Smart Back Button:** Custom `PopScope` logic handles history navigation within tabs before exiting the app.
* **Settings & Preferences:**
    * **Dark/Light Mode:** Fully custom Material 3 themes with "Electric Purple" branding.
    * **Localization (i18n):** Native support for **English (en)** and **Greek (el)** via `.arb` files.
    * **Persistence:** Saves user preferences (Theme, Language, Phone Verification) locally using `SharedPreferences`.
* **Authentication:**
    * **Firebase Integration:** Robust auth flow supporting Email/Password and Phone OTP.
    * **Session Management:** Automatic session restoration and verification checks on startup.

---

### Tech Stack

* **Frontend:** Flutter (Dart)
* **State Management:** Provider (MultiProvider pattern)
* **Backend (Auth):** Firebase Authentication
* **Backend (Data):** Python (FastAPI) + PostgreSQL
* **Local Storage:** SharedPreferences & File System

---

### Key Packages

* **`provider`:** Essential state management for data flow.
* **`firebase_auth` & `firebase_core`:** User identity and session handling.
* **`flutter_localizations`:** Internationalization and localization support.
* **`auto_size_text`:** Responsive typography that scales with screen size.
* **`image_picker`:** Handling Gallery and Camera access permissions.
* **`path_provider`:** Accessing local file storage directories.
* **`flutter_native_splash`:** Native startup screen configuration.

---

### Theme Customization

The app uses a strict styling system defined in `main.dart` to prevent default Material 3 color

## AI Scoring Engine

The core feature of this application is an AI-driven attractiveness scoring system designed to run efficiently on standard CPU backends.

### How it Works (The Pipeline)

The scoring algorithm utilizes a **Transfer Learning** approach, leveraging a pre-trained face recognition model as a feature extractor for a custom regression head.


1.  **Input:** User uploads a selfie (JPEG/PNG).
2.  **Preprocessing:** The image is passed through **MTCNN** (Multi-task Cascaded Convolutional Networks) to detect, align, and crop the face.
3.  **Feature Extraction:** The cropped face is fed into **FaceNet (InceptionResnetV1)**, which maps the facial features into a **128-dimensional Euclidean embedding**.
    * *Note:* We use FaceNet because it is robust to minor lighting and pose variations.
4.  **Inference:** The 128-d vector is passed to a custom **Linear Regression** model.
5.  **Output:** The model predicts a score (1.0 - 10.0) based on the learned weights from the training dataset.

### Data & Methodology

To ensure the model is culturally relevant to the app's initial target demographic (Europe), we curated a specific subset of data:

* **Source:** [SCUT-FBP5500 Dataset](https://github.com/HCIILAB/SCUT-FBP5500-Database-Release)
* **Filtering:** We filtered the dataset to use only the **~1,500 Caucasian** images to reduce demographic noise and improve relative ranking accuracy for the target user base.
* **Labeling:** The ground-truth labels (originally 1-5) were averaged from 60 human raters and linearly scaled to a 1-10 range.
* **Performance:** The model achieves a **Mean Absolute Error (MAE) of 0.61** on the test set.

---

## Ethical & Technical Limitations

Please note that "beauty" is subjective and culturally dependent. This model has the following inherent biases:
1.  **Rater Bias:** The model mimics the preferences of the original 60 raters (university students), favoring specific aesthetic traits like neoteny (youthfulness).
2.  **Lens Distortion:** The model was trained on portrait-focal-length photos. Wide-angle selfie camera shots may result in lower scores due to geometric distortion (e.g., nose enlargement).

---

## Credits & Citations

This project is made possible by the **SCUT-FBP5500 Database**. We gratefully acknowledge the researchers at South China University of Technology for providing this dataset for academic and research use.

**Citation:**
> Liang, L., Lin, L., Jin, L., Xie, D., & Li, M. (2018). **SCUT-FBP5500: A Diverse Benchmark Dataset for Multi-Paradigm Facial Beauty Prediction.** *In 2018 24th International Conference on Pattern Recognition (ICPR)* (pp. 1598-1603). IEEE.

**Repository:** [SCUT-FBP5500 Database Release](https://github.com/HCIILAB/SCUT-FBP5500-Database-Release)

## Disclaimer: Educational Purposes Only

This AI scoring engine was built strictly for **educational and portfolio demonstration purposes**. It should *not* be taken seriously or used as a genuine measure of human attractiveness. 

If you test the model with your own photo, please be aware that the algorithm is **extremely sensitive** to the following factors:

* **Facial Orientation (Pose):** The model was trained on straight-facing, passport-style images. Tilted heads, profile shots, or looking away from the camera will severely artificially lower the score.
* **Photo Quality & Lighting:** Harsh shadows, poor lighting, or camera lens distortion (such as wide-angle selfie lenses making noses appear larger) will negatively skew the mathematical embedding.
* **Phenotype & Rater Bias:** The ground-truth data relies on a specific subset of the SCUT-FBP5500 dataset, meaning the model is hardcoded to the subjective, culturally-dependent biases of the original raters which were chinese college students so they gave harsher ratings to caucasian people.

**TL;DR:** The scoring mechanism is highly rigid. If you upload a photo and receive a low rating, blame the dataset variance and the camera angle, not your face!

## Getting Started

The project has two parts that run together: a **Flutter app** (`lib/`) and a **Python FastAPI backend** (`backend/`) backed by PostgreSQL. Both use the same Firebase project. The steps below take you from an empty folder to a running app.

### Prerequisites

Install these first:

* **Flutter SDK** — Dart `>= 3.8.1` (run `flutter doctor` and resolve any issues).
* **Python 3.10+**.
* **PostgreSQL 13+** — running locally or reachable remotely.
* **A Firebase project** with **Authentication** (Email/Password + Phone), **Firestore**, **Cloud Messaging (FCM)** and **Storage** enabled.
* Android Studio and/or Xcode if you want to run on an emulator/simulator.

> **Secrets are not in the repo.** `backend/.env`, `backend/serviceAccountKey.json`, `lib/firebase_options.dart`, `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist` are all gitignored. After forking, you must create them yourself using the steps below.

### 1. Fork & clone

Fork the repo on GitHub, then clone **your** fork:

```bash
git clone https://github.com/<your-username>/FoitiFinder.git
cd FoitiFinder
```

### 2. Backend (FastAPI + PostgreSQL)

```bash
cd backend

# Create and activate a virtual environment
python -m venv venv
# Windows (PowerShell):
venv\Scripts\Activate.ps1
# macOS / Linux:
# source venv/bin/activate

# Install backend dependencies (this is large — it includes TensorFlow/DeepFace)
pip install -r requirements.txt
```

**Create the database.** Make an empty PostgreSQL database (the app creates its tables automatically on first start, so no migrations are needed):

```bash
createdb foitifinder        # or: psql -c "CREATE DATABASE foitifinder;"
```

**Configure the connection.** Copy the example env file and edit it with your own credentials:

```bash
copy .env.example .env       # Windows
# cp .env.example .env       # macOS / Linux
# then edit DATABASE_URL inside backend/.env
```

**Add the Firebase Admin key.** In the [Firebase Console](https://console.firebase.google.com/) → **Project settings → Service accounts → Generate new private key**. Save the downloaded JSON as `backend/serviceAccountKey.json` (exact name).

**Run the backend** (from the `backend/` folder, so the relative paths to the key and model resolve):

```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

You should see Uvicorn start on `http://0.0.0.0:8000`. Visit `http://127.0.0.1:8000/docs` for the interactive API.

**(Optional) Run the backend tests:**

```bash
pip install -r requirements-dev.txt
python -m pytest
```

### 3. Firebase (client side)

From the project root, generate the client Firebase config:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

This creates `lib/firebase_options.dart` and the platform files. Alternatively, copy your Firebase project’s `google-services.json` into `android/app/` and `GoogleService-Info.plist` into `ios/Runner/` as documented in the [FlutterFire setup](https://firebase.google.com/docs/flutter/setup). These files are gitignored and must not be committed.

### 4. Frontend (Flutter)

From the project root:

```bash
flutter pub get          # install Dart/Flutter dependencies
flutter gen-l10n         # generate localization (English + Greek)
```

**Point the app at your backend.** The app defaults to `http://127.0.0.1:8000` (and matching `ws://…` for chat). Override with `--dart-define` when the backend is not on localhost:

* Physical device on the same LAN: `flutter run --dart-define=API_BASE_URL=http://YOUR_PC_LAN_IP:8000`
* Android emulator (host loopback): `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000`
* Custom WebSocket base only: add `--dart-define=WS_BASE_URL=ws://host:8000`

**Run the app** (start the backend from step 2 first):

```bash
flutter run              # add any --dart-define flags from above
```

### 5. AI scoring model

The trained model (`backend/matchmaker/rating_model.pkl`) is **already included** in the repo, so the scoring endpoint works out of the box. To retrain or reproduce it from scratch, see [`research/methodology.md`](research/methodology.md).


