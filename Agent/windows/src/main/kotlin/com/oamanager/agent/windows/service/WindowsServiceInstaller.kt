package com.oamanager.agent.windows.service

import java.io.File

/**
 * Windows 서비스 / Task Scheduler 등록 유틸리티.
 *
 * - Windows Task Scheduler: 로그온 시 자동 시작 (트레이 모드)
 * - sc.exe: Windows 서비스 등록 (WinSW 기반)
 *
 * 관리자 권한이 필요합니다.
 */
object WindowsServiceInstaller {

    private const val TASK_NAME = "OAAgent_Heartbeat"
    private const val SERVICE_NAME = "OAAgentService"

    /**
     * Windows Task Scheduler에 로그온 시 자동 시작 등록.
     *
     * 트레이 아이콘 모드로 실행합니다.
     */
    fun registerStartupTask(jarPath: String, javaPath: String = "javaw.exe"): Boolean {
        return try {
            val command = listOf(
                "schtasks.exe",
                "/Create",
                "/SC", "ONLOGON",
                "/TN", TASK_NAME,
                "/TR", "\"$javaPath\" -jar \"$jarPath\"",
                "/RL", "HIGHEST",
                "/F", // 기존 작업 덮어쓰기
            )
            val process = ProcessBuilder(command)
                .redirectErrorStream(true)
                .start()
            val exitCode = process.waitFor()
            if (exitCode == 0) {
                println("Startup task registered: $TASK_NAME")
                true
            } else {
                val output = process.inputStream.bufferedReader().readText()
                System.err.println("Task registration failed: $output")
                false
            }
        } catch (e: Exception) {
            System.err.println("Task registration error: ${e.message}")
            false
        }
    }

    /**
     * Task Scheduler 등록 해제.
     */
    fun unregisterStartupTask(): Boolean {
        return try {
            val process = ProcessBuilder(
                "schtasks.exe", "/Delete", "/TN", TASK_NAME, "/F"
            )
                .redirectErrorStream(true)
                .start()
            process.waitFor() == 0
        } catch (_: Exception) {
            false
        }
    }

    /**
     * 주기적 Heartbeat Task Scheduler 등록 (--send-now 모드).
     *
     * 트레이 모드를 사용하지 않을 때, Task Scheduler로 주기 실행.
     *
     * @param intervalMinutes 실행 주기 (분)
     */
    fun registerPeriodicTask(
        jarPath: String,
        intervalMinutes: Int = 15,
        javaPath: String = "java.exe",
    ): Boolean {
        return try {
            val taskName = "${TASK_NAME}_Periodic"
            val command = listOf(
                "schtasks.exe",
                "/Create",
                "/SC", "MINUTE",
                "/MO", intervalMinutes.toString(),
                "/TN", taskName,
                "/TR", "\"$javaPath\" -jar \"$jarPath\" --send-now",
                "/RL", "HIGHEST",
                "/F",
            )
            val process = ProcessBuilder(command)
                .redirectErrorStream(true)
                .start()
            val exitCode = process.waitFor()
            if (exitCode == 0) {
                println("Periodic task registered: $taskName (every ${intervalMinutes}min)")
                true
            } else {
                val output = process.inputStream.bufferedReader().readText()
                System.err.println("Periodic task registration failed: $output")
                false
            }
        } catch (e: Exception) {
            System.err.println("Periodic task registration error: ${e.message}")
            false
        }
    }

    /**
     * Windows 서비스 설치 여부 확인.
     */
    fun isServiceInstalled(): Boolean {
        return try {
            val process = ProcessBuilder("sc.exe", "query", SERVICE_NAME)
                .redirectErrorStream(true)
                .start()
            process.waitFor() == 0
        } catch (_: Exception) {
            false
        }
    }
}
