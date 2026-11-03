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
        const val EXTRA_START_ID = "startId"
        private const val STATE_ORDER = "order"
    }

    private var items: List<Video> = emptyList()
    private var loaded = false
    private lateinit var pager: ViewPager2
    private lateinit var positionText: TextView

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

        pager = findViewById(R.id.pager)
        positionText = findViewById(R.id.position)
        pager.offscreenPageLimit = 1

        val likedOnly = intent.getBooleanExtra(EXTRA_LIKED, false)
        val shuffle = intent.getBooleanExtra(EXTRA_SHUFFLE, false)
        val savedOrder = savedInstanceState?.getLongArray(STATE_ORDER)
        val startId = intent.getLongExtra(EXTRA_START_ID, -1L)

        lifecycleScope.launch {
            val all = withContext(Dispatchers.IO) { Videos.queryAll(this@ReelsActivity) }
            val byId = all.associateBy { it.id }
            val ids: List<Long> = when {
                savedOrder != null -> savedOrder.toList()
                likedOnly -> Videos.likedOrder(all).map { it.id } // en son beğenilen önce
                else -> Store.selected.toList()
            }
            var list = ids.mapNotNull { byId[it] }
            if (shuffle && savedOrder == null && startId == -1L) list = list.shuffled()
            items = list

            if (items.isEmpty()) {
                Toast.makeText(this@ReelsActivity, "Oynatılacak video bulunamadı", Toast.LENGTH_LONG).show()
                finish()
                return@launch
            }

            pager.adapter = object : FragmentStateAdapter(this@ReelsActivity) {
                override fun getItemCount() = items.size
                override fun createFragment(position: Int): Fragment = ReelFragment.newInstance(items[position])
                // Video kimliğini sayfa kimliği olarak kullan: silinen video listeden düşebilsin.
                override fun getItemId(position: Int) = items[position].id
                override fun containsItem(itemId: Long) = items.any { it.id == itemId }
            }
            pager.registerOnPageChangeCallback(object : ViewPager2.OnPageChangeCallback() {
                override fun onPageSelected(p: Int) {
                    updatePosition()
                }
            })
            if (savedOrder == null && startId != -1L) {
                val start = items.indexOfFirst { it.id == startId }
                if (start > 0) pager.setCurrentItem(start, false)
            }
            updatePosition()
            loaded = true
        }
    }

    private fun updatePosition() {
        positionText.text = "${pager.currentItem + 1} / ${items.size}"
    }

    override fun onResume() {
        super.onResume()
        if (loaded) removeDeleted()
    }

    /** Galeriden dönünce: telefondan silinen videoları akıştan çıkar. */
    private fun removeDeleted() {
        lifecycleScope.launch {
            val existing = withContext(Dispatchers.IO) {
                Videos.queryAll(this@ReelsActivity).mapTo(HashSet()) { it.id }
            }
            val gone = items.filter { it.id !in existing }.map { it.id }
            if (gone.isEmpty()) return@launch
            Store.forget(gone)
            val current = pager.currentItem
            items = items.filter { it.id in existing }
            Toast.makeText(this@ReelsActivity, "Silinen video akıştan kaldırıldı", Toast.LENGTH_SHORT).show()
            if (items.isEmpty()) {
                finish()
                return@launch
            }
            pager.adapter?.notifyDataSetChanged()
            pager.setCurrentItem(current.coerceAtMost(items.size - 1), false)
            updatePosition()
        }
    }

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        if (items.isNotEmpty()) outState.putLongArray(STATE_ORDER, items.map { it.id }.toLongArray())
    }
}
