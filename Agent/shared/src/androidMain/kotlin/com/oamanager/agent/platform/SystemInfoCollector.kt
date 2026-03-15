package com.oamanager.agent.platform

import android.app.ActivityManager
import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.BatteryManager
import android.os.Build
import android.os.Environment
import android.os.StatFs
import android.os.SystemClock
import com.oamanager.agent.model.SystemInfo
import java.io.BufferedReader
import java.io.FileReader
import java.net.Inet4Address
import java.net.NetworkInterface

/**
 * Android 시스템 정보 수집기 (actual 구현).
 *
 * 18개 항목을 Android API로 수집합니다.
 */
actual class SystemInfoCollector(
    private val context: Context,
    private val assetUserName: String = "",
    private val employeeId: String = "",
    private val agentVersion: String = "",
) {
    actual suspend fun collect(): SystemInfo {
        return SystemInfo(
            cpuUsage = readCpuUsage(),
            memoryTotalMb = getMemoryTotal(),
            memoryUsedMb = getMemoryUsed(),
            storageTotalGb = getStorageTotal(),
            storageUsedGb = getStorageUsed(),
            batteryLevel = getBatteryLevel(),
            batteryCharging = isBatteryCharging(),
            networkType = getNetworkType(),
            ipAddress = getIpAddress(),
            osVersion = getOsVersion(),
            uptimeHours = getUptimeHours(),
            osDetailVersion = getOsDetailVersion(),
            deviceManufacturer = Build.MANUFACTURER,
            deviceModel = Build.MODEL,
            deviceUser = getDeviceUser(),
            assetUserName = assetUserName,
            employeeId = employeeId,
            agentVersion = agentVersion,
        )
    }

    // ─── CPU ────────────────────────────────────────────────────────────

    private fun readCpuUsage(): Float {
        return try {
            val reader1 = BufferedReader(FileReader("/proc/stat"))
            val line1 = reader1.readLine()
            reader1.close()
            val parts1 = line1.split("\\s+".toRegex())
            val idle1 = parts1[4].toLong()
            val total1 = parts1.drop(1).take(7).sumOf { it.toLong() }

            Thread.sleep(300)

            val reader2 = BufferedReader(FileReader("/proc/stat"))
            val line2 = reader2.readLine()
            reader2.close()
            val parts2 = line2.split("\\s+".toRegex())
            val idle2 = parts2[4].toLong()
            val total2 = parts2.drop(1).take(7).sumOf { it.toLong() }

            val idleDelta = idle2 - idle1
            val totalDelta = total2 - total1
            if (totalDelta > 0) {
                ((totalDelta - idleDelta).toFloat() / totalDelta * 100f)
            } else 0f
        } catch (_: Exception) {
            0f
        }
    }

    // ─── Memory ─────────────────────────────────────────────────────────

    private fun getMemoryInfo(): ActivityManager.MemoryInfo {
        val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val memoryInfo = ActivityManager.MemoryInfo()
        activityManager.getMemoryInfo(memoryInfo)
        return memoryInfo
    }

    private fun getMemoryTotal(): Int {
        return (getMemoryInfo().totalMem / (1024 * 1024)).toInt()
    }

    private fun getMemoryUsed(): Int {
        val info = getMemoryInfo()
        return ((info.totalMem - info.availMem) / (1024 * 1024)).toInt()
    }

    // ─── Storage ────────────────────────────────────────────────────────

    private fun getStorageTotal(): Float {
        val stat = StatFs(Environment.getDataDirectory().path)
        return stat.totalBytes.toFloat() / (1024 * 1024 * 1024)
    }

    private fun getStorageUsed(): Float {
        val stat = StatFs(Environment.getDataDirectory().path)
        return (stat.totalBytes - stat.availableBytes).toFloat() / (1024 * 1024 * 1024)
    }

    // ─── Battery ────────────────────────────────────────────────────────

    private fun getBatteryLevel(): Int {
        val batteryManager = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        return batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
    }

    private fun isBatteryCharging(): Boolean {
        val batteryManager = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        return batteryManager.isCharging
    }

    // ─── Network ────────────────────────────────────────────────────────

    private fun getNetworkType(): String {
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val network = cm.activeNetwork ?: return "UNKNOWN"
        val caps = cm.getNetworkCapabilities(network) ?: return "UNKNOWN"
        return when {
            caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "WIFI"
            caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "CELLULAR"
            caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "ETHERNET"
            else -> "UNKNOWN"
        }
    }

    private fun getIpAddress(): String {
        return try {
            NetworkInterface.getNetworkInterfaces().toList()
                .flatMap { it.inetAddresses.toList() }
                .firstOrNull { !it.isLoopbackAddress && it is Inet4Address }
                ?.hostAddress ?: "0.0.0.0"
        } catch (_: Exception) {
            "0.0.0.0"
        }
    }

    // ─── OS ─────────────────────────────────────────────────────────────

    private fun getOsVersion(): String {
        return "Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})"
    }

    private fun getOsDetailVersion(): String {
        return "${Build.DISPLAY} / ${Build.VERSION.SECURITY_PATCH}"
    }

    // ─── Uptime ─────────────────────────────────────────────────────────

    private fun getUptimeHours(): Float {
        return SystemClock.elapsedRealtime() / 3_600_000f
    }

    // ─── Device User ────────────────────────────────────────────────────

    private fun getDeviceUser(): String {
        return try {
            val accountManager =
                context.getSystemService(Context.ACCOUNT_SERVICE) as android.accounts.AccountManager
            val accounts = accountManager.getAccountsByType("com.google")
            accounts.firstOrNull()?.name ?: Build.USER
        } catch (_: Exception) {
            Build.USER
        }
    }
}
