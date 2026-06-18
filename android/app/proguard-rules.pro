# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep WebView JS interface
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Keep file picker
-keep class com.mr.flutter.plugin.filepicker.** { *; }

# Keep image picker
-keep class io.flutter.plugins.imagepicker.** { *; }

# Keep share plus
-keep class dev.fluttercommunity.plus.share.** { *; }

# Dart/Flutter
-dontwarn io.flutter.**
