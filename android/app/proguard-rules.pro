# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
# sqflite
-keep class com.tekartik.** { *; }
# local_auth / biometric
-keep class androidx.biometric.** { *; }
# mobile_scanner
-keep class com.google.mlkit.** { *; }
# Prevent stripping of notification-related classes
-keep class com.dexterous.** { *; }
# Google Sign-In
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }
# Cloud Firestore
-keep class io.grpc.** { *; }

# Play Core deferred components
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task

# Ignore missing optional classes for ML Kit and gRPC/OkHttp
-dontwarn com.google.mlkit.**
-dontwarn io.grpc.**
-dontwarn com.squareup.okhttp.**
