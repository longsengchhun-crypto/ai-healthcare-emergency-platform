# Keep Flutter plugin entry points; R8 handles the rest.
-keep class io.flutter.plugins.** { *; }
-dontwarn com.google.android.play.core.**
