package com.osman.reelsgaleri

import android.Manifest
import android.app.RecoverableSecurityException
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import androidx.activity.result.IntentSenderRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AlertDialog
import androidx.core.content.ContextCompat
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
import kotlinx.coroutines.Job
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
    /** Normal "Reels'i İzle" modunda izlenenleri işaretle (keşfet akışı). */
    private var trackSeen = false

    /** Android 10'da izin onayından sonra tekrar denenecek video. */
    private var pendingDelete: Uri? = null

    private val deleteLauncher =
        registerForActivityResult(ActivityResultContracts.StartIntentSenderForResult()) { result ->
            val uri = pendingDelete
            pendingDelete = null
            if (result.resultCode != RESULT_OK) return@registerForActivityResult
            // Android 10: kullanıcı izin verdi, şimdi gerçekten sil.
            if (Build.VERSION.SDK_INT == 29 && uri != null) {
                try { contentResolver.delete(uri, null, null) } catch (_: Exception) {}
            }
            // Android 11+ silmeyi sistem yaptı. Listeden çıkarma onResume'da olur.
        }

    private val writePermission =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { ok ->
            val uri = pendingDelete
            pendingDelete = null
            if (ok && uri != null) deleteDirect(uri)
            else Toast.makeText(this, "Silmek için depolama izni gerekli", Toast.LENGTH_SHORT).show()
        }
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
        trackSeen = !likedOnly && startId == -1L

        lifecycleScope.launch {
            val all = withContext(Dispatchers.IO) { Videos.queryAll(this@ReelsActivity) }
            val byId = all.associateBy { it.id }
            val ids: List<Long> = when {
                savedOrder != null -> savedOrder.toList()
                likedOnly -> Videos.likedOrder(all).map { it.id } // en son beğenilen önce
                else -> Store.unseenSelected()
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
                    markProgress()
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

    /** Videoyu telefondan kalıcı olarak siler (onay sorulur). */
    fun deleteVideo(id: Long, uri: Uri) {
        if (Build.VERSION.SDK_INT >= 30) {
            // Sistem kendi onay penceresini gösterir.
            val sender = MediaStore.createDeleteRequest(contentResolver, listOf(uri)).intentSender
            deleteLauncher.launch(IntentSenderRequest.Builder(sender).build())
            return
        }
        AlertDialog.Builder(this)
            .setTitle("Video silinsin mi?")
            .setMessage("Bu video telefondan kalıcı olarak silinecek.")
            .setPositiveButton("Sil") { _, _ ->
                if (Build.VERSION.SDK_INT < 29 && ContextCompat.checkSelfPermission(
                        this, Manifest.permission.WRITE_EXTERNAL_STORAGE
                    ) != PackageManager.PERMISSION_GRANTED
                ) {
                    pendingDelete = uri
                    writePermission.launch(Manifest.permission.WRITE_EXTERNAL_STORAGE)
                } else {
                    deleteDirect(uri)
                }
            }
            .setNegativeButton("Vazgeç", null)
            .show()
    }

    private fun deleteDirect(uri: Uri) {
        try {
            contentResolver.delete(uri, null, null)
            removeDeleted()
        } catch (e: SecurityException) {
            if (Build.VERSION.SDK_INT == 29 && e is RecoverableSecurityException) {
                pendingDelete = uri
                deleteLauncher.launch(IntentSenderRequest.Builder(e.userAction.actionIntent.intentSender).build())
            } else {
                Toast.makeText(this, "Video silinemedi", Toast.LENGTH_SHORT).show()
            }
        }
    }

    private fun updatePosition() {
        positionText.text = "${pager.currentItem + 1} / ${items.size}"
    }

    /** Gecilen (ustte kalan) videolari "izlendi" say; su anki video, donusta
     *  kaldigin yer olsun diye isaretlenmez. */
    private fun markProgress() {
        if (!trackSeen || items.isEmpty()) return
        val upto = pager.currentItem
        if (upto <= 0) return
        Store.markSeen(items.subList(0, upto).map { it.id })
    }

    override fun onStop() {
        super.onStop()
        markProgress()
    }

    override fun onResume() {
        super.onResume()
        if (loaded) removeDeleted()
    }

    /** Galeriden dönünce: telefondan silinen videoları akıştan çıkar. */
    private var pruneJob: Job? = null

    private fun removeDeleted() {
        if (pruneJob?.isActive == true) return
        pruneJob = lifecycleScope.launch {
            val existing = withContext(Dispatchers.IO) {
                Videos.queryAll(this@ReelsActivity).mapTo(HashSet()) { it.id }
            }
            val gone = items.filter { it.id !in existing }.map { it.id }
            if (gone.isEmpty()) return@launch
            Store.forget(gone)
            val current = pager.currentItem
            items = items.filter { it.id in existing }
            Toast.makeText(this@ReelsActivity, "Video silindi", Toast.LENGTH_SHORT).show()
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
