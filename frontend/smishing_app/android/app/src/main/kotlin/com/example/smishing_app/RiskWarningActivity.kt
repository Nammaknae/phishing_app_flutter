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
import android.widget.ImageView
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
            ViewGroup.LayoutParams.WRAP_CONTENT
        )
    }

    private fun createContentView(score: Int, grade: String, content: String): LinearLayout {
        val statusText: String
        val titleText: String
        val guideText: String
        val iconRes: Int
        val statusColor: Int
        val statusLightColor: Int

        when {
            score >= 80 -> {
                statusText = "위험"
                titleText = "스미싱 위험 알림"
                guideText = "스미싱 위험이 높은 알림입니다.\n링크를 열지 마세요."
                iconRes = android.R.drawable.ic_dialog_alert
                statusColor = Color.rgb(211, 47, 47)
                statusLightColor = Color.rgb(255, 235, 238)
            }

            score >= 50 -> {
                statusText = "주의"
                titleText = "주의가 필요한 알림"
                guideText = "의심스러운 알림이 감지되었습니다.\n발신자와 링크를 한 번 더 확인해 주세요."
                iconRes = android.R.drawable.ic_dialog_alert
                statusColor = Color.rgb(245, 124, 0)
                statusLightColor = Color.rgb(255, 243, 224)
            }

            else -> {
                statusText = "안전"
                titleText = "안전한 알림"
                guideText = "현재 알림은 안전한 것으로 판단됩니다."
                iconRes = android.R.drawable.checkbox_on_background
                statusColor = Color.rgb(46, 125, 50)
                statusLightColor = Color.rgb(232, 245, 233)
            }
        }

        val displayContent = content.ifBlank {
            grade.ifBlank { "감지된 알림 내용이 없습니다." }
        }

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(24), dp(26), dp(24), dp(22))
            background = roundedStrokeBg(
                Color.rgb(247, 251, 255),
                Color.rgb(218, 232, 247),
                30
            )
        }

        val iconCircle = LinearLayout(this).apply {
            gravity = Gravity.CENTER
            background = roundedBg(statusLightColor, 32)
        }

        iconCircle.addView(
            ImageView(this).apply {
                setImageResource(iconRes)
                setColorFilter(statusColor)
            },
            LinearLayout.LayoutParams(dp(38), dp(38))
        )

        root.addView(
            iconCircle,
            LinearLayout.LayoutParams(dp(72), dp(72)).apply {
                gravity = Gravity.CENTER_HORIZONTAL
            }
        )

        root.addView(
            TextView(this).apply {
                text = titleText
                textSize = 24f
                gravity = Gravity.CENTER
                typeface = Typeface.DEFAULT_BOLD
                setTextColor(Color.rgb(24, 64, 112))
                setPadding(0, dp(16), 0, 0)
            },
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        )

        root.addView(
            TextView(this).apply {
                text = "$statusText · ${score}점"
                textSize = 15f
                gravity = Gravity.CENTER
                typeface = Typeface.DEFAULT_BOLD
                setTextColor(statusColor)
                setPadding(dp(18), dp(8), dp(18), dp(8))
                background = roundedBg(statusLightColor, 22)
            },
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                gravity = Gravity.CENTER_HORIZONTAL
                topMargin = dp(12)
            }
        )

        root.addView(
            TextView(this).apply {
                text = guideText
                textSize = 15.5f
                gravity = Gravity.CENTER
                setTextColor(Color.rgb(68, 82, 100))
                setLineSpacing(dp(4).toFloat(), 1.0f)
                setPadding(0, dp(18), 0, 0)
            },
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
        )

        val messageBox = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(18), dp(16), dp(18), dp(16))
            background = roundedStrokeBg(
                Color.WHITE,
                Color.rgb(207, 226, 245),
                22
            )
        }

        messageBox.addView(
            TextView(this).apply {
                text = "감지된 알림 내용"
                textSize = 13f
                typeface = Typeface.DEFAULT_BOLD
                setTextColor(Color.rgb(25, 118, 210))
            }
        )

        messageBox.addView(
            TextView(this).apply {
                text = displayContent
                textSize = 14.5f
                setTextColor(Color.rgb(72, 84, 100))
                maxLines = 5
                ellipsize = TextUtils.TruncateAt.END
                setLineSpacing(dp(3).toFloat(), 1.0f)
                setPadding(0, dp(8), 0, 0)
            }
        )

        root.addView(
            messageBox,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = dp(20)
            }
        )

        val buttonRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(0, dp(24), 0, 0)
        }

        buttonRow.addView(
            TextView(this).apply {
                text = "닫기"
                textSize = 16f
                gravity = Gravity.CENTER
                typeface = Typeface.DEFAULT_BOLD
                isClickable = true
                isFocusable = true
                setTextColor(Color.rgb(36, 78, 118))
                background = roundedBg(Color.rgb(232, 243, 253), 16)
                setOnClickListener { finish() }
            },
            LinearLayout.LayoutParams(0, dp(52), 1f).apply {
                rightMargin = dp(8)
            }
        )

        buttonRow.addView(
            TextView(this).apply {
                text = "신고/확인"
                textSize = 16f
                gravity = Gravity.CENTER
                typeface = Typeface.DEFAULT_BOLD
                isClickable = true
                isFocusable = true
                setTextColor(Color.WHITE)
                background = roundedBg(Color.rgb(25, 118, 210), 16)
                setOnClickListener { finish() }
            },
            LinearLayout.LayoutParams(0, dp(52), 1f).apply {
                leftMargin = dp(8)
            }
        )

        root.addView(buttonRow)

        return root
    }

    private fun roundedBg(color: Int, radius: Int): GradientDrawable {
        return GradientDrawable().apply {
            setColor(color)
            cornerRadius = dp(radius).toFloat()
        }
    }

    private fun roundedStrokeBg(bgColor: Int, strokeColor: Int, radius: Int): GradientDrawable {
        return GradientDrawable().apply {
            setColor(bgColor)
            setStroke(dp(1), strokeColor)
            cornerRadius = dp(radius).toFloat()
        }
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