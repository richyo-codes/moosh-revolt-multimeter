package ca.richyoung.mooshrevolt

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val continuityChannel = "ca.richyoung.mooshrevolt/continuity_tone"
    private lateinit var continuityTone: ContinuityTone

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        continuityTone = ContinuityTone(getSystemService(Context.AUDIO_SERVICE) as AudioManager)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, continuityChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        continuityTone.start()
                        result.success(null)
                    }
                    "stop" -> {
                        continuityTone.stop()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onPause() {
        continuityTone.stop()
        super.onPause()
    }

    override fun onDestroy() {
        continuityTone.release()
        super.onDestroy()
    }
}

/** A low-latency, looping 880 Hz tone for continuity mode. */
private class ContinuityTone(private val audioManager: AudioManager) {
    private var audioTrack: AudioTrack? = null
    private var hasAudioFocus = false

    fun start() {
        if (audioTrack?.playState == AudioTrack.PLAYSTATE_PLAYING) return
        requestAudioFocus()

        val sampleRate = 44100
        val sampleCount = sampleRate / 10
        val pcm = ShortArray(sampleCount) { index ->
            val fadeSamples = 220
            val envelope = minOf(1.0, index.toDouble() / fadeSamples, (sampleCount - index).toDouble() / fadeSamples)
            (kotlin.math.sin(2.0 * Math.PI * 880.0 * index / sampleRate) * 12000.0 * envelope).toInt().toShort()
        }
        val track = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setSampleRate(sampleRate)
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build(),
            )
            .setBufferSizeInBytes(pcm.size * 2)
            .setTransferMode(AudioTrack.MODE_STATIC)
            .build()
        track.write(pcm, 0, pcm.size)
        track.setLoopPoints(0, pcm.size, -1)
        track.play()
        audioTrack = track
    }

    fun stop() {
        audioTrack?.let { track ->
            if (track.playState == AudioTrack.PLAYSTATE_PLAYING) track.stop()
            track.release()
        }
        audioTrack = null
        abandonAudioFocus()
    }

    fun release() = stop()

    @Suppress("DEPRECATION")
    private fun requestAudioFocus() {
        if (!hasAudioFocus) {
            hasAudioFocus = audioManager.requestAudioFocus(
                null,
                AudioManager.STREAM_MUSIC,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK,
            ) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        }
    }

    @Suppress("DEPRECATION")
    private fun abandonAudioFocus() {
        if (hasAudioFocus) audioManager.abandonAudioFocus(null)
        hasAudioFocus = false
    }
}
