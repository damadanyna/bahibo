# Banay Android Release

## 1. Release signing

1. Generate an upload keystore once on your machine.
2. Save the keystore outside Git, for example in `keystores/upload-keystore.jks` at the project root.
3. Copy `android/key.properties.example` to `android/key.properties`.
4. Replace the placeholder values in `android/key.properties`:

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=../keystores/upload-keystore.jks
```

PowerShell command to generate the keystore:

```powershell
keytool -genkeypair -v -keystore keystores/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Important:

- Keep the same keystore for every future Play Store update.
- Never commit `android/key.properties` or the `.jks` file.
- The Android project is configured to block `release` builds when `android/key.properties` is missing.

## 2. Versioning strategy

Flutter Android reads the version from `pubspec.yaml`:

```yaml
version: 1.0.0+1
```

- `1.0.0` is the user-facing `versionName`.
- `1` is the Android `versionCode`.

Recommended rules:

- Bug fix only: increment patch and build number. Example `1.0.0+1` -> `1.0.1+2`
- New backward-compatible feature: increment minor and build number. Example `1.0.1+2` -> `1.1.0+3`
- Breaking or major product change: increment major and build number. Example `1.1.0+3` -> `2.0.0+4`
- `versionCode` must always increase for every Play Store upload.

Recommended release flow:

1. Update `version:` in `pubspec.yaml`.
2. Run `flutter pub get` if dependencies changed.
3. Build the bundle:

```powershell
flutter build appbundle --release
```

Output:

`build/app/outputs/bundle/release/app-release.aab`

## 3. Firebase checklist

1. Open Firebase Console.
2. Open project `bahibo-865e5`.
3. Add Android app with package name `com.banay.app`.
4. Download the generated `google-services.json`.
5. Replace `android/app/google-services.json` with the downloaded file.
6. Confirm Firebase services used by the app are enabled for this Android app.
7. If you use SHA certificates for Auth, Dynamic Links, or App Check, register the SHA-1 and SHA-256 from your release/upload keystore.

Command to print SHA fingerprints from the keystore:

```powershell
keytool -list -v -keystore keystores/upload-keystore.jks -alias upload
```

## 4. Google Play Console checklist

1. Create the app in Play Console if it does not exist yet.
2. Use package name `com.banay.app`.
3. Complete the store listing, app access, content rating, privacy policy, and Data safety forms.
4. Enroll in Play App Signing when prompted.
5. Upload `build/app/outputs/bundle/release/app-release.aab` to an internal testing track first.
6. Verify install, login, notifications, and upgrade behavior from the internal track build.
7. Promote to closed, open, or production after validation.

## 5. First publication preflight

1. `flutter clean`
2. `flutter pub get`
3. Confirm `pubspec.yaml` version is correct.
4. Confirm `android/key.properties` points to the real upload keystore.
5. Confirm `android/app/google-services.json` comes from Firebase for `com.banay.app`.
6. Run `flutter build appbundle --release`.
7. Upload the generated `.aab` to Play Console.