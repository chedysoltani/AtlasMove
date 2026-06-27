# Google Play Core (missing classes fix)
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

# Agora RTC Engine
-keep class io.agora.** { *; }
-keep class io.agora.rtc2.** { *; }
-dontwarn io.agora.**

# Android audio
-keep class android.media.audiofx.** { *; }

# Flutter plugins reflection
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Stripe
-keep class com.stripe.** { *; }
-dontwarn com.stripe.**

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Socket.IO
-keep class io.socket.** { *; }
-dontwarn io.socket.**

# OkHttp (used by multiple libs)
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }

# Gson (JSON parsing)
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }

# Geolocator
-keep class com.baseflow.geolocator.** { *; }

# Google Maps
-keep class com.google.android.gms.maps.** { *; }
-keep class com.google.maps.** { *; }
