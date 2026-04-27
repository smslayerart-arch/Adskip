#!/bin/bash

echo "=== AdSkip 프로젝트 파일 생성 중 ==="

# 폴더 생성
mkdir -p app/src/main/java/com/adskip
mkdir -p app/src/main/res/xml
mkdir -p app/src/main/res/layout
mkdir -p app/src/main/res/values
mkdir -p app/src/main/res/drawable
mkdir -p app/src/main/res/mipmap-hdpi
mkdir -p app/src/main/res/mipmap-mdpi
mkdir -p app/src/main/res/mipmap-xhdpi
mkdir -p app/src/main/res/mipmap-xxhdpi
mkdir -p app/src/main/res/mipmap-xxxhdpi
mkdir -p .github/workflows
mkdir -p gradle/wrapper

echo "폴더 생성 완료"

# ── AndroidManifest.xml ──
cat > app/src/main/AndroidManifest.xml << 'MANIFEST'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.adskip">

    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />

    <application
        android:allowBackup="true"
        android:icon="@mipmap/ic_launcher"
        android:label="@string/app_name"
        android:roundIcon="@mipmap/ic_launcher_round"
        android:supportsRtl="true"
        android:theme="@style/Theme.AppCompat.Light.DarkActionBar">

        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

        <service
            android:name=".AdSkipService"
            android:exported="true"
            android:label="@string/app_name"
            android:permission="android.permission.BIND_ACCESSIBILITY_SERVICE">
            <intent-filter>
                <action android:name="android.accessibilityservice.AccessibilityService" />
            </intent-filter>
            <meta-data
                android:name="android.accessibilityservice"
                android:resource="@xml/accessibility_service_config" />
        </service>

    </application>

</manifest>
MANIFEST

# ── accessibility_service_config.xml ──
cat > app/src/main/res/xml/accessibility_service_config.xml << 'AXMLEOF'
<?xml version="1.0" encoding="utf-8"?>
<accessibility-service xmlns:android="http://schemas.android.com/apk/res/android"
    android:accessibilityEventTypes="typeWindowStateChanged|typeWindowContentChanged"
    android:accessibilityFeedbackType="feedbackGeneric"
    android:accessibilityFlags="flagRetrieveInteractiveWindows|flagRequestFilterKeyEvents|flagDefault"
    android:canRetrieveWindowContent="true"
    android:description="@string/accessibility_description"
    android:notificationTimeout="100"
    android:settingsActivity=".MainActivity" />
AXMLEOF

# ── strings.xml ──
cat > app/src/main/res/values/strings.xml << 'STREOF'
<resources>
    <string name="app_name">광고 스킵</string>
    <string name="accessibility_description">게임 광고를 자동으로 건너뜁니다</string>
    <string name="notification_channel_name">광고 스킵 서비스</string>
    <string name="notification_title">광고 스킵</string>
    <string name="notification_text_on">✅ ON — 광고 자동 스킵 중</string>
    <string name="notification_text_off">⛔ OFF — 비활성화됨</string>
    <string name="action_turn_on">켜기</string>
    <string name="action_turn_off">끄기</string>
</resources>
STREOF

# ── activity_main.xml ──
cat > app/src/main/res/layout/activity_main.xml << 'LAYOUTEOF'
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical"
    android:padding="24dp"
    android:gravity="center_horizontal">

    <TextView
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="🎮 광고 스킵"
        android:textSize="28sp"
        android:textStyle="bold"
        android:layout_marginTop="40dp" />

    <TextView
        android:id="@+id/tvStatus"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="접근성 권한 확인 중..."
        android:textSize="16sp"
        android:layout_marginTop="24dp"
        android:gravity="center" />

    <Button
        android:id="@+id/btnOpenAccessibility"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="접근성 설정 열기"
        android:layout_marginTop="24dp" />

    <View
        android:layout_width="match_parent"
        android:layout_height="1dp"
        android:background="#DDDDDD"
        android:layout_marginTop="32dp"
        android:layout_marginBottom="32dp" />

    <TextView
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="사용 방법"
        android:textSize="18sp"
        android:textStyle="bold" />

    <TextView
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="1. 접근성 서비스를 켜주세요\n2. 알림창의 ON/OFF 버튼으로 제어\n3. 게임 실행 후 광고 시작되면 자동 스킵\n\n모든 게임에서 작동합니다."
        android:textSize="15sp"
        android:layout_marginTop="12dp"
        android:lineSpacingMultiplier="1.5" />

