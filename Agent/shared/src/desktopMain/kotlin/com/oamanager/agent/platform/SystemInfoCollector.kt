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
            macAddress = getMacAddress(),
            serialNumber = getSerialNumber(),
            phoneNumber = "",
            osBuildNumber = getOsBuildNumber(),
            osUbr = if (isMac) "" else getWindowsUbr(),
            osKbList = if (isMac) "" else getWindowsKbList(),
        )
    }

    // ─── 취약점 관리 (Build/UBR/KB) ─────────────────────────────────────────

    /** Windows: OS Build (예: "19045").  macOS: 시스템 빌드 (예: "24A348") */
    private fun getOsBuildNumber(): String {
        return try {
            if (isMac) {
                runShell("sh", "-c", "sw_vers -buildVersion").trim()
            } else {
                runPowerShell("(Get-CimInstance Win32_OperatingSystem).BuildNumber").trim()
            }
        } catch (_: Exception) {
            ""
        }
    }

    /** Windows UBR (HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\UBR) */
    private fun getWindowsUbr(): String {
        return try {
            runPowerShell(
                "(Get-ItemProperty 'HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion').UBR"
            ).trim()
        } catch (_: Exception) {
            ""
        }
    }

    /** Windows 적용 KB 목록 — Get-HotFix 결과를 콤마로 join. 실패 시 빈 문자열. */
    private fun getWindowsKbList(): String {
        return try {
            runPowerShell(
                "(Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -ExpandProperty HotFixID) -join ','"
            ).trim()
        } catch (_: Exception) {
            ""
        }
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
            if (isMac) {
                val result = runShell("sh", "-c", "pmset -g batt | grep -o '[0-9]*%' | tr -d '%'")
                result.trim().toIntOrNull() ?: -1
            } else {
                runPowerShell("(Get-CimInstance Win32_Battery).EstimatedChargeRemaining")
                    .trim().toIntOrNull() ?: -1
            }
        } catch (_: Exception) { -1 }
    }

    private fun isBatteryCharging(): Boolean {
        return try {
            if (isMac) {
                val result = runShell("sh", "-c", "pmset -g batt | head -1")
                result.contains("AC Power", ignoreCase = true)
            } else {
                val status = runPowerShell("(Get-CimInstance Win32_Battery).BatteryStatus")
                    .trim().toIntOrNull() ?: 2
                status != 1
            }
        } catch (_: Exception) { true }
    }

    // ─── Network ────────────────────────────────────────────────────────

    private fun getNetworkType(): String {
        return try {
            if (isMac) {
                val result = runShell("sh", "-c", "networksetup -listallhardwareports | grep -A1 'Wi-Fi' | grep Device | awk '{print \$2}'")
                val wifiDev = result.trim()
                if (wifiDev.isNotEmpty()) {
                    val status = runShell("sh", "-c", "ifconfig $wifiDev | grep 'status: active'")
                    if (status.contains("active")) return "WIFI"
                }
                return "ETHERNET"
            }
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
            if (isMac) {
                val ver = runShell("sh", "-c", "sw_vers -productVersion").trim()
                val build = runShell("sh", "-c", "sw_vers -buildVersion").trim()
                "macOS $ver (Build $build)"
            } else {
                val build = runPowerShell("(Get-CimInstance Win32_OperatingSystem).BuildNumber").trim()
                val caption = runPowerShell("(Get-CimInstance Win32_OperatingSystem).Caption").trim()
                "$caption (Build $build)"
            }
        } catch (_: Exception) {
            System.getProperty("os.name") ?: "Unknown"
        }
    }

    // ─── Uptime ─────────────────────────────────────────────────────────

    private fun getUptimeHours(): Float {
        return try {
            if (isMac) {
                val result = runShell("sh", "-c", "sysctl -n kern.boottime | awk '{print \$4}' | tr -d ','")
                val bootTime = result.trim().toLongOrNull() ?: return 0f
                ((System.currentTimeMillis() / 1000 - bootTime) / 3600f)
            } else {
                val result = runPowerShell(
                    "((Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime).TotalHours"
                ).trim()
                result.toFloatOrNull() ?: 0f
            }
        } catch (_: Exception) { 0f }
    }

    // ─── Device Info ────────────────────────────────────────────────────

    private fun getDeviceManufacturer(): String {
        return try {
            if (isMac) "Apple"
            else runPowerShell("(Get-CimInstance Win32_ComputerSystem).Manufacturer").trim().ifEmpty { "Unknown" }
        } catch (_: Exception) { "Unknown" }
    }

    private fun getDeviceModel(): String {
        return try {
            if (isMac) {
                runShell("sh", "-c", "sysctl -n hw.model").trim().ifEmpty { "Mac" }
            } else {
                runPowerShell("(Get-CimInstance Win32_ComputerSystem).Model").trim().ifEmpty { "Unknown" }
            }
        } catch (_: Exception) { "Unknown" }
    }

    private fun getDeviceUser(): String {
        return System.getProperty("user.name") ?: "Unknown"
    }

    // ─── MAC Address ────────────────────────────────────────────────────

    private fun getMacAddress(): String {
        return try {
            NetworkInterface.getNetworkInterfaces().toList()
                .filter { it.isUp && !it.isLoopback && it.hardwareAddress != null }
                .firstOrNull()
                ?.hardwareAddress
                ?.joinToString(":") { "%02x".format(it) } ?: ""
        } catch (_: Exception) {
            ""
        }
    }

    // ─── Serial Number ──────────────────────────────────────────────────

    private fun getSerialNumber(): String {
        return try {
            if (isMac) {
                runShell("sh", "-c", "ioreg -l | grep IOPlatformSerialNumber | awk '{print \$4}' | tr -d '\"'")
            } else {
                runShell("powershell.exe", "-NoProfile", "-NonInteractive", "-Command",
                    "(Get-CimInstance Win32_BIOS).SerialNumber")
            }.trim()
        } catch (_: Exception) {
            ""
        }
    }

    // ─── Phone Number (desktop: 해당 없음) ──────────────────────────────

    private fun getPhoneNumber(): String = ""

    // ─── OS Detection ──────────────────────────────────────────────────

    private val isMac: Boolean = System.getProperty("os.name")?.lowercase()?.contains("mac") == true

    // ─── Shell Helper ──────────────────────────────────────────────────

    private fun runPowerShell(command: String): String {
        return runShell("powershell.exe", "-NoProfile", "-NonInteractive", "-Command", command)
    }

    private fun runShell(vararg command: String): String {
        return try {
            val process = ProcessBuilder(*command)
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
