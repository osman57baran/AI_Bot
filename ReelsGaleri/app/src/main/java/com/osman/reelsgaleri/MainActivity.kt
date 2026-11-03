package com.osman.reelsgaleri

import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.TextView
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.materialswitch.MaterialSwitch

class MainActivity : AppCompatActivity() {

    private var afterPermission: (() -> Unit)? = null

    private val permissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) {
            if (Videos.hasAccess(this)) {
                afterPermission?.invoke()
            } else {
                Toast.makeText(this, "Videoları görmek için galeri izni gerekli", Toast.LENGTH_LONG).show()
            }
            afterPermission = null
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        Store.init(this)

        val shuffle = findViewById<MaterialSwitch>(R.id.swShuffle)
        val prefs = getSharedPreferences("ayarlar", MODE_PRIVATE)
        shuffle.isChecked = prefs.getBoolean("shuffle", false)
        shuffle.setOnCheckedChangeListener { _, checked ->
            prefs.edit().putBoolean("shuffle", checked).apply()
        }

        findViewById<Button>(R.id.btnPick).setOnClickListener {
            withPermission { startActivity(Intent(this, PickerActivity::class.java)) }
        }
        findViewById<Button>(R.id.btnWatch).setOnClickListener {
            if (Store.selected.isEmpty()) {
                Toast.makeText(this, "Önce galeriden video seç", Toast.LENGTH_SHORT).show()
                withPermission { startActivity(Intent(this, PickerActivity::class.java)) }
            } else {
                withPermission { openReels(likedOnly = false, shuffle.isChecked) }
            }
        }
        findViewById<Button>(R.id.btnLiked).setOnClickListener {
            if (Store.likes.isEmpty()) {
                Toast.makeText(this, "Henüz beğendiğin video yok", Toast.LENGTH_SHORT).show()
            } else {
                withPermission { openReels(likedOnly = true, shuffle.isChecked) }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        findViewById<TextView>(R.id.stats).text =
            "🎬 Seçili video: ${Store.selected.size}\n" +
                "❤ Beğenilen: ${Store.likes.size}\n" +
                "💬 Yorum: ${Store.totalComments()}"
    }

    private fun openReels(likedOnly: Boolean, shuffle: Boolean) {
        startActivity(
            Intent(this, ReelsActivity::class.java)
                .putExtra(ReelsActivity.EXTRA_LIKED, likedOnly)
                .putExtra(ReelsActivity.EXTRA_SHUFFLE, shuffle)
        )
    }

    private fun withPermission(action: () -> Unit) {
        if (Videos.hasAccess(this)) {
            action()
        } else {
            afterPermission = action
            permissionLauncher.launch(Videos.permissions())
        }
    }
}