</LinearLayout>
LAYOUTEOF

# ── AdSkipService.kt ──
cat > app/src/main/java/com/adskip/AdSkipService.kt << 'SERVICEEOF'
package com.adskip

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.KeyEvent
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
            "dismiss", "done", "continue", "watch later",
            "건너뛰기", "광고 건너뛰기", "광고건너뛰기",
            "닫기", "광고 닫기", "광고닫기",
            "확인", "계속하기", "계속",
            "x", "✕", "✗", "×", "⨉"
        )
    }

    private var isActive = false
    private val handler = Handler(Looper.getMainLooper())
    private var scanRunnable: Runnable? = null
    private lateinit var notificationManager: NotificationManager

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
        showToast("광고 스킵 서비스 시작\n알림창에서 ON/OFF 가능")
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
        val root = rootInActiveWindow ?: return
        try {
            traverseTree(root)
        } catch (_: Exception) {}
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
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
                        child.recycle()
                    }
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
        if (node.isClickable && node.isEnabled) {
            return node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        }
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
SERVICEEOF

# ── MainActivity.kt ──
cat > app/src/main/java/com/adskip/MainActivity.kt << 'MAINEOF'
package com.adskip

import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import android.widget.Button
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity

class MainActivity : AppCompatActivity() {

    private lateinit var tvStatus: TextView
    private lateinit var btnOpenAccessibility: Button

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        tvStatus = findViewById(R.id.tvStatus)
        btnOpenAccessibility = findViewById(R.id.btnOpenAccessibility)
        btnOpenAccessibility.setOnClickListener {
            startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
        }
    }

    override fun onResume() {
        super.onResume()
        updateStatus()
    }

    private fun updateStatus() {
        if (isAccessibilityEnabled()) {
            tvStatus.text = "✅ 접근성 권한 허용됨\n\n알림창에서 ON/OFF 버튼으로 제어하세요.\n볼륨 하단 버튼 3번 빠르게 눌러도 토글됩니다."
            btnOpenAccessibility.text = "접근성 설정 다시 열기"
        } else {
            tvStatus.text = "❌ 접근성 권한이 필요합니다.\n\n아래 버튼을 눌러 설정에서\n'광고 스킵'을 찾아 활성화해주세요."
            btnOpenAccessibility.text = "접근성 설정 열기"
        }
    }

    private fun isAccessibilityEnabled(): Boolean {
        val enabled = Settings.Secure.getInt(
            contentResolver, Settings.Secure.ACCESSIBILITY_ENABLED, 0
        )
        if (enabled == 0) return false
        val services = Settings.Secure.getString(
            contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        return services.contains("${packageName}/com.adskip.AdSkipService")
    }
}
MAINEOF

# ── GitHub Actions workflow ──
cat > .github/workflows/build.yml << 'WFEOF'
name: Build APK

on:
  push:
    branches: [ main ]
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'

      - name: Grant execute permission for gradlew
        run: chmod +x gradlew

      - name: Build Debug APK
        run: ./gradlew assembleDebug

      - name: Upload APK
        uses: actions/upload-artifact@v4
        with:
          name: AdSkip-APK
          path: app/build/outputs/apk/debug/app-debug.apk
WFEOF

# ── gradle-wrapper.properties ──
cat > gradle/wrapper/gradle-wrapper.properties << 'GRADLEEOF'
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-8.2-bin.zip
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
GRADLEEOF

echo "모든 파일 생성 완료"

# Git에 추가 및 커밋
git add -A
git commit -m "Add all project files"
git push

echo ""
echo "=== 완료! Actions 탭에서 빌드 진행 확인하세요 ==="
