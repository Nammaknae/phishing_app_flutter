package com.example.smishing_app

import android.app.Activity
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.ColorDrawable
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.text.TextUtils
import android.view.Gravity
import android.view.ViewGroup
import android.view.Window
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

class RiskWarningActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestWindowFeature(Window.FEATURE_NO_TITLE)
        window.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
        setFinishOnTouchOutside(true)

        val score = intent.getIntExtra(EXTRA_SCORE, 0)
        val grade = intent.getStringExtra(EXTRA_GRADE).orEmpty()
        val content = intent.getStringExtra(EXTRA_CONTENT).orEmpty()

        setContentView(createContentView(score, grade, content))

        window.setLayout(
            (resources.displayMetrics.widthPixels * 0.88f).toInt(),
            ViewGroup.LayoutParams.WRAP_CONTENT,
        )
    }

    private fun createContentView(score: Int, grade: String, content: String): LinearLayout {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(22), dp(20), dp(22), dp(18))
            background = GradientDrawable().apply {
                setColor(Color.WHITE)
                cornerRadius = dp(20).toFloat()
            }
        }

        root.addView(
            TextView(this).apply {
                text = "스미싱 의심 알림"
                setTextColor(Color.rgb(198, 40, 40))
                textSize = 22f
                typeface = Typeface.DEFAULT_BOLD
            },
        )

        root.addView(
            TextView(this).apply {
                text = "위험도 ${score}점"
                setTextColor(Color.rgb(33, 33, 33))
                textSize = 18f
                typeface = Typeface.DEFAULT_BOLD
                setPadding(0, dp(12), 0, 0)
            },
        )

        root.addView(
            TextView(this).apply {
                text = "이 알림은 스미싱 위험이 있습니다. 링크를 열지 마세요."
                setTextColor(Color.rgb(66, 66, 66))
                textSize = 15f
                setPadding(0, dp(10), 0, 0)
            },
        )

        root.addView(
            TextView(this).apply {
                text = content.ifBlank { grade }
                setTextColor(Color.rgb(97, 97, 97))
                textSize = 14f
                maxLines = 3
                ellipsize = TextUtils.TruncateAt.END
                setPadding(0, dp(12), 0, 0)
            },
        )

        root.addView(
            LinearLayout(this).apply {
                gravity = Gravity.END
                orientation = LinearLayout.HORIZONTAL
                setPadding(0, dp(18), 0, 0)

                addView(
                    Button(context).apply {
                        text = "닫기"
                        setOnClickListener { finish() }
                    },
                )

                addView(
                    Button(context).apply {
                        text = "신고/확인"
                        setOnClickListener { finish() }
                    },
                )
            },
        )

        return root
    }

    private fun dp(value: Int): Int {
        return (value * resources.displayMetrics.density).toInt()
    }

    companion object {
        const val EXTRA_SCORE = "score"
        const val EXTRA_GRADE = "grade"
        const val EXTRA_CONTENT = "content"
    }
}
