package com.osman.reelsgaleri

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

data class Comment(val text: String, val time: Long)

/**
 * Seçili videolar, beğeniler ve yorumlar telefonun içinde (uygulamanın kendi
 * klasöründe) tek bir JSON dosyasında tutulur. İnternet gerekmez.
 */
object Store {
    private var file: File? = null

    /** Seçilen videoların MediaStore kimlikleri (sıralı). */
    val selected = LinkedHashSet<Long>()
    val likes = LinkedHashSet<Long>()
    val comments = HashMap<Long, MutableList<Comment>>()

    /** Izlenmis ("kesfedilmis") videolar: her video bir kez gelsin diye tutulur. */
    val seen = LinkedHashSet<Long>()

    fun init(ctx: Context) {
        if (file != null) return
        val f = File(ctx.applicationContext.filesDir, "data.json")
        file = f
        if (!f.exists()) return
        try {
            val o = JSONObject(f.readText())
            o.optJSONArray("selected")?.let { a -> for (i in 0 until a.length()) selected += a.getLong(i) }
            o.optJSONArray("likes")?.let { a -> for (i in 0 until a.length()) likes += a.getLong(i) }
            o.optJSONArray("seen")?.let { a -> for (i in 0 until a.length()) seen += a.getLong(i) }
            o.optJSONObject("comments")?.let { c ->
                for (key in c.keys()) {
                    val arr = c.getJSONArray(key)
                    val list = ArrayList<Comment>()
                    for (i in 0 until arr.length()) {
                        val it = arr.getJSONObject(i)
                        list += Comment(it.getString("t"), it.getLong("d"))
                    }
                    comments[key.toLong()] = list
                }
            }
        } catch (_: Exception) {
            // Bozuk dosya: boş başla, ama eski dosyayı yedekle.
            f.copyTo(File(f.parentFile, "data.bozuk.json"), overwrite = true)
        }
    }

    @Synchronized
    fun save() {
        val f = file ?: return
        val o = JSONObject()
        o.put("selected", JSONArray(selected.toList()))
        o.put("likes", JSONArray(likes.toList()))
        o.put("seen", JSONArray(seen.toList()))
        val c = JSONObject()
        for ((id, list) in comments) {
            if (list.isEmpty()) continue
            val arr = JSONArray()
            list.forEach { arr.put(JSONObject().put("t", it.text).put("d", it.time)) }
            c.put(id.toString(), arr)
        }
        o.put("comments", c)
        val tmp = File(f.parentFile, "data.json.tmp")
        tmp.writeText(o.toString())
        if (!tmp.renameTo(f)) {
            f.writeText(o.toString())
            tmp.delete()
        }
    }

    fun setSelected(ids: List<Long>) {
        selected.clear()
        selected.addAll(ids)
        save()
    }

    fun isLiked(id: Long) = id in likes

    fun toggleLike(id: Long): Boolean {
        val liked = if (id in likes) { likes.remove(id); false } else { likes.add(id); true }
        save()
        return liked
    }

    fun like(id: Long) {
        if (likes.add(id)) save()
    }

    fun commentsOf(id: Long): List<Comment> = comments[id] ?: emptyList()

    fun addComment(id: Long, text: String) {
        comments.getOrPut(id) { ArrayList() }.add(Comment(text, System.currentTimeMillis()))
        save()
    }

    fun removeComment(id: Long, comment: Comment) {
        comments[id]?.remove(comment)
        save()
    }

    /** Telefondan silinmiş videoların kayıtlarını temizler. */
    fun forget(ids: Collection<Long>) {
        if (ids.isEmpty()) return
        selected.removeAll(ids.toSet())
        likes.removeAll(ids.toSet())
        seen.removeAll(ids.toSet())
        ids.forEach { comments.remove(it) }
        save()
    }

    /** Henuz izlenmemis secili videolar (secim sirasini korur). */
    fun unseenSelected(): List<Long> = selected.filter { it !in seen }

    fun markSeen(ids: Collection<Long>) {
        if (seen.addAll(ids)) save()
    }

    fun resetSeen() {
        if (seen.isEmpty()) return
        seen.clear()
        save()
    }

    fun totalComments() = comments.values.sumOf { it.size }
}
