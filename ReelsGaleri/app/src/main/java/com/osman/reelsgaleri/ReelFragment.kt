package com.osman.reelsgaleri

import android.annotation.SuppressLint
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.GestureDetector
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.animation.OvershootInterpolator
import android.widget.ImageButton
import android.widget.ImageView
import android.widget.ProgressBar
import android.widget.TextView
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView

/** Tek bir video sayfası. Sadece ekranda olan sayfa oynatıcıyı tutar. */
class ReelFragment : Fragment(R.layout.fragment_reel) {

    companion object {
        fun newInstance(v: Video) = ReelFragment().apply {
            arguments = Bundle().apply {
                putLong("id", v.id)
                putString("uri", v.uri.toString())
                putString("name", v.name)
            }
        }
    }

    private val videoId by lazy { requireArguments().getLong("id") }
    private val uri by lazy { Uri.parse(requireArguments().getString("uri")) }
    private val name by lazy { requireArguments().getString("name") ?: "" }

    private var player: ExoPlayer? = null
    private lateinit var playerView: PlayerView
    private lateinit var likeButton: ImageButton
    private lateinit var likeText: TextView
    private lateinit var commentCount: TextView
    private lateinit var lastComment: TextView
    private lateinit var playIcon: ImageView
    private lateinit var bigHeart: ImageView
    private lateinit var progress: ProgressBar
    private lateinit var title: TextView

    private val handler = Handler(Looper.getMainLooper())
    private val progressTick = object : Runnable {
        override fun run() {
            player?.let {
                val d = it.duration
                if (d > 0) progress.progress = (it.currentPosition * 1000 / d).toInt()
            }
            handler.postDelayed(this, 100)
        }
    }

    @SuppressLint("ClickableViewAccessibility")
    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        playerView = view.findViewById(R.id.player)
        likeButton = view.findViewById(R.id.btnLike)
        likeText = view.findViewById(R.id.likeText)
        commentCount = view.findViewById(R.id.commentCount)
        lastComment = view.findViewById(R.id.lastComment)
        playIcon = view.findViewById(R.id.playIcon)
        bigHeart = view.findViewById(R.id.bigHeart)
        progress = view.findViewById(R.id.progress)
        title = view.findViewById(R.id.title)

        title.text = name.substringBeforeLast('.')
        refreshLike()
        refreshComments()

        likeButton.setOnClickListener {
            Store.toggleLike(videoId)
            refreshLike()
            pop(likeButton)
        }
        view.findViewById<ImageButton>(R.id.btnComment).setOnClickListener {
            CommentsSheet.show(requireContext(), videoId) { refreshComments() }
        }

        val detector = GestureDetector(requireContext(), object : GestureDetector.SimpleOnGestureListener() {
            override fun onDown(e: MotionEvent) = true
            override fun onSingleTapConfirmed(e: MotionEvent): Boolean {
                togglePlay()
                return true
            }
            override fun onDoubleTap(e: MotionEvent): Boolean {
                Store.like(videoId)
                refreshLike()
                showBigHeart()
                return true
            }
        })
        view.findViewById<View>(R.id.touch).setOnTouchListener { _, e -> detector.onTouchEvent(e) }
    }

    override fun onResume() {
        super.onResume()
        val p = ExoPlayer.Builder(requireContext()).build().apply {
            setMediaItem(MediaItem.fromUri(uri))
            repeatMode = Player.REPEAT_MODE_ONE
            playWhenReady = true
            addListener(object : Player.Listener {
                override fun onPlayerError(error: PlaybackException) {
                    title.text = "⚠ Bu video oynatılamadı: $name"
                }
            })
            prepare()
        }
        player = p
        playerView.player = p
        playIcon.visibility = View.GONE
        handler.post(progressTick)
    }

    override fun onPause() {
        super.onPause()
        handler.removeCallbacks(progressTick)
        playerView.player = null
        player?.release()
        player = null
    }

    private fun togglePlay() {
        val p = player ?: return
        if (p.isPlaying) {
            p.pause()
            playIcon.visibility = View.VISIBLE
        } else {
            p.play()
            playIcon.visibility = View.GONE
        }
    }

    private fun refreshLike() {
        val liked = Store.isLiked(videoId)
        likeButton.setImageResource(if (liked) R.drawable.ic_heart else R.drawable.ic_heart_outline)
        likeButton.setColorFilter(
            if (liked) ContextCompat.getColor(requireContext(), R.color.accent) else 0xFFFFFFFF.toInt()
        )
        likeText.text = if (liked) "Beğendin" else "Beğen"
    }

    private fun refreshComments() {
        val list = Store.commentsOf(videoId)
        commentCount.text = if (list.isEmpty()) "Yorum" else list.size.toString()
        lastComment.text = list.lastOrNull()?.let { "💬 ${it.text}" } ?: ""
    }

    private fun pop(v: View) {
        v.animate().scaleX(1.3f).scaleY(1.3f).setDuration(120).withEndAction {
            v.animate().scaleX(1f).scaleY(1f).setDuration(120).start()
        }.start()
    }

    private fun showBigHeart() {
        bigHeart.animate().cancel()
        bigHeart.alpha = 1f
        bigHeart.scaleX = 0.4f
        bigHeart.scaleY = 0.4f
        bigHeart.animate().scaleX(1f).scaleY(1f).setInterpolator(OvershootInterpolator()).setDuration(250)
            .withEndAction {
                bigHeart.animate().alpha(0f).setStartDelay(350).setDuration(250).start()
            }.start()
    }
}
