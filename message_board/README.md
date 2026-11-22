# Message Board Vault

CSC 4360 · Mobile App Development · Homework 02 · Undergraduate track

One Android Flutter board. Registration has two steps: create an email/password account, then finish the private profile with your first and last names. A signed-in account with an incomplete profile returns to that step after relaunch. The board opens after Firestore confirms the profile exists.

## 1. Set up Firebase on Windows

1. Install Flutter stable and Android Studio. In Android Studio, install the Android SDK and command-line tools and create an Android Virtual Device. Start it. In PowerShell, check:

   ```powershell
   flutter doctor
   flutter doctor --android-licenses
   flutter devices
   ```

2. Open the [Firebase Console](https://console.firebase.google.com/) and create a project for this homework. In **Build → Authentication → Get started → Sign-in method**, enable **Email/Password**. In **Build → Firestore Database → Create database**, create the default database in **Production mode**. Select a region. The app creates collections when the first profile and post are saved.

3. With Node.js 22 installed, open PowerShell in the extracted `message_board` folder. Run:

   ```powershell
   npm install -g firebase-tools
   firebase login
   dart pub global activate flutterfire_cli
   flutter pub get
   $projectId = Read-Host "Enter your Firebase project ID from Project settings"
   dart pub global run flutterfire_cli:flutterfire configure --project=$projectId --platforms=android
   firebase deploy --only firestore:rules --project $projectId
   ```

   Choose Android if prompted. FlutterFire should generate `lib/firebase_options.dart` for the project and configure Android. Use the exact project ID, which can differ from the display name. Deploy from this folder so the CLI reads its `firebase.json` and `firestore.rules`. Check that the deployed rules appear in **Firestore Database → Rules**. The Android package is `edu.gsu.message_board`.

4. With the Android emulator running, launch:

   ```powershell
   flutter analyze
   flutter run --dart-define=RULES_CHECKS=true
   ```

   Register a fictional test account, finish its profile, and verify Authentication → Users and Firestore → Data. Create a second test account for live updates and ownership checks.

## 2. Data model and ownership

| Path | Field | Writer and purpose |
| --- | --- | --- |
| `users/{uid}` | `uid` | App copies the signed-in Firebase Auth UID. The rules require it to match the document ID and auth UID. |
| | `firstName`, `lastName` | Account owner supplies these once during profile completion. |
| | `role` | App sets `member` at creation. The rules accept that value only. The role is descriptive. |
| | `registrationDateTime` | Firestore resolves the server timestamp when the profile is created. |
| `messages/{messageId}` | `text` | Author writes the initial text and can edit it later. |
| | `authorUid` | App copies the signed-in UID at creation. Rules bind it to the account and make it immutable. |
| | `authorName` | App copies the profile name at creation. Rules match it to the profile and make it immutable. It is visible on the board. |
| | `createdAt` | Firestore resolves the creation timestamp. Rules make it immutable. |
| | `editedAt` | App starts it at null. Firestore resolves a fresh server timestamp on edits. |

Firebase Auth manages credentials and session persistence. A private profile is readable only by its own account and is created once. Signed-in accounts can read all messages. Rules limit message edits and deletes to the owner and block unexpected fields at creation. Profile names appear publicly as author names, so use fictional names in evidence. Passwords, email addresses, and tokens are absent from Firestore documents. Drafts live in the current board screen's memory.

`AuthService` handles identity and exposes one stable auth stream. `BoardService` handles profile reads/writes, live ordered board reads, and message writes. A single `StreamBuilder` subscribes while the board is mounted and releases the listener on sign-out.

Message creation uses a Firestore transaction and one generated document ID per submission. A retry with the same draft reuses that ID while the screen is open. Rapid taps are also blocked while a post is in flight. Create requires a connection. A separate successful submission, a changed draft, or a draft re-entered after relaunch gets a new ID. Edits and deletes use ordinary Firestore writes and can wait for reconnect; a cached board and pending edits have visible indicators.

## 3. Run the three undergraduate choice spices

### #1 · Emulator Explorer

Use an Android Studio emulator and a current JDK 21. In one PowerShell window:

```powershell
firebase emulators:start --project demo-vault-hunt --only auth,firestore
```

In a second PowerShell window in the same project folder:

```powershell
flutter run --dart-define=USE_EMULATORS=true --dart-define=RULES_CHECKS=true
```

The Android emulator reaches the host at `10.0.2.2`. The app selects a dedicated Firebase app with the demo project ID and redirects both services to the local suite before making requests. Register two fictional accounts and create two posts in this mode to seed the local data. Screenshot the **Local emulator** app label and Emulator UI at [http://localhost:4000](http://localhost:4000). Compare the production Auth and Firestore consoles before and after, using unique seed names that appear only in the emulator. Stop this emulator session before running the isolated test suite below.

### #2 · Rules Unit Tester

```powershell
npm --prefix rules-tests ci
firebase emulators:exec --project demo-vault-hunt --only firestore "npm --prefix rules-tests test"
```

Capture the test names and pass/fail summary. The suite covers signed-out list denial, signed-in shared reads, cross-owner update/delete denial, forged attribution, owner CRUD, profile privacy and role constraints, and a duplicate transaction. It uses an isolated local project and clears its test data between cases.

### #4 · Idempotent Alchemist

Use the same-ID transaction test output from #2 and independently rapid-tap **Post** on the release app with a unique message. In Firestore Data, verify exactly one matching document and capture its ID. The test issues two concurrent calls with the same document ID, which exercises deduplication beyond the disabled UI button.

## 4. Build and test the exact APK

```powershell
flutter analyze
flutter build apk --release --dart-define=RULES_CHECKS=true
adb install -r .\build\app\outputs\flutter-apk\app-release.apk
Get-FileHash .\build\app\outputs\flutter-apk\app-release.apk -Algorithm SHA256
```

If more than one device is connected, run `adb devices` and use `adb -s DEVICE_SERIAL install -r .\build\app\outputs\flutter-apk\app-release.apk` for each one. If PowerShell cannot find adb, run it from your Android SDK’s `platform-tools` folder or add that folder to PATH. Use the same APK on both devices and attach that same file. Record its hash and device details. Use a dedicated assignment Firebase project and disposable posts for the rules checks. Follow the [Flutter signing guide](https://docs.flutter.dev/deployment/android) for a release signing key if your course requires one. The standard Flutter Android scaffold signs locally installable release builds with its debug key until you configure release signing.

The rules-check build shows **Test signed-out board read** on the sign-in screen. On account B, open the action menu of a disposable message written by account A and choose **Test cross-user update**, then **Test cross-user delete**. These send real Firestore requests. Capture the returned `permission-denied` and verify A's post is still present. Run the forged-author denial in the automated suite. To build without diagnostic buttons later, omit the `RULES_CHECKS` flag.

Use [EVIDENCE_CHECKLIST.md](EVIDENCE_CHECKLIST.md) to capture and write your results. Submit the public GitHub URL, the tested release APK, and one Word or PDF reflection/evidence document. The GitHub repo should include the Firebase setup guide, source, rules, and test package. Keep signing keys and service-account credentials out of the repo.

### Official references

- [FlutterFire setup](https://firebase.google.com/docs/flutter/setup)
- [Flutter Auth and session persistence](https://firebase.google.com/docs/auth/flutter/start)
- [Realtime listeners](https://firebase.google.com/docs/firestore/query-data/listen)
- [Offline behavior](https://firebase.google.com/docs/firestore/manage-data/enable-offline)
- [Transactions](https://firebase.google.com/docs/firestore/manage-data/transactions)
- [Rules tests](https://firebase.google.com/docs/rules/unit-tests)
- [Android release builds](https://docs.flutter.dev/deployment/android)
