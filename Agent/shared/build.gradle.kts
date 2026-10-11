import java.net.URI
import java.nio.charset.StandardCharsets
import java.util.Base64

plugins {
    kotlin("multiplatform")
    kotlin("plugin.serialization")
    id("com.android.library")
}

/**
 * Runtime endpoint configuration is intentionally supplied outside the source
 * tree. The Supabase anon key is a public client identifier, but keeping it
 * out of Git prevents a stale environment key from being released again.
 */
fun agentBuildInput(name: String): String? =
    providers.gradleProperty(name)
        .orElse(providers.environmentVariable(name))
        .orNull
        ?.trim()
        ?.takeIf { it.isNotEmpty() }

fun requireAgentBuildInput(name: String): String =
    agentBuildInput(name)
        ?: throw GradleException(
            "$name is required to compile the OA Agent. Supply it through a " +
                "Gradle property (-P$name=...) or environment variable; never commit it.",
        )

fun requireAgentSupabaseUrl(): String {
    val value = requireAgentBuildInput("OA_AGENT_SUPABASE_URL").removeSuffix("/")
    val uri = runCatching { URI(value) }.getOrElse {
        throw GradleException("OA_AGENT_SUPABASE_URL must be an absolute HTTPS URL.")
    }

    check(uri.scheme == "https" && !uri.host.isNullOrBlank()) {
        "OA_AGENT_SUPABASE_URL must be an absolute HTTPS URL."
    }
    return value
}

fun requireAgentAnonKey(): String {
    val value = requireAgentBuildInput("OA_AGENT_SUPABASE_ANON_KEY")
    val parts = value.split('.')
    check(parts.size == 3) {
        "OA_AGENT_SUPABASE_ANON_KEY must be a JWT-shaped Supabase anon key."
    }

    val payload = runCatching {
        String(Base64.getUrlDecoder().decode(parts[1]), StandardCharsets.UTF_8)
    }.getOrElse {
        throw GradleException("OA_AGENT_SUPABASE_ANON_KEY has an invalid JWT payload.")
    }
    check(Regex("\\\"role\\\"\\s*:\\s*\\\"anon\\\"").containsMatchIn(payload)) {
        "OA_AGENT_SUPABASE_ANON_KEY must carry the anon role."
    }
    return value
}

fun kotlinStringLiteral(value: String): String = buildString {
    append('"')
    value.forEach { character ->
        when (character) {
            '\\' -> append("\\\\")
            '"' -> append("\\\"")
            '\n' -> append("\\n")
            '\r' -> append("\\r")
            '\t' -> append("\\t")
            else -> append(character)
        }
    }
    append('"')
}

val generatedAgentConfigDir = layout.buildDirectory.dir(
    "generated/source/agentRuntimeConfig/commonMain/kotlin",
)
val generatedAgentConfigFile = generatedAgentConfigDir.map { directory ->
    directory.file("com/oamanager/agent/GeneratedAgentRuntimeConfig.kt")
}

val generateAgentRuntimeConfig by tasks.registering {
    group = "build setup"
    description = "Generates the OA Agent runtime endpoint configuration from secure build inputs."
    outputs.file(generatedAgentConfigFile)
    // Do not cache a generated source file that contains a deployment-specific key.
    outputs.upToDateWhen { false }
    outputs.cacheIf { false }

    doLast {
        val output = generatedAgentConfigFile.get().asFile
        output.parentFile.mkdirs()
        output.writeText(
            """
            |// Generated during the build. Do not edit or commit this file.
            |package com.oamanager.agent
            |
            |internal object GeneratedAgentRuntimeConfig {
            |    const val SUPABASE_URL: String = ${kotlinStringLiteral(requireAgentSupabaseUrl())}
            |    const val SUPABASE_ANON_KEY: String = ${kotlinStringLiteral(requireAgentAnonKey())}
            |}
            """.trimMargin() + "\n",
            StandardCharsets.UTF_8,
        )
    }
}

kotlin {
    androidTarget {
        compilations.all {
            kotlinOptions {
                jvmTarget = "17"
            }
        }
    }

    jvm("desktop") {
        compilations.all {
            kotlinOptions {
                jvmTarget = "17"
            }
        }
    }

    sourceSets {
        val commonMain by getting {
            kotlin.srcDir(generatedAgentConfigDir)
            dependencies {
                // HTTP Client
                implementation("io.ktor:ktor-client-core:2.3.8")
                implementation("io.ktor:ktor-client-content-negotiation:2.3.8")
                implementation("io.ktor:ktor-serialization-kotlinx-json:2.3.8")
                // WebSocket (Realtime)
                implementation("io.ktor:ktor-client-websockets:2.3.8")
                // JSON
                implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.3")
                // Coroutines
                implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.8.0")
                // DateTime
                implementation("org.jetbrains.kotlinx:kotlinx-datetime:0.5.0")
            }
        }
        val androidMain by getting {
            dependencies {
                implementation("io.ktor:ktor-client-okhttp:2.3.8")
            }
        }
        val desktopMain by getting {
            dependencies {
                implementation("io.ktor:ktor-client-cio:2.3.8")
            }
        }
    }
}

// Every Kotlin target consumes commonMain, so generate the source before any
// Android or JVM compilation without requiring platform-specific duplication.
tasks.configureEach {
    if (name.startsWith("compile") && name.contains("Kotlin")) {
        dependsOn(generateAgentRuntimeConfig)
    }
}

android {
    namespace = "com.oamanager.agent.shared"
    compileSdk = 36

    defaultConfig {
        minSdk = 26
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}
