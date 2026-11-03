package com.osman.reelsgaleri

import android.Manifest
import android.content.ContentUris
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.util.LruCache
import android.util.Size
import android.widget.ImageView
import androidx.core.content.ContextCompat
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.asCoroutineDispatcher
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.concurrent.Executors

data class Video(
    val id: Long,
    val uri: Uri,
    val name: String,
    val durationMs: Long,
)

object Videos {

    /** İzin istenirken kullanılacak izinler. */
    fun permissions(): Array<String> = when {
        Build.VERSION.SDK_INT >= 34 -> arrayOf(
            Manifest.permission.READ_MEDIA_VIDEO,
            Manifest.permission.READ_MEDIA_VISUAL_USER_SELECTED,
        )
        Build.VERSION.SDK_INT >= 33 -> arrayOf(Manifest.permission.READ_MEDIA_VIDEO)
        else -> arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE)
    }

    fun hasAccess(ctx: Context): Boolean {
        fun granted(p: String) = ContextCompat.checkSelfPermission(ctx, p) == PackageManager.PERMISSION_GRANTED
        return when {
            Build.VERSION.SDK_INT >= 34 -> granted(Manifest.permission.READ_MEDIA_VIDEO) ||
                granted(Manifest.permission.READ_MEDIA_VISUAL_USER_SELECTED)
            Build.VERSION.SDK_INT >= 33 -> granted(Manifest.permission.READ_MEDIA_VIDEO)
            else -> granted(Manifest.permission.READ_EXTERNAL_STORAGE)
        }
    }

    /** Galerideki tüm videolar, en yeniden en eskiye. */
    fun queryAll(ctx: Context): List<Video> {
        val collection = MediaStore.Video.Media.EXTERNAL_CONTENT_URI
        val projection = arrayOf(
            MediaStore.Video.Media._ID,
            MediaStore.Video.Media.DISPLAY_NAME,
            MediaStore.Video.Media.DURATION,
        )
        val result = ArrayList<Video>()
        ctx.contentResolver.query(
            collection, projection, null, null,
            "${MediaStore.Video.Media.DATE_ADDED} DESC"
        )?.use { c ->
            val idCol = c.getColumnIndexOrThrow(MediaStore.Video.Media._ID)
            val nameCol = c.getColumnIndexOrThrow(MediaStore.Video.Media.DISPLAY_NAME)
            val durCol = c.getColumnIndexOrThrow(MediaStore.Video.Media.DURATION)
            while (c.moveToNext()) {
                val id = c.getLong(idCol)
                result += Video(
                    id = id,
                    uri = ContentUris.withAppendedId(collection, id),
                    name = c.getString(nameCol) ?: "video",
                    durationMs = c.getLong(durCol),
                )
            }
        }
        return result
    }

    /** Beğenilenler, en son beğenilen önce, sadece telefonda hâlâ duranlar. */
    fun likedOrder(all: List<Video>): List<Video> {
        val byId = all.associateBy { it.id }
        return Store.likes.toList().asReversed().mapNotNull { byId[it] }
    }

    fun formatDuration(ms: Long): String {
        if (ms <= 0) return ""
        val s = ms / 1000
        return if (s >= 3600) "%d:%02d:%02d".format(s / 3600, (s / 60) % 60, s % 60)
        else "%d:%02d".format(s / 60, s % 60)
    }
}

/** Küçük resimleri arka planda yükleyip bellekte önbelleğe alır. */
object Thumbs {
    private val dispatcher = Executors.newFixedThreadPool(4).asCoroutineDispatcher()
    private val cache = object : LruCache<Long, Bitmap>(
        (Runtime.getRuntime().maxMemory() / 1024 / 8).toInt()
    ) {
        override fun sizeOf(key: Long, value: Bitmap) = value.byteCount / 1024
    }

    fun load(scope: CoroutineScope, view: ImageView, video: Video): Job? {
        view.tag = video.id
        cache.get(video.id)?.let {
            view.setImageBitmap(it)
            return null
        }
        view.setImageDrawable(null)
        val ctx = view.context.applicationContext
        return scope.launch {
            val bmp = withContext(dispatcher) {
                try {
                    if (Build.VERSION.SDK_INT >= 29) {
                        ctx.contentResolver.loadThumbnail(video.uri, Size(320, 320), null)
                    } else {
                        @Suppress("DEPRECATION")
                        MediaStore.Video.Thumbnails.getThumbnail(
                            ctx.contentResolver, video.id,
                            MediaStore.Video.Thumbnails.MINI_KIND, null
                        )
                    }
                } catch (_: Exception) {
                    null
                }
            }
            if (bmp != null) {
                cache.put(video.id, bmp)
                if (view.tag == video.id) view.setImageBitmap(bmp)
            }
        }
    }
}
