plugins {
    id("com.android.application")
    kotlin("android")
}

/**
 * Release signing material is intentionally supplied out of band. Gradle
 * properties can be passed with -P or kept in the operator Gradle directory;
 * CI may instead inject environment variables.
 */
fun signingInput(name: String): String? =
    providers.gradleProperty(name)
        .orElse(providers.environmentVariable(name))
        .orNull
        ?.takeIf { it.isNotBlank() }

val releaseStoreFile = signingInput("OA_AGENT_SIGNING_STORE_FILE")
val releaseStorePassword = signingInput("OA_AGENT_SIGNING_STORE_PASSWORD")
val releaseKeyAlias = signingInput("OA_AGENT_SIGNING_KEY_ALIAS")
val releaseKeyPassword = signingInput("OA_AGENT_SIGNING_KEY_PASSWORD")
val releaseSigningConfigured = listOf(
    releaseStoreFile,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
).all { it != null }

val releaseSigningHelp = """
    Android release signing requires OA_AGENT_SIGNING_STORE_FILE,
    OA_AGENT_SIGNING_STORE_PASSWORD, OA_AGENT_SIGNING_KEY_ALIAS, and
    OA_AGENT_SIGNING_KEY_PASSWORD. Provide them as Gradle properties or
    environment variables through CI/secure local Gradle configuration; never
    add them to this repository.
""".trimIndent()

android {
    namespace = "com.oamanager.agent"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.oamanager.agent"
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "1.0.0"
    }

    signingConfigs {
        create("release") {
            if (releaseSigningConfigured) {
                storeFile = file(requireNotNull(releaseStoreFile))
                storePassword = requireNotNull(releaseStorePassword)
                keyAlias = requireNotNull(releaseKeyAlias)
                keyPassword = requireNotNull(releaseKeyPassword)
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            if (releaseSigningConfigured) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

gradle.taskGraph.whenReady {
    val releaseArtifactRequested = allTasks.any { task ->
        task.project == project &&
            task.name.contains("Release", ignoreCase = true) &&
            listOf("assemble", "bundle", "package", "sign").any { prefix ->
                task.name.startsWith(prefix, ignoreCase = true)
            }
    }

    check(!releaseArtifactRequested || releaseSigningConfigured) {
        releaseSigningHelp
    }
}

dependencies {
    // KMP 공유 모듈
    implementation(project(":shared"))

    // AndroidX
    implementation("androidx.work:work-runtime-ktx:2.9.0")
    implementation("androidx.security:security-crypto:1.1.0-alpha06")
    implementation("androidx.lifecycle:lifecycle-viewmodel-ktx:2.7.0")
    implementation("androidx.activity:activity-ktx:1.8.2")
    implementation("androidx.appcompat:appcompat:1.6.1")

    // Material Design
    implementation("com.google.android.material:material:1.11.0")


    // JSON (kotlinx.serialization — shared 모듈의 API 타입 접근용)
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.3")

    // Coroutines
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.0")
}
