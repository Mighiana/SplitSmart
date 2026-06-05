# Dev flavor Firebase config

The `dev` build flavor points at a **separate sandbox Firebase project** so testing
never touches production user data.

## One-time setup (you, in the Firebase console)

1. Create a new Firebase project, e.g. **`splitsmart-dev`** (Spark/free plan is fine).
2. Add an **Android app** with package name **`com.splitsmart.splitsmart.dev`**
   (note the `.dev` suffix — this is the dev flavor's applicationId).
3. Download that project's **`google-services.json`** and place it here:

       android/app/src/dev/google-services.json

4. (Optional) In the dev project, enable the same products you use in prod:
   Authentication (Email/Password + Google), Firestore, Storage, App Check.
5. Update `firebase/.firebaserc` → replace `REPLACE_WITH_DEV_PROJECT_ID` with the
   dev project id so `firebase deploy --project dev …` targets the sandbox.

Until that file exists, `--flavor dev` builds will fail with a missing
`google-services.json` error (by design).

## Build commands (flavors are now REQUIRED)

    flutter run --flavor dev  -d <device>        # sandbox
    flutter run --flavor prod -d <device>        # production
    flutter build apk --release --flavor prod

Prod uses the existing `android/app/google-services.json` (root) via the
google-services plugin's fallback, so production builds keep working unchanged.
