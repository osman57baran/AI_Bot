package com.osman.reelsgaleri

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import android.widget.Toast
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.GridLayoutManager
import androidx.recyclerview.widget.RecyclerView
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** Galerideki tüm videoları ızgara halinde gösterir; dokunarak seçilir. */
class PickerActivity : AppCompatActivity() {

    private var videos: List<Video> = emptyList()
    private val chosen = HashSet<Long>()
    private lateinit var countText: TextView
    private lateinit var allButton: Button
    private val adapter = Adapter()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_picker)
        Store.init(this)
        chosen.addAll(Store.selected)

        countText = findViewById(R.id.count)
        allButton = findViewById(R.id.btnAll)
        val grid = findViewById<RecyclerView>(R.id.grid)
        grid.layoutManager = GridLayoutManager(this, 3)
        grid.adapter = adapter
        grid.setHasFixedSize(true)

        allButton.setOnClickListener {
            if (chosen.size == videos.size) chosen.clear() else chosen.addAll(videos.map { it.id })
            adapter.notifyDataSetChanged()
            updateHeader()
        }
        findViewById<Button>(R.id.btnSave).setOnClickListener { saveAndClose() }
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() = saveAndClose()
        })

        countText.text = "Yükleniyor…"
        lifecycleScope.launch {
            videos = withContext(Dispatchers.IO) { Videos.queryAll(this@PickerActivity) }
            // Galeriden silinmiş videoları seçimden çıkar.
            val existing = videos.mapTo(HashSet()) { it.id }
            chosen.retainAll(existing)
            adapter.notifyDataSetChanged()
            updateHeader()
            if (videos.isEmpty()) {
                findViewById<TextView>(R.id.empty).apply {
                    visibility = View.VISIBLE
                    text = "Galeride video bulunamadı."
                }
            }
        }
    }

    private fun updateHeader() {
        countText.text = "${chosen.size} / ${videos.size} seçili"
        allButton.text = if (videos.isNotEmpty() && chosen.size == videos.size) "Seçimi kaldır" else "Tümünü seç"
    }

    private fun saveAndClose() {
        // Galeri sırasını (en yeni önce) koru.
        Store.setSelected(videos.filter { it.id in chosen }.map { it.id })
        Toast.makeText(this, "${chosen.size} video kaydedildi", Toast.LENGTH_SHORT).show()
        finish()
    }

    private inner class Holder(v: View) : RecyclerView.ViewHolder(v) {
        val thumb: ImageView = v.findViewById(R.id.thumb)
        val overlay: View = v.findViewById(R.id.overlay)
        val check: View = v.findViewById(R.id.check)
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
            val sel = v.id in chosen
            h.overlay.visibility = if (sel) View.VISIBLE else View.GONE
            h.check.visibility = if (sel) View.VISIBLE else View.GONE
            h.itemView.setOnClickListener {
                if (!chosen.remove(v.id)) chosen.add(v.id)
                notifyItemChanged(h.bindingAdapterPosition)
                updateHeader()
            }
        }
    }
}
