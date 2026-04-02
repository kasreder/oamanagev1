# OA Agent ProGuard Rules
-keep class com.oamanager.agent.** { *; }
-keep class io.ktor.** { *; }
-keep class kotlinx.serialization.** { *; }
-keep class kotlinx.coroutines.** { *; }

# AndroidX / WorkManager / Lifecycle
-keep class androidx.work.** { *; }
-keep class androidx.lifecycle.** { *; }
-keep class androidx.security.crypto.** { *; }
-keep class androidx.startup.** { *; }

# Ktor engine
-keep class io.ktor.client.engine.okhttp.** { *; }

# Suppress warnings
-dontwarn org.slf4j.**
-dontwarn java.lang.management.**
-dontwarn io.ktor.util.debug.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**
