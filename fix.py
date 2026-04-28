content = '''package com.adskip

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.accessibilityservice.GestureDescription
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Path
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.DisplayMetrics
import android.view.KeyEvent
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.Toast
import androidx.core.app.NotificationCompat

class AdSkipService : AccessibilityService() {

    companion object {
        const val CHANNEL_ID = "adskip_channel"
        const val NOTIFICATION_ID = 1
        const val ACTION_TURN_ON = "com.adskip.TURN_ON"
        const val ACTION_TURN_OFF = "com.adskip.TURN_OFF"

        private val SKIP_KEYWORDS = setOf(
            "skip", "skip ad", "skip ads", "close", "close ad",
            "dismiss", "done", "continue",
            "건너뛰기", "광고 건너뛰기", "닫기", "광고 닫기",
            "확인", "계속하기", "계속",
            "x", "✕", "✗", "×", "⨉"
        )
    }

    private var isActive = false
    private val handler = Handler(Looper.getMainLooper())
    private var scanRunnable: Runnable? = null
    private lateinit var notificationManager: NotificationManager

    private var screenWidth = 1440
    private var screenHeight = 3088
    private var cornerIndex = 0

    private var volumeDownPressCount = 0
    private var lastVolumeDownTime = 0L

    private val toggleReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                ACTION_TURN_ON -> setActive(true)
                ACTION_TURN_OFF -> setActive(false)
            }
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()

        val info = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                    AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS or
                    AccessibilityServiceInfo.FLAG_REQUEST_FILTER_KEY_EVENTS
            notificationTimeout = 100
        }
        serviceInfo = info

        val wm = getSystemService(WINDOW_SERVICE) as WindowManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val bounds = wm.currentWindowMetrics.bounds
            screenWidth = bounds.width()
            screenHeight = bounds.height()
        } else {
            val metrics = DisplayMetrics()
            @Suppress("DEPRECATION")
            wm.defaultDisplay.getRealMetrics(metrics)
            screenWidth = metrics.widthPixels
            screenHeight = metrics.heightPixels
        }

        notificationManager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        createNotificationChannel()

        val filter = IntentFilter().apply {
            addAction(ACTION_TURN_ON)
            addAction(ACTION_TURN_OFF)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(toggleReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(toggleReceiver, filter)
        }

        updateNotification()
        showToast("광고 스킵 서비스 시작")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (!isActive) return
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            handler.post { trySkipAd() }
        }
    }

    override fun onKeyEvent(event: KeyEvent): Boolean {
        if (event.keyCode == KeyEvent.KEYCODE_VOLUME_DOWN &&
            event.action == KeyEvent.ACTION_UP
        ) {
            val now = System.currentTimeMillis()
            if (now - lastVolumeDownTime < 600) {
                volumeDownPressCount++
                if (volumeDownPressCount >= 2) {
                    volumeDownPressCount = 0
                    setActive(!isActive)
                    return true
                }
            } else {
                volumeDownPressCount = 1
            }
            lastVolumeDownTime = now
        }
        return false
    }

    private fun setActive(active: Boolean) {
        isActive = active
        if (isActive) {
            showToast("✅ 광고 스킵 ON")
            startScanning()
        } else {
            showToast("⛔ 광고 스킵 OFF")
            stopScanning()
        }
        updateNotification()
    }

    private fun startScanning() {
        stopScanning()
        scanRunnable = object : Runnable {
            override fun run() {
                if (isActive) {
                    trySkipAd()
                    handler.postDelayed(this, 300)
                }
            }
        }
        handler.post(scanRunnable!!)
    }

    private fun stopScanning() {
        scanRunnable?.let { handler.removeCallbacks(it) }
        scanRunnable = null
    }

    private fun trySkipAd() {
        val root = rootInActiveWindow
        if (root != null) {
            try {
                if (traverseTree(root)) return
            } catch (_: Exception) {}
        }
        tapNextCorner()
    }

    private fun tapNextCorner() {
        val corners = listOf(
            listOf(
                Pair(screenWidth * 0.98f, screenHeight * 0.025f),
                Pair(screenWidth * 0.94f, screenHeight * 0.025f),
                Pair(screenWidth * 0.98f, screenHeight * 0.05f),
                Pair(screenWidth * 0.94f, screenHeight * 0.05f),
                Pair(screenWidth * 0.90f, screenHeight * 0.04f)
            ),
            listOf(
                Pair(screenWidth * 0.02f, screenHeight * 0.025f),
                Pair(screenWidth * 0.06f, screenHeight * 0.025f),
                Pair(screenWidth * 0.02f, screenHeight * 0.05f),
                Pair(screenWidth * 0.06f, screenHeight * 0.05f),
                Pair(screenWidth * 0.10f, screenHeight * 0.04f)
            ),
            listOf(
                Pair(screenWidth * 0.98f, screenHeight * 0.97f),
                Pair(screenWidth * 0.94f, screenHeight * 0.97f),
                Pair(screenWidth * 0.98f, screenHeight * 0.93f),
                Pair(screenWidth * 0.94f, screenHeight * 0.93f),
                Pair(screenWidth * 0.90f, screenHeight * 0.95f)
            ),
            listOf(
                Pair(screenWidth * 0.02f, screenHeight * 0.97f),
                Pair(screenWidth * 0.06f, screenHeight * 0.97f),
                Pair(screenWidth * 0.02f, screenHeight * 0.93f),
                Pair(screenWidth * 0.06f, screenHeight * 0.93f),
                Pair(screenWidth * 0.10f, screenHeight * 0.95f)
            )
        )

        val group = corners[cornerIndex % corners.size]
        cornerIndex++

        group.forEachIndexed { i, (x, y) ->
            handler.postDelayed({
                if (isActive) performTap(x, y)
            }, (i * 40).toLong())
        }
    }

    private fun performTap(x: Float, y: Float) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val path = Path().apply { moveTo(x, y) }
            val stroke = GestureDescription.StrokeDescription(path, 0, 50)
            val gesture = GestureDescription.Builder().addStroke(stroke).build()
            dispatchGesture(gesture, null, null)
        }
    }

    private fun traverseTree(node: AccessibilityNodeInfo): Boolean {
        try {
            if (isSkipButton(node)) {
                if (performClickOnNode(node)) return true
            }
            for (i in 0 until node.childCount) {
                val child = node.getChild(i) ?: continue
                try {
                    if (traverseTree(child)) return true
                } finally {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) child.recycle()
                }
            }
        } catch (_: Exception) {}
        return false
    }

    private fun isSkipButton(node: AccessibilityNodeInfo): Boolean {
        val text = node.text?.toString()?.trim()?.lowercase() ?: ""
        val desc = node.contentDescription?.toString()?.trim()?.lowercase() ?: ""
        for (keyword in SKIP_KEYWORDS) {
            if (text == keyword || desc == keyword ||
                text.contains(keyword) || desc.contains(keyword)
            ) return true
        }
        return false
    }

    private fun performClickOnNode(node: AccessibilityNodeInfo): Boolean {
        if (node.isClickable && node.isEnabled)
            return node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        var parent: AccessibilityNodeInfo? = node.parent
        var depth = 0
        while (parent != null && depth < 4) {
            if (parent.isClickable && parent.isEnabled) {
                val result = parent.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) parent.recycle()
                return result
            }
            val next = parent.parent
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) parent.recycle()
            parent = next
            depth++
        }
        return false
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                getString(R.string.notification_channel_name),
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                setShowBadge(false)
                enableVibration(false)
                setSound(null, null)
            }
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun updateNotification() {
        notificationManager.notify(NOTIFICATION_ID, buildNotification(isActive))
    }

    private fun buildNotification(active: Boolean): Notification {
        val intent = Intent(if (active) ACTION_TURN_OFF else ACTION_TURN_ON)
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        else PendingIntent.FLAG_UPDATE_CURRENT

        val togglePending = PendingIntent.getBroadcast(this, 0, intent, flags)
        val openAppPending = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java), flags
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_media_ff)
            .setContentTitle(getString(R.string.notification_title))
            .setContentText(
                if (active) getString(R.string.notification_text_on)
                else getString(R.string.notification_text_off)
            )
            .setContentIntent(openAppPending)
            .addAction(0,
                if (active) getString(R.string.action_turn_off)
                else getString(R.string.action_turn_on),
                togglePending
            )
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun showToast(message: String) {
        handler.post { Toast.makeText(applicationContext, message, Toast.LENGTH_SHORT).show() }
    }

    override fun onInterrupt() { stopScanning() }

    override fun onDestroy() {
        stopScanning()
        try { unregisterReceiver(toggleReceiver) } catch (_: Exception) {}
        notificationManager.cancel(NOTIFICATION_ID)
        super.onDestroy()
    }
}
'''

import os
os.makedirs('app/src/main/java/com/adskip', exist_ok=True)
with open('app/src/main/java/com/adskip/AdSkipService.kt', 'w') as f:
    f.write(content)
print("AdSkipService.kt 완료")

import subprocess
subprocess.run(['git', 'add', '-A'])
subprocess.run(['git', 'commit', '-m', 'Fix gesture dispatch'])
subprocess.run(['git', 'push'])
print("Push 완료")
