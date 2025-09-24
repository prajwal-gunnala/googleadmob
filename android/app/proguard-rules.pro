# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.kts.
#
# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# If your project uses WebView with JS, uncomment the following
# and specify the fully qualified class name to the JavaScript interface
# class:
#-keepclassmembers class fqcn.of.javascript.interface.for.webview {
#   public *;
#}

# Uncomment this to preserve the line number information for
# debugging stack traces.
#-keepattributes SourceFile,LineNumberTable

# If you keep the line number information, uncomment this to
# hide the original source file name.
#-renamesourcefileattribute SourceFile

# Flutter and Dart specific rules
-keep class io.flutter.** { *; }
-keep class androidx.lifecycle.** { *; }
-keepattributes *Annotation*

# Google Play Core - Industry standard comprehensive rules
-keep class com.google.android.play.core.** { *; }
-keep interface com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Google Mobile Ads
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Video Player
-keep class io.flutter.plugins.videoplayer.** { *; }

# Image Picker
-keep class io.flutter.plugins.imagepicker.** { *; }

# Permission Handler
-keep class com.baseflow.permissionhandler.** { *; }

# Path Provider
-keep class io.flutter.plugins.pathprovider.** { *; }

# Gal (Gallery) plugin
-keep class dev.flutter.gal.** { *; }

# Android Support / AndroidX
-keep class androidx.** { *; }
-keep interface androidx.** { *; }

# Gson (if used by any dependencies)
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }

# OkHttp (common HTTP library)
-dontwarn okhttp3.**
-dontwarn okio.**

# Retrofit (if used)
-dontwarn retrofit2.**
-keep class retrofit2.** { *; }

# General Android rules
-keepclassmembers class * extends android.app.Activity {
    public void *(android.view.View);
}

-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
