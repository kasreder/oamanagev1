plugins {
    kotlin("jvm") version "1.9.22"
    kotlin("plugin.serialization") version "1.9.22"
    application
}

application {
    mainClass.set("com.oamanager.agent.windows.MainKt")
}

dependencies {
    // KMP shared 모듈 (desktop 타겟)
    implementation(project(":shared"))

    // Ktor CIO 엔진 (Windows용 HTTP/WebSocket)
    implementation("io.ktor:ktor-client-cio:2.3.8")

    // Coroutines
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.8.0")

    // JSON
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.3")
}

kotlin {
    jvmToolchain(17)
}

tasks.jar {
    manifest {
        attributes["Main-Class"] = "com.oamanager.agent.windows.MainKt"
    }
    // Fat JAR (모든 의존성 포함)
    duplicatesStrategy = DuplicatesStrategy.EXCLUDE
    from(configurations.runtimeClasspath.get().map { if (it.isDirectory) it else zipTree(it) })
}

tasks.register<Copy>("dist") {
    dependsOn("jar")
    from(tasks.jar.get().archiveFile)
    from("install")
    into(layout.buildDirectory.dir("dist"))
}
