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
