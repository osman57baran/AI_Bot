package com.osman.reelsgaleri

import android.os.Bundle
import android.view.WindowManager
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.fragment.app.Fragment
import androidx.lifecycle.lifecycleScope
import androidx.viewpager2.adapter.FragmentStateAdapter
import androidx.viewpager2.widget.ViewPager2
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** Seçilen videoları Reels gibi dikey kaydırarak oynatır. */
class ReelsActivity : AppCompatActivity() {

    companion object {
        const val EXTRA_LIKED = "liked"
        const val EXTRA_SHUFFLE = "shuffle"
        private const val STATE_ORDER = "order"
    }

    private var items: List<Video> = emptyList()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_reels)
        Store.init(this)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        WindowInsetsControllerCompat(window, window.decorView).apply {
            hide(WindowInsetsCompat.Type.systemBars())
            systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        }

        val pager = findViewById<ViewPager2>(R.id.pager)
        val position = findViewById<TextView>(R.id.position)
        pager.offscreenPageLimit = 1

        val likedOnly = intent.getBooleanExtra(EXTRA_LIKED, false)
        val shuffle = intent.getBooleanExtra(EXTRA_SHUFFLE, false)
        val savedOrder = savedInstanceState?.getLongArray(STATE_ORDER)

        lifecycleScope.launch {
            val all = withContext(Dispatchers.IO) { Videos.queryAll(this@ReelsActivity) }
            val byId = all.associateBy { it.id }
            val ids: List<Long> = when {
                savedOrder != null -> savedOrder.toList()
                likedOnly -> Store.likes.toList().reversed() // en son beğenilen önce
                else -> Store.selected.toList()
            }
            var list = ids.mapNotNull { byId[it] }
            if (shuffle && savedOrder == null) list = list.shuffled()
            items = list

            if (items.isEmpty()) {
                Toast.makeText(this@ReelsActivity, "Oynatılacak video bulunamadı", Toast.LENGTH_LONG).show()
                finish()
                return@launch
            }

            pager.adapter = object : FragmentStateAdapter(this@ReelsActivity) {
                override fun getItemCount() = items.size
                override fun createFragment(position: Int): Fragment = ReelFragment.newInstance(items[position])
            }
            pager.registerOnPageChangeCallback(object : ViewPager2.OnPageChangeCallback() {
                override fun onPageSelected(p: Int) {
                    position.text = "${p + 1} / ${items.size}"
                }
            })
            position.text = "1 / ${items.size}"
        }
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        if (items.isNotEmpty()) outState.putLongArray(STATE_ORDER, items.map { it.id }.toLongArray())
    }
}
