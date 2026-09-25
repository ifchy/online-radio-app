# Release signing: the upload key, GitHub secrets and signed builds

This guide is for the owner. It explains how to create the eRadioto **upload key**, give it to
GitHub Actions without ever committing it, and get a signed APK onto a phone.

> **This repository is public.** The keystore, its passwords, `key.properties` and any base64
> copy of the keystore must never be committed, pasted into an issue or PR, or kept in a
> cloud-synced copy of the repo. `.gitignore` blocks `*.jks`, `*.keystore`, `*.p12`,
> `key.properties` and `*.b64`, but it is only a safety net.

## How it fits together

| Piece | Where it lives |
|---|---|
| Upload keystore `eradioto-upload.jks` | Your Mac (outside the repo) plus an offline or password-manager backup |
| The four signing secrets | GitHub → repo → Settings → Secrets and variables → Actions |
| `.github/workflows/release.yml` | Runs only for `v*` tags and manual runs. It decodes the keystore into the runner's temp folder, writes `android/key.properties`, builds, checks the signature, uploads the artifacts, then deletes both files. |
| `.github/workflows/ci.yml` | Runs on every PR and every push to `main`. It has no access to the secrets. Its release build is debug-signed and is never uploaded. |
| `android/app/build.gradle.kts` | Signs release builds with `android/key.properties` when that file exists, otherwise with the debug key, so `flutter run --release` works without a key. |

The four secrets:

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | The keystore file, base64-encoded on one line |
| `ANDROID_KEYSTORE_PASSWORD` | The keystore password you choose in step 1 |
| `ANDROID_KEY_PASSWORD` | For a PKCS12 keystore, the same as the keystore password |
| `ANDROID_KEY_ALIAS` | `upload` |

If any of them is missing or empty, the release run stops at "Require signing secrets" before
it builds anything. CI never falls back to the debug key for a release.

## 1. Create the upload keystore (once, on your Mac)

Use the JDK 17 `keytool` (`keytool -version` should say 17 or later). Run it from your home
folder, not from the repo:

```bash
cd ~
keytool -genkeypair -v \
  -keystore ~/eradioto-upload.jks \
  -storetype PKCS12 \
  -keyalg RSA -keysize 2048 \
  -validity 10000 \
  -alias upload
```

- keytool asks for a keystore password (at least 6 characters), then for your name and
  organisation. The name ends up in the certificate; your own name or "eRadioto" is fine.
- With PKCS12 the key password is the keystore password, so keytool does not ask for a second one.
- Validity 10000 days is about 27 years. Google Play requires the certificate to be valid until
  at least October 2033.

## 2. Back it up before anything else

- Copy `~/eradioto-upload.jks` **and** its password into your password manager (as an attachment
  and a secret field), or onto offline storage such as an encrypted USB stick.
- Do **not** put the file in the repo folder, in a cloud-synced copy of the repo, or in a chat or
  email.
- Losing the upload key is recoverable once the app is on Google Play: Play App Signing holds the
  real app signing key, and you can ask Play Console support to reset the upload key (Phase 4).
  Before the app is on Play, a lost key means every tester has to uninstall and reinstall.

## 3. Add the four secrets to GitHub

With the GitHub CLI, from inside your local clone (so `gh` knows the repo):

```bash
base64 -i ~/eradioto-upload.jks | tr -d '\n' > ~/eradioto-upload.b64
gh secret set ANDROID_KEYSTORE_BASE64 < ~/eradioto-upload.b64
gh secret set ANDROID_KEYSTORE_PASSWORD     # prompts; paste the keystore password
gh secret set ANDROID_KEY_PASSWORD          # prompts; paste the same password
gh secret set ANDROID_KEY_ALIAS --body upload
rm ~/eradioto-upload.b64
gh secret list                               # shows the four names, never the values
```

(`base64 -i` is the macOS form. On Linux use `base64 -w0 ~/eradioto-upload.jks`.)

