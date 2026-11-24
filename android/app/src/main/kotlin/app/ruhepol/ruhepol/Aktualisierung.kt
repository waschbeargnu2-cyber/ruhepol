package app.ruhepol.ruhepol

import android.app.Activity
import android.content.Intent
import androidx.core.content.FileProvider
import org.json.JSONObject
import java.io.File
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

// ---------------------------------------------------------------------------
// ERKLÄRUNG: Updates direkt in der App.
// Fragt bei GitHub nach dem neuesten Release (öffentliches Repository),
// lädt die APK in den Cache der App und öffnet den Android-Installer.
// Läuft immer in einem Hintergrund-Thread (nie im UI-Thread).
// ---------------------------------------------------------------------------
object Aktualisierung {
    private const val NEUESTES_RELEASE =
        "https://api.github.com/repos/waschbeargnu2-cyber/ruhepol/releases/latest"

    private fun verbinden(adresse: String): HttpURLConnection {
        val v = URL(adresse).openConnection() as HttpURLConnection
        v.connectTimeout = 10_000
        v.readTimeout = 30_000
        v.instanceFollowRedirects = true
        v.setRequestProperty("User-Agent", "Agenda-App")
        return v
    }

    fun pruefen(): Map<String, Any?> {
        val v = verbinden(NEUESTES_RELEASE)
        v.setRequestProperty("Accept", "application/vnd.github+json")
        try {
            if (v.responseCode != 200) throw IOException("GitHub antwortet mit ${v.responseCode}")
            val json = JSONObject(v.inputStream.bufferedReader().use { it.readText() })
            val build = json.optString("tag_name").removePrefix("build-").toIntOrNull() ?: 0
            var url = ""
            var groesse = 0L
            val dateien = json.optJSONArray("assets")
            if (dateien != null) {
                for (i in 0 until dateien.length()) {
                    val d = dateien.getJSONObject(i)
                    if (d.optString("name").endsWith(".apk")) {
                        url = d.optString("browser_download_url")
                        groesse = d.optLong("size")
                    }
                }
            }
            return mapOf(
                "build" to build,
                "name" to json.optString("name"),
                "notiz" to json.optString("body"),
                "url" to url,
                "groesse" to groesse,
                "datum" to json.optString("published_at")
            )
        } finally {
            v.disconnect()
        }
    }

    fun herunterladen(activity: Activity, adresse: String): File {
        val ordner = File(activity.cacheDir, "updates")
        ordner.mkdirs()
        ordner.listFiles()?.forEach { it.delete() }
        val ziel = File(ordner, "agenda-update.apk")
        val v = verbinden(adresse)
        try {
            if (v.responseCode != 200) throw IOException("Download fehlgeschlagen (${v.responseCode})")
            v.inputStream.use { ein -> ziel.outputStream().use { aus -> ein.copyTo(aus) } }
        } finally {
            v.disconnect()
        }
        return ziel
    }

    fun installieren(activity: Activity, datei: File) {
        val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.dateien", datei)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        activity.startActivity(intent)
    }
}
