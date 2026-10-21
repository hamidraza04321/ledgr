# Ledgr: setup guide

Ledgr works right away in **guest mode** (offline, data on the device).
Google sign-in, cloud sync and Gemini chat assist start working once you
connect a Firebase project (steps below, about 15 minutes).

---

## 1. Build & run (important: folder name)

The project folder name contains `&` (`Expense & Income Tracker`), and Windows'
Gradle script breaks on `&`. Use a junction (a shortcut path) once:

```powershell
New-Item -ItemType Directory -Force C:\dev
New-Item -ItemType Junction -Path C:\dev\ledgr -Target "C:\Users\UHF-IT\OneDrive\Desktop\Expense & Income Tracker"
```

Then always build/run from `C:\dev\ledgr`:

```powershell
cd C:\dev\ledgr
# Installable APK for modern phones (arm64), smallest download:
flutter build apk --release --target-platform android-arm64
# → build\app\outputs\flutter-apk\app-release.apk (copy to phone & install)

flutter run                 # phone connected with USB debugging
```

On a slow connection, the first build downloads Flutter's engine once
(~40 MB for release arm64; debug builds need ~170 MB per CPU type).

Alternative: rename the folder to `Expense and Income Tracker`, or move the
project out of OneDrive (OneDrive syncing the `build` folder slows builds).

---

## 2. Create the Firebase project

1. Open <https://console.firebase.google.com> → **Add project** → name it
   `Ledgr` (Google Analytics is optional).
2. **Add app → Android**
   - Package name: `com.ledgrapp.ledgr`
   - App nickname: `Ledgr`
   - Debug signing certificate SHA-1 (this PC's debug key):
     `7F:3C:A0:F6:4A:26:19:2C:53:C4:57:F7:68:DD:52:DD:73:C4:4E:11`
   - In **Project settings → Your apps → Android**, also add the SHA-256:
     `2B:DB:DD:BE:BC:47:FD:71:54:FE:87:A8:48:D1:DE:FC:F0:AD:D5:55:69:E8:B9:AA:61:12:41:2B:E0:9F:07:B8`
   - On another PC, print that PC's own SHA-1 and SHA-256 with:
     `keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android`
3. **Build → Authentication → Get started → Sign-in method → Google →
   Enable** (pick a support email) → Save.
4. **Build → Firestore Database → Create database** → choose a location
   close to you (for example `asia-south1`) → **production mode**.
   Open the **Rules** tab, paste the contents of [`firestore.rules`](firestore.rules)
   and click **Publish**.
5. **Build → AI Logic → Get started → Gemini Developer API** (free tier,
   no billing needed). This powers the AI assist in chat.
   AI Logic requires **App Check** (enforcement becomes mandatory on
   2 Nov 2026). In **Security → App Check → Apps**, register the Ledgr
   Android app with **Play Integrity**. Side-loaded APKs can't pass Play
   Integrity, so Ledgr also ships a debug token (see section 3, step 4).

## 3. Connect the app

1. **Project settings → Your apps → Android → download
   `google-services.json`**. Download it *after* steps 2–3 so it contains
   the Google sign-in client IDs.
2. Put it here: `android/app/google-services.json`
3. Run, from `C:\dev\ledgr`:

   ```powershell
   dart run tool/configure_firebase.dart
   ```

   This writes `lib/firebase_options.dart`, the Google Web client ID and
   (first time only) an App Check debug token in
   `lib/core/config/app_check_token.dart`.
   If you cloned the project from GitHub, that file holds an empty token
   (the real one is never uploaded). Delete the file before running the
   command so it generates a token of your own.
4. Copy the token from `lib/core/config/app_check_token.dart` and add it in
   **App Check → Apps → Ledgr → ⋮ (three dots) → Manage debug tokens →
   Add debug token** (name it e.g. `Ledgr APK`).
   Keep this token private: anyone with it can call Gemini on your project.
   For a Play Store release, set the token to `''` to use Play Integrity.
5. Build again. **Continue with Google** now works, and chat shows
   *"Gemini assist on"*.

### Release builds

The release APK is currently signed with the debug key, so the SHA-1 above
also covers it. If you later create your own release keystore (for the Play
Store), add its SHA-1 and SHA-256 in Firebase too, and also the
**Play App Signing** SHA-1 from Play Console.

---

## How data is stored

| Mode    | Where data lives                         | Offline |
|---------|------------------------------------------|---------|
| Guest   | SQLite on the phone only                 | ✔       |
| Google  | SQLite on the phone + Firestore `users/{uid}/…` | ✔ (syncs when back online) |

- Signing in with Google **moves your guest entries into the account**.
- Sync is automatic: changes upload about 2 seconds after you make them,
  and changes from other devices arrive live.
- Conflicts: the most recent edit wins.
- Chat history stays on the device (entries themselves are synced).
- Signing out removes the data from that phone (it stays in the cloud).

## Troubleshooting

| Problem | Fix |
|---|---|
| "Google sign-in is misconfigured" | SHA-1/SHA-256 missing in Firebase, or `google-services.json` downloaded before enabling Google sign-in. Fix, re-download, re-run step 3. |
| "Google did not return an ID token" | Web client ID is empty. Re-run `dart run tool/configure_firebase.dart` with a fresh `google-services.json`. |
| Sync shows "Sync problem" | Firestore rules not published, or database not created (step 2.4). |
| Chat never uses Gemini | Enable AI Logic (step 2.5); check the "Gemini assist" switch in **More**. The offline parser still works without it. |
| Gemini error "Firebase App Check token is invalid" | The debug token is not registered (section 3, step 4), or the app isn't registered in App Check. |
| Gradle: `'Income' is not recognized` | You are building from the `&` path. See section 1. |
| Gradle: `No such host is known` | Network/DNS hiccup while downloading. Run the build again. |
