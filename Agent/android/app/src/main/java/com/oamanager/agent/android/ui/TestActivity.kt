package com.oamanager.agent.android.ui

import android.app.Activity
import android.os.Bundle
import android.widget.LinearLayout
import android.widget.TextView

/**
 * 최소 테스트 Activity — 앱 실행 자체가 되는지 확인용.
 */
class TestActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(48, 100, 48, 48)
        }
        val tv = TextView(this).apply {
            text = "OA Agent 테스트 화면\n\n앱이 정상 실행됨!"
            textSize = 20f
        }
        layout.addView(tv)
        setContentView(layout)
    }
}
