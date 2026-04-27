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
