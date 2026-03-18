package com.oamanager.agent.platform

import com.oamanager.agent.model.SystemInfo
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader
import java.lang.management.ManagementFactory
import java.net.Inet4Address
import java.net.NetworkInterface

/**
 * Windows 시스템 정보 수집기 (JVM actual 구현).
 *
 * WMI(PowerShell) 및 Java Management API로 18개 항목을 수집합니다.
 * Windows 10 / Windows 11 호환.
 */
actual class SystemInfoCollector(
    private val assetUserName: String = "",
    private val employeeId: String = "",
    private val agentVersion: String = "",
) {
    actual suspend fun collect(): SystemInfo {
        return SystemInfo(
            cpuUsage = getCpuUsage(),
            memoryTotalMb = getMemoryTotalMb(),
            memoryUsedMb = getMemoryUsedMb(),
            storageTotalGb = getStorageTotalGb(),
            storageUsedGb = getStorageUsedGb(),
            batteryLevel = getBatteryLevel(),
            batteryCharging = isBatteryCharging(),
            networkType = getNetworkType(),
            ipAddress = getIpAddress(),
            osVersion = getOsVersion(),
            uptimeHours = getUptimeHours(),
            osDetailVersion = getOsDetailVersion(),
            deviceManufacturer = getDeviceManufacturer(),
            deviceModel = getDeviceModel(),
            deviceUser = getDeviceUser(),
            assetUserName = assetUserName,
            employeeId = employeeId,
            agentVersion = agentVersion,
        )
    }

    // ─── CPU ────────────────────────────────────────────────────────────

    private fun getCpuUsage(): Float {
        return try {
            val osBean = ManagementFactory.getOperatingSystemMXBean()
            if (osBean is com.sun.management.OperatingSystemMXBean) {
                (osBean.cpuLoad * 100).toFloat()
            } else {
                // fallback: PowerShell
                runPowerShell(
                    "(Get-CimInstance Win32_Processor).LoadPercentage"
                ).trim().toFloatOrNull() ?: 0f
            }
        } catch (_: Exception) {
            0f
        }
    }

    // ─── Memory ─────────────────────────────────────────────────────────

    private fun getMemoryTotalMb(): Int {
        return try {
            val osBean = ManagementFactory.getOperatingSystemMXBean()
            if (osBean is com.sun.management.OperatingSystemMXBean) {
                (osBean.totalMemorySize / (1024 * 1024)).toInt()
            } else {
                runPowerShell(
                    "(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1MB"
                ).trim().toIntOrNull() ?: 0
            }
        } catch (_: Exception) {
            0
        }
    }

    private fun getMemoryUsedMb(): Int {
        return try {
            val osBean = ManagementFactory.getOperatingSystemMXBean()
            if (osBean is com.sun.management.OperatingSystemMXBean) {
                val total = osBean.totalMemorySize
                val free = osBean.freeMemorySize
                ((total - free) / (1024 * 1024)).toInt()
            } else {
                val total = getMemoryTotalMb()
                val free = runPowerShell(
                    "(Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1KB"
                ).trim().toIntOrNull() ?: 0
                total - free
            }
        } catch (_: Exception) {
            0
        }
    }

    // ─── Storage ────────────────────────────────────────────────────────

    private fun getStorageTotalGb(): Float {
        return try {
            val root = File("C:\\")
            root.totalSpace.toFloat() / (1024 * 1024 * 1024)
        } catch (_: Exception) {
            0f
        }
    }

    private fun getStorageUsedGb(): Float {
        return try {
            val root = File("C:\\")
            (root.totalSpace - root.freeSpace).toFloat() / (1024 * 1024 * 1024)
        } catch (_: Exception) {
            0f
        }
    }

    // ─── Battery ────────────────────────────────────────────────────────

    private fun getBatteryLevel(): Int {
        return try {
            val result = runPowerShell(
                "(Get-CimInstance Win32_Battery).EstimatedChargeRemaining"
            ).trim()
            result.toIntOrNull() ?: -1 // 데스크탑(배터리 없음) → -1
        } catch (_: Exception) {
            -1
        }
    }

    private fun isBatteryCharging(): Boolean {
        return try {
            // BatteryStatus: 1=Discharging, 2=AC, 3~5=Charging variants
            val result = runPowerShell(
                "(Get-CimInstance Win32_Battery).BatteryStatus"
            ).trim()
            val status = result.toIntOrNull() ?: 2
            status != 1 // 1이 아니면 충전 중 또는 AC 전원
        } catch (_: Exception) {
            true // 데스크탑은 항상 AC
        }
    }

    // ─── Network ────────────────────────────────────────────────────────

    private fun getNetworkType(): String {
        return try {
            val result = runPowerShell(
                "(Get-NetAdapter | Where-Object { \$_.Status -eq 'Up' } | Select-Object -First 1).InterfaceDescription"
            ).trim().lowercase()
            when {
                result.contains("wi-fi") || result.contains("wireless") || result.contains("wlan") -> "WIFI"
                result.contains("ethernet") || result.contains("realtek") || result.contains("intel") -> "ETHERNET"
                else -> "UNKNOWN"
            }
        } catch (_: Exception) {
            "UNKNOWN"
        }
    }

    private fun getIpAddress(): String {
        return try {
            NetworkInterface.getNetworkInterfaces().toList()
                .filter { it.isUp && !it.isLoopback }
                .flatMap { it.inetAddresses.toList() }
                .firstOrNull { !it.isLoopbackAddress && it is Inet4Address }
                ?.hostAddress ?: "0.0.0.0"
        } catch (_: Exception) {
            "0.0.0.0"
        }
    }

    // ─── OS ─────────────────────────────────────────────────────────────

    private fun getOsVersion(): String {
        val name = System.getProperty("os.name") ?: "Windows"
        val version = System.getProperty("os.version") ?: ""
        return "$name $version"
    }

    private fun getOsDetailVersion(): String {
        return try {
            val build = runPowerShell(
                "(Get-CimInstance Win32_OperatingSystem).BuildNumber"
            ).trim()
            val caption = runPowerShell(
                "(Get-CimInstance Win32_OperatingSystem).Caption"
            ).trim()
            "$caption (Build $build)"
        } catch (_: Exception) {
            System.getProperty("os.name") ?: "Windows"
        }
    }

    // ─── Uptime ─────────────────────────────────────────────────────────

    private fun getUptimeHours(): Float {
        return try {
            val uptimeMs = ManagementFactory.getRuntimeMXBean().uptime
            // 시스템 업타임 (JVM이 아닌 OS)
            val result = runPowerShell(
                "((Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime).TotalHours"
            ).trim()
            result.toFloatOrNull() ?: (uptimeMs / 3_600_000f)
        } catch (_: Exception) {
            0f
        }
    }

    // ─── Device Info ────────────────────────────────────────────────────

    private fun getDeviceManufacturer(): String {
        return try {
            runPowerShell(
                "(Get-CimInstance Win32_ComputerSystem).Manufacturer"
            ).trim().ifEmpty { "Unknown" }
        } catch (_: Exception) {
            "Unknown"
        }
    }

    private fun getDeviceModel(): String {
        return try {
            runPowerShell(
                "(Get-CimInstance Win32_ComputerSystem).Model"
            ).trim().ifEmpty { "Unknown" }
        } catch (_: Exception) {
            "Unknown"
        }
    }

    private fun getDeviceUser(): String {
        return System.getProperty("user.name") ?: "Unknown"
    }

    // ─── PowerShell Helper ──────────────────────────────────────────────

    private fun runPowerShell(command: String): String {
        return try {
            val process = ProcessBuilder(
                "powershell.exe", "-NoProfile", "-NonInteractive", "-Command", command
            )
                .redirectErrorStream(true)
                .start()

            val output = BufferedReader(InputStreamReader(process.inputStream))
                .readText()
                .trim()

            process.waitFor()
            output
        } catch (_: Exception) {
            ""
        }
    }
}
