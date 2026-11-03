package com.osman.reelsgaleri

import android.content.Context
import android.util.AttributeSet
import android.widget.FrameLayout

/** Genişliği kadar yüksekliği olan kare kutu (galeri ızgarası için). */
class SquareFrame @JvmOverloads constructor(
    context: Context, attrs: AttributeSet? = null
) : FrameLayout(context, attrs) {
    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        super.onMeasure(widthMeasureSpec, widthMeasureSpec)
    }
}
