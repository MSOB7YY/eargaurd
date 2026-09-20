package com.msob7y.eargaurd

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.AudioTrack
import android.media.MediaRecorder
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.log10
import kotlin.math.sin

data class Analysis(
    val sampleRate: Int,
    val binHz: Double,
    val bars: DoubleArray,
    val peakHz: Double,
    val peakDb: Double,
    val bandPeakHz: Double,
    val bandPeakDb: Double,
) {
    fun toMap(): Map<String, Any> = mapOf(
        "sampleRate" to sampleRate,
        "binHz" to binHz,
        "bars" to bars.toList(),
        "peakHz" to peakHz,
        "peakDb" to peakDb,
        "bandPeakHz" to bandPeakHz,
        "bandPeakDb" to bandPeakDb,
    )
}

class AudioEngine(context: Context) {

    private val am = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    fun maxVolume(): Int = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
    fun currentVolume(): Int = am.getStreamVolume(AudioManager.STREAM_MUSIC)

    fun setVolume(v: Int) {
        am.setStreamVolume(AudioManager.STREAM_MUSIC, v.coerceIn(0, maxVolume()), 0)
    }

    fun step(delta: Int) = setVolume(currentVolume() + delta)

    fun enforceCap(cap: Int) {
        if (currentVolume() > cap) setVolume(cap)
    }

    private val sources = intArrayOf(
        MediaRecorder.AudioSource.UNPROCESSED,
        MediaRecorder.AudioSource.VOICE_RECOGNITION,
        MediaRecorder.AudioSource.MIC,
    )

    private var re = DoubleArray(0)
    private var im = DoubleArray(0)
    private var win = DoubleArray(0)
    private var peak = DoubleArray(0)
    private var samples = ShortArray(0)
    private var curFft = 0

    private fun ensureBuffers(fftSize: Int) {
        if (curFft == fftSize) return
        re = DoubleArray(fftSize)
        im = DoubleArray(fftSize)
        peak = DoubleArray(fftSize / 2)
        samples = ShortArray(fftSize)
        win = DoubleArray(fftSize) { 0.5 - 0.5 * cos(2.0 * PI * it / (fftSize - 1)) }
        curFft = fftSize
    }

    private fun openRecord(sampleRate: Int, bufSize: Int): AudioRecord? {
        for (src in sources) {
            try {
                val r = AudioRecord(
                    src, sampleRate,
                    AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, bufSize,
                )
                if (r.state == AudioRecord.STATE_INITIALIZED) return r
                r.release()
            } catch (_: Exception) {
            }
        }
        return null
    }

    @Synchronized
    fun analyze(
        minHz: Int,
        maxHz: Int,
        fftSize: Int = 4096,
        frames: Int = 4,
        sampleRate: Int = 44100,
        barCount: Int = 120,
    ): Analysis? {
        val minBuf = AudioRecord.getMinBufferSize(
            sampleRate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT,
        )
        if (minBuf <= 0) return null
        val record = openRecord(sampleRate, maxOf(minBuf, fftSize * 2)) ?: return null

        ensureBuffers(fftSize)
        val half = fftSize / 2
        peak.fill(0.0)

        try {
            record.startRecording()
            repeat(frames) {
                var read = 0
                while (read < fftSize) {
                    val r = record.read(samples, read, fftSize - read)
                    if (r <= 0) break
                    read += r
                }
                if (read < fftSize) return@repeat
                for (i in 0 until fftSize) {
                    re[i] = (samples[i] / 32768.0) * win[i]
                    im[i] = 0.0
                }
                Fft.transform(re, im)
                for (b in 0 until half) {
                    val m = hypot(re[b], im[b])
                    if (m > peak[b]) peak[b] = m
                }
            }
        } catch (e: Exception) {
            record.release()
            return null
        } finally {
            try { record.stop() } catch (_: Exception) {}
            record.release()
        }

        val binHz = sampleRate.toDouble() / fftSize
        val norm = fftSize / 4.0

        val bars = DoubleArray(barCount)
        val binsPerBar = half / barCount
        for (i in 0 until barCount) {
            val start = i * binsPerBar
            val end = if (i == barCount - 1) half else (i + 1) * binsPerBar
            var mx = 0.0
            for (b in start until end) if (peak[b] > mx) mx = peak[b]
            bars[i] = toDb(mx, norm)
        }

        val minBin = (minHz / binHz).toInt().coerceIn(1, half - 1)
        val maxBin = (maxHz / binHz).toInt().coerceIn(minBin, half - 1)
        var gBin = 0
        var gMag = 0.0
        var bBin = minBin
        var bMag = 0.0
        for (b in 1 until half) {
            if (peak[b] > gMag) {
                gMag = peak[b]
                gBin = b
            }
            if (b in minBin..maxBin && peak[b] > bMag) {
                bMag = peak[b]
                bBin = b
            }
        }

        return Analysis(
            sampleRate = sampleRate,
            binHz = binHz,
            bars = bars,
            peakHz = gBin * binHz,
            peakDb = toDb(gMag, norm),
            bandPeakHz = bBin * binHz,
            bandPeakDb = toDb(bMag, norm),
        )
    }

    private fun toDb(mag: Double, norm: Double): Double =
        (20.0 * log10(mag / norm + 1e-12)).coerceAtLeast(-120.0)

    fun playWarning() {
        val sr = 44100
        val toneMs = 220
        val n = sr * toneMs / 1000
        val total = n * 2
        val buf = ShortArray(total)
        val f1 = 1000.0
        val f2 = 1600.0
        for (i in 0 until n) {
            buf[i] = (sin(2 * PI * f1 * i / sr) * 0.6 * Short.MAX_VALUE).toInt().toShort()
        }
        for (i in 0 until n) {
            buf[n + i] = (sin(2 * PI * f2 * i / sr) * 0.6 * Short.MAX_VALUE).toInt().toShort()
        }

        val track = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(sr)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build(),
            )
            .setBufferSizeInBytes(total * 2)
            .setTransferMode(AudioTrack.MODE_STATIC)
            .build()
        track.write(buf, 0, total)
        track.play()

        Thread {
            try { Thread.sleep((toneMs * 2 + 300).toLong()) } catch (_: Exception) {}
            try { track.stop() } catch (_: Exception) {}
            track.release()
        }.start()
    }
}
