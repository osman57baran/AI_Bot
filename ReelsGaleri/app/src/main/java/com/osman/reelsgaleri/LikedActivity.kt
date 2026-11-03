package com.osman.reelsgaleri

import android.content.Intent
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.GridLayoutManager
import androidx.recyclerview.widget.RecyclerView
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** Beğenilen videolar ızgara halinde; dokununca o videodan itibaren Reels açılır. */
class LikedActivity : AppCompatActivity() {

    private var videos: List<Video> = emptyList()
    private val adapter = Adapter()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_liked)
        Store.init(this)
        val grid = findViewById<RecyclerView>(R.id.grid)
        grid.layoutManager = GridLayoutManager(this, 3)
        grid.adapter = adapter
    }

    override fun onResume() {
        super.onResume()
        // Reels'te beğeni kaldırılmış ya da video silinmiş olabilir: her dönüşte yenile.
        lifecycleScope.launch {
            val all = withContext(Dispatchers.IO) { Videos.queryAll(this@LikedActivity) }
            videos = Videos.likedOrder(all)
            adapter.notifyDataSetChanged()
            findViewById<TextView>(R.id.header).text = "❤ Beğendiklerim (${videos.size})"
            findViewById<View>(R.id.empty).visibility = if (videos.isEmpty()) View.VISIBLE else View.GONE
        }
    }

    private inner class Holder(v: View) : RecyclerView.ViewHolder(v) {
        val thumb: ImageView = v.findViewById(R.id.thumb)
        val duration: TextView = v.findViewById(R.id.duration)
        var job: Job? = null
    }

    private inner class Adapter : RecyclerView.Adapter<Holder>() {
        override fun getItemCount() = videos.size

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int) =
            Holder(LayoutInflater.from(parent.context).inflate(R.layout.item_video, parent, false))

        override fun onBindViewHolder(h: Holder, position: Int) {
            val v = videos[position]
            h.job?.cancel()
            h.job = Thumbs.load(lifecycleScope, h.thumb, v)
            h.duration.text = Videos.formatDuration(v.durationMs)
            h.itemView.setOnClickListener {
                startActivity(
                    Intent(this@LikedActivity, ReelsActivity::class.java)
                        .putExtra(ReelsActivity.EXTRA_LIKED, true)
                        .putExtra(ReelsActivity.EXTRA_START_ID, v.id)
                )
            }
        }
    }
}
