package com.osman.reelsgaleri

import android.content.Context
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.view.inputmethod.EditorInfo
import android.widget.EditText
import android.widget.TextView
import androidx.appcompat.app.AlertDialog
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.bottomsheet.BottomSheetBehavior
import com.google.android.material.bottomsheet.BottomSheetDialog
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Bir videonun yorumlarını gösteren ve yeni yorum yazdıran alt panel. */
object CommentsSheet {

    private val dateFormat = SimpleDateFormat("d MMMM yyyy, HH:mm", Locale("tr"))

    fun show(ctx: Context, videoId: Long, onChanged: () -> Unit) {
        val dialog = BottomSheetDialog(ctx)
        val view = LayoutInflater.from(ctx).inflate(R.layout.sheet_comments, null)
        dialog.setContentView(view)
        dialog.behavior.state = BottomSheetBehavior.STATE_EXPANDED
        dialog.behavior.skipCollapsed = true
        dialog.window?.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE)

        val titleView = view.findViewById<TextView>(R.id.sheetTitle)
        val empty = view.findViewById<View>(R.id.noComments)
        val list = view.findViewById<RecyclerView>(R.id.list)
        val input = view.findViewById<EditText>(R.id.input)

        val items = ArrayList(Store.commentsOf(videoId))

        lateinit var adapter: RecyclerView.Adapter<RecyclerView.ViewHolder>
        fun refresh() {
            titleView.text = "Yorumlar (${items.size})"
            empty.visibility = if (items.isEmpty()) View.VISIBLE else View.GONE
            list.visibility = if (items.isEmpty()) View.GONE else View.VISIBLE
        }

        adapter = object : RecyclerView.Adapter<RecyclerView.ViewHolder>() {
            override fun getItemCount() = items.size
            override fun onCreateViewHolder(parent: ViewGroup, viewType: Int) =
                object : RecyclerView.ViewHolder(
                    LayoutInflater.from(parent.context).inflate(R.layout.item_comment, parent, false)
                ) {}

            override fun onBindViewHolder(h: RecyclerView.ViewHolder, position: Int) {
                val c = items[position]
                h.itemView.findViewById<TextView>(R.id.text).text = c.text
                h.itemView.findViewById<TextView>(R.id.date).text = dateFormat.format(Date(c.time))
                h.itemView.setOnLongClickListener {
                    AlertDialog.Builder(ctx)
                        .setMessage("Bu yorum silinsin mi?")
                        .setPositiveButton("Sil") { _, _ ->
                            Store.removeComment(videoId, c)
                            val i = items.indexOf(c)
                            if (i >= 0) {
                                items.removeAt(i)
                                adapter.notifyItemRemoved(i)
                            }
                            refresh()
                            onChanged()
                        }
                        .setNegativeButton("Vazgeç", null)
                        .show()
                    true
                }
            }
        }
        list.layoutManager = LinearLayoutManager(ctx)
        list.adapter = adapter
        if (items.isNotEmpty()) list.scrollToPosition(items.size - 1)

        fun send() {
            val text = input.text.toString().trim()
            if (text.isEmpty()) return
            Store.addComment(videoId, text)
            items.clear()
            items.addAll(Store.commentsOf(videoId))
            adapter.notifyItemInserted(items.size - 1)
            list.scrollToPosition(items.size - 1)
            input.text.clear()
            refresh()
            onChanged()
        }
        view.findViewById<View>(R.id.send).setOnClickListener { send() }
        input.setOnEditorActionListener { _, actionId, _ ->
            if (actionId == EditorInfo.IME_ACTION_SEND) { send(); true } else false
        }

        refresh()
        dialog.show()
    }
}
