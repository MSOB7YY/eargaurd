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
import kotlin.math.sqrt

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

    fun captureBand10kDbfs(sampleRate: Int = 44100, fftSize: Int = 4096): Double {
        val minBuf = AudioRecord.getMinBufferSize(
            sampleRate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT,
        )
        if (minBuf <= 0) return -999.0
        val record = try {
            AudioRecord(
                MediaRecorder.AudioSource.MIC, sampleRate,
                AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT,
                maxOf(minBuf, fftSize * 2),
            )
        } catch (e: Exception) {
            return -999.0
        }
        if (record.state != AudioRecord.STATE_INITIALIZED) {
            record.release()
            return -999.0
        }

        val samples = ShortArray(fftSize)
        var read = 0
        try {
            record.startRecording()
            while (read < fftSize) {
                val r = record.read(samples, read, fftSize - read)
                if (r <= 0) break
                read += r
            }
        } catch (e: Exception) {
            record.release()
            return -999.0
        } finally {
            try { record.stop() } catch (_: Exception) {}
            record.release()
        }
        if (read < fftSize) return -999.0

        val re = DoubleArray(fftSize)
        val im = DoubleArray(fftSize)
        for (i in 0 until fftSize) {
            val hann = 0.5 - 0.5 * cos(2.0 * PI * i / (fftSize - 1))
            re[i] = (samples[i] / 32768.0) * hann
        }
        Fft.transform(re, im)

        val binHz = sampleRate.toDouble() / fftSize
        val startBin = (10000.0 / binHz).toInt().coerceIn(1, fftSize / 2 - 1)
        val endBin = fftSize / 2
        var sumSq = 0.0
        var count = 0
        val norm = fftSize / 2.0
        for (b in startBin until endBin) {
            val mag = hypot(re[b], im[b]) / norm
            sumSq += mag * mag
            count++
        }
        if (count == 0) return -999.0
        val rms = sqrt(sumSq / count)
        return 20.0 * log10(rms + 1e-12)
    }

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