Without the CLI: GitHub → the repo → **Settings → Secrets and variables → Actions → New
repository secret**, once per secret. For `ANDROID_KEYSTORE_BASE64`, open the `.b64` file,
copy its whole content, and delete the file afterwards.

Always delete the `.b64` file when you are done. It is the keystore in text form.

## 4. Optional: a local `android/key.properties`

Only if you want local release builds signed with the upload key (for example to install over
a CI-built APK without uninstalling). Create `android/key.properties`:

```properties
storeFile=/Users/<you>/eradioto-upload.jks
storePassword=<keystore password>
keyPassword=<keystore password>
keyAlias=upload
```

Use the absolute path. The file is gitignored (in `.gitignore` and `android/.gitignore`). Check
with `git status` that it never shows up. Without it, `flutter run --release` signs with the
debug key, which is fine for day-to-day testing.

## 5. Run a signed build

**From a tag** (works as soon as the branch with `release.yml` is pushed, because a tag push
runs the workflow file from the tagged commit):

```bash
git tag v0.1.0-rc.1        # on the commit you want to build
git push origin v0.1.0-rc.1
```

**Manually**, once `release.yml` is on the default branch: GitHub → **Actions → release → Run
workflow**, then pick the branch.

Each run builds a release AAB and a release APK with the same `versionCode`, which is the
workflow run number. Minimum Android is 7.0 (API 24) and the target is API 36. The run fails if
either file is signed with the debug certificate, if the two files are signed with different
keys, or if the debug test stations leaked into the release build.

## 6. Download and install the APK

1. Open the finished run (Actions → release → the run). Under **Artifacts**, download
   `eradioto-v0.1.0-rc.1`. With the CLI: `gh run download <run-id> -n eradioto-v0.1.0-rc.1`.
2. Unzip it. It contains `app-release.aab` (for Google Play later) and `app-release.apk` (for
   your phone).
3. If the phone has a build signed with a different key (a local `flutter run` build is signed
   with the debug key), uninstall it first, otherwise the install fails with
   `INSTALL_FAILED_UPDATE_INCOMPATIBLE`:

   ```bash
   adb uninstall bg.izk.radio
   ```

4. Install and open it:

   ```bash
   adb install -r app-release.apk
   ```

## 7. Check who signed a file

```bash
keytool -printcert -jarfile app-release.aab
# APKs for minSdk 24+ carry only v2/v3 signatures, which keytool cannot read. Use apksigner
# from the Android SDK build-tools instead:
"$ANDROID_HOME"/build-tools/<version>/apksigner verify --print-certs app-release.apk
```

The owner line must show the name you entered in step 1, never `CN=Android Debug`. The SHA-256
fingerprint is the same for both files and for every later build.

## 8. Turn on secret scanning and push protection

GitHub → the repo → **Settings → Code security** (called "Code security and analysis" on older
accounts). Enable **Secret scanning** and **Push protection**. Both are free for public
repositories. Push protection blocks a push that contains a recognised secret.

## Upload key and app signing key

- The key you created is the **upload key**. It proves to Google Play that an upload comes from
  you.
- When the app goes to Play (Phase 4), enrol in **Play App Signing**. Google then keeps the real
  **app signing key** and re-signs what users download. If the upload key is ever lost or leaked,
  Play Console support can register a new upload key. The app signing key never leaves Google.
- Until then, the APKs you sideload are signed with the upload key directly. Keep using the same
  key so updates install over each other.

## If something goes wrong

| Failing step | What it means |
|---|---|
| Require signing secrets | One of the four secrets is missing or empty. `gh secret list` shows which exist. |
| Decode upload keystore | `ANDROID_KEYSTORE_BASE64` is not valid base64 of the `.jks`, the password is wrong, or the alias is not `upload`. Repeat step 3. |
| Verify not debug-signed | The build was not signed with the upload key. Paste this step's log (it contains only certificate names and fingerprints, which are public). |
| No debug stations in the release build | Debug-only test stations reached the release build. That is a code bug, not a key problem. |
