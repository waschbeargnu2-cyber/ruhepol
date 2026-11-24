package app.ruhepol.ruhepol

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.CalendarContract
import android.provider.CalendarContract.Calendars
import android.provider.CalendarContract.Events
import android.provider.CalendarContract.Instances
import android.provider.Settings
import android.speech.RecognizerIntent
import androidx.core.content.pm.PackageInfoCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

// ---------------------------------------------------------------------------
// ERKLÄRUNG: Brücke zum Kalender des Handys (Android „CalendarContract“).
// Android stellt hier ALLE Kalender bereit, die auf dem Handy eingerichtet
// sind (Google, Samsung …). Android synchronisiert sie selbst mit Google.
// Die Dart-Seite ruft diese Funktionen über den Kanal "ruhepol/kalender" auf
// (siehe lib/handy_kalender.dart).
// ---------------------------------------------------------------------------
class MainActivity : FlutterActivity() {

    companion object {
        private const val KANAL = "ruhepol/kalender"
        private const val ANFRAGE_CODE = 4711
        private const val ANFRAGE_BENACHRICHTIGUNG = 4712
        private const val ANFRAGE_SPRACHE = 4713
        private const val KONTO = "Ruhepol"
        const val AKTION_NEU = "app.ruhepol.ruhepol.NEUE_AUFGABE"
    }

    private var offeneAnfrage: MethodChannel.Result? = null
    private var offeneBenachrichtigungsAnfrage: MethodChannel.Result? = null
    private var kanal: MethodChannel? = null
    private var offeneSprache: MethodChannel.Result? = null

    @Deprecated("Für die Spracherkennung reicht die klassische Variante")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != ANFRAGE_SPRACHE) return
        val antwort = offeneSprache ?: return
        offeneSprache = null
        val text = if (resultCode == RESULT_OK) {
            data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)?.firstOrNull()
        } else {
            null
        }
        antwort.success(text)
    }

    /** Aktion, mit der die App geöffnet wurde (Teilen, Kurzbefehl, Widget). */
    private var wartendeAktion: Map<String, Any?>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        wartendeAktion = aktionAus(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val aktion = aktionAus(intent) ?: return
        val k = kanal
        if (k != null) k.invokeMethod("aktion", aktion) else wartendeAktion = aktion
    }

    private fun aktionAus(intent: Intent?): Map<String, Any?>? {
        if (intent == null) return null
        return when (intent.action) {
            Intent.ACTION_SEND ->
                if (intent.type?.startsWith("text/") == true) {
                    mapOf(
                        "aktion" to "teilen",
                        "text" to (intent.getStringExtra(Intent.EXTRA_TEXT) ?: ""),
                        "betreff" to intent.getStringExtra(Intent.EXTRA_SUBJECT)
                    )
                } else {
                    null
                }
            AKTION_NEU -> mapOf("aktion" to "neu")
            else -> null
        }
    }

    private fun imHintergrund(result: MethodChannel.Result, arbeit: () -> Any?) {
        Thread {
            try {
                val wert = arbeit()
                runOnUiThread { result.success(wert) }
            } catch (e: Exception) {
                runOnUiThread { result.error("netz", e.message ?: e.toString(), null) }
            }
        }.start()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val k = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, KANAL)
        kanal = k
        k.setMethodCallHandler { call, result ->
                try {
                    behandeln(call, result)
                } catch (e: SecurityException) {
                    result.error("keine_berechtigung", e.message, null)
                } catch (e: Exception) {
                    result.error("fehler", e.message ?: e.toString(), null)
                }
            }
    }

    private fun behandeln(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> result.success(berechtigungsStatus())
            "berechtigungAnfragen" -> berechtigungAnfragen(result)
            "einstellungenOeffnen" -> {
                startActivity(
                    Intent(
                        Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        Uri.fromParts("package", packageName, null)
                    )
                )
                result.success(null)
            }
            "kalender" -> result.success(kalenderListe())
            "eigenerKalender" -> result.success(
                eigenerKalender(
                    call.argument<String>("name") ?: KONTO,
                    call.argument<Number>("farbe")?.toInt() ?: 0xFF7FA88C.toInt()
                )
            )
            "termine" -> result.success(
                termine(
                    call.argument<Number>("von")!!.toLong(),
                    call.argument<Number>("bis")!!.toLong()
                )
            )
            "eintragSpeichern" -> result.success(eintragSpeichern(call))
            "eintragLoeschen" -> result.success(eintragLoeschen(call.argument<String>("id")!!))

            // Erinnerungen
            "benachrichtigungStatus" -> result.success(benachrichtigungsStatus())
            "benachrichtigungAnfragen" -> benachrichtigungAnfragen(result)
            "exakteWecker" -> result.success(ErinnerungsPlaner.exakteWeckerErlaubt(this))
            "erinnerungenPlanen" -> {
                val liste = call.argument<List<Map<String, Any?>>>("liste") ?: emptyList()
                ErinnerungsPlaner.planen(this, liste)
                result.success(liste.size)
            }
            "testErinnerung" -> {
                ErinnerungsPlaner.stellen(
                    this,
                    99999,
                    System.currentTimeMillis() + 10_000L,
                    "Agenda",
                    "So sehen deine Erinnerungen aus.",
                    ""
                )
                result.success(null)
            }
            "erledigteAbholen" -> result.success(ErinnerungsPlaner.erledigteAbholen(this))

            // Material You: Akzentfarbe aus dem Hintergrundbild (ab Android 12)
            "systemFarbe" -> result.success(
                if (Build.VERSION.SDK_INT >= 31) getColor(android.R.color.system_accent1_500) else null
            )

            // Spracheingabe über die Spracherkennung des Handys
            "spracheingabe" -> {
                if (offeneSprache != null) {
                    result.error("laeuft", "Spracheingabe läuft schon", null)
                } else {
                    val sprache = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                        putExtra(
                            RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                            RecognizerIntent.LANGUAGE_MODEL_FREE_FORM
                        )
                        putExtra(RecognizerIntent.EXTRA_LANGUAGE, "de-DE")
                        putExtra(RecognizerIntent.EXTRA_PROMPT, "Aufgabe sprechen, z. B. „Zahnarzt morgen 15 Uhr“")
                    }
                    try {
                        offeneSprache = result
                        startActivityForResult(sprache, ANFRAGE_SPRACHE)
                    } catch (e: ActivityNotFoundException) {
                        offeneSprache = null
                        result.error("nichtVerfuegbar", "Keine Spracherkennung gefunden", null)
                    }
                }
            }

            // App-Start-Aktion (Teilen, Kurzbefehl, Widget)
            "startAktion" -> {
                result.success(wartendeAktion)
                wartendeAktion = null
            }

            // Widget
            "widgetAktualisieren" -> {
                WidgetDaten.speichern(this, call.argument<String>("json") ?: "{}")
                result.success(null)
            }

            // Updates
            "appVersion" -> {
                val info = packageManager.getPackageInfo(packageName, 0)
                result.success(
                    mapOf(
                        "name" to info.versionName,
                        "build" to PackageInfoCompat.getLongVersionCode(info).toInt()
                    )
                )
            }
            "updatePruefen" -> imHintergrund(result) { Aktualisierung.pruefen() }
            "updateInstallieren" -> {
                if (!packageManager.canRequestPackageInstalls()) {
                    startActivity(
                        Intent(
                            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                            Uri.parse("package:$packageName")
                        )
                    )
                    result.success("erlaubnis")
                } else {
                    val url = call.argument<String>("url")!!
                    imHintergrund(result) {
                        val datei = Aktualisierung.herunterladen(this, url)
                        runOnUiThread { Aktualisierung.installieren(this, datei) }
                        "gestartet"
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    // ------------------------------------------------------------ Berechtigung

    private fun hatBerechtigung(): Boolean {
        if (Build.VERSION.SDK_INT < 23) return true
        return checkSelfPermission(Manifest.permission.READ_CALENDAR) == PackageManager.PERMISSION_GRANTED &&
            checkSelfPermission(Manifest.permission.WRITE_CALENDAR) == PackageManager.PERMISSION_GRANTED
    }

    private fun berechtigungsStatus(): String {
        if (hatBerechtigung()) return "erteilt"
        val gefragt = getSharedPreferences("ruhepol", MODE_PRIVATE)
            .getBoolean("kalenderGefragt", false)
        if (!gefragt) return "nichtGefragt"
        val nochmalFragbar = Build.VERSION.SDK_INT >= 23 &&
            shouldShowRequestPermissionRationale(Manifest.permission.READ_CALENDAR)
        return if (nochmalFragbar) "verweigert" else "dauerhaftVerweigert"
    }

    private fun berechtigungAnfragen(result: MethodChannel.Result) {
        if (hatBerechtigung() || Build.VERSION.SDK_INT < 23) {
            result.success("erteilt")
            return
        }
        if (offeneAnfrage != null) {
            result.error("laeuft", "Es läuft schon eine Anfrage", null)
            return
        }
        getSharedPreferences("ruhepol", MODE_PRIVATE).edit()
            .putBoolean("kalenderGefragt", true).apply()
        offeneAnfrage = result
        requestPermissions(
            arrayOf(Manifest.permission.READ_CALENDAR, Manifest.permission.WRITE_CALENDAR),
            ANFRAGE_CODE
        )
    }

    private fun benachrichtigungsStatus(): String {
        if (ErinnerungsPlaner.benachrichtigungenErlaubt(this)) return "erteilt"
        if (Build.VERSION.SDK_INT < 33) return "dauerhaftVerweigert" // in den Einstellungen aus
        val gefragt = getSharedPreferences("ruhepol", MODE_PRIVATE)
            .getBoolean("benachrichtigungGefragt", false)
        if (!gefragt) return "nichtGefragt"
        return if (shouldShowRequestPermissionRationale(Manifest.permission.POST_NOTIFICATIONS)) {
            "verweigert"
        } else {
            "dauerhaftVerweigert"
        }
    }

    private fun benachrichtigungAnfragen(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 33 || ErinnerungsPlaner.benachrichtigungenErlaubt(this)) {
            result.success(benachrichtigungsStatus())
            return
        }
        if (offeneBenachrichtigungsAnfrage != null) {
            result.error("laeuft", "Es läuft schon eine Anfrage", null)
            return
        }
        getSharedPreferences("ruhepol", MODE_PRIVATE).edit()
            .putBoolean("benachrichtigungGefragt", true).apply()
        offeneBenachrichtigungsAnfrage = result
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), ANFRAGE_BENACHRICHTIGUNG)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        when (requestCode) {
            ANFRAGE_CODE -> {
                val antwort = offeneAnfrage ?: return
                offeneAnfrage = null
                antwort.success(berechtigungsStatus())
            }
            ANFRAGE_BENACHRICHTIGUNG -> {
                val antwort = offeneBenachrichtigungsAnfrage ?: return
                offeneBenachrichtigungsAnfrage = null
                antwort.success(benachrichtigungsStatus())
            }
        }
    }

    // ------------------------------------------------------------ Lesen

    private fun kalenderListe(): List<Map<String, Any?>> {
        val liste = mutableListOf<Map<String, Any?>>()
        val felder = arrayOf(
            Calendars._ID,
            Calendars.CALENDAR_DISPLAY_NAME,
            Calendars.ACCOUNT_NAME,
            Calendars.ACCOUNT_TYPE,
            Calendars.CALENDAR_COLOR,
            Calendars.CALENDAR_ACCESS_LEVEL,
            Calendars.VISIBLE
        )
        contentResolver.query(Calendars.CONTENT_URI, felder, null, null, null)?.use { c ->
            while (c.moveToNext()) {
                liste.add(
                    mapOf(
                        "id" to c.getLong(0).toString(),
                        "name" to (c.getString(1) ?: "Kalender"),
                        "konto" to c.getString(2),
                        "kontoTyp" to c.getString(3),
                        "farbe" to c.getInt(4),
                        "schreibbar" to (c.getInt(5) >= Calendars.CAL_ACCESS_CONTRIBUTOR),
                        "sichtbar" to (c.getInt(6) == 1)
                    )
                )
            }
        }
        return liste
    }

    private fun termine(von: Long, bis: Long): List<Map<String, Any?>> {
        val liste = mutableListOf<Map<String, Any?>>()
        val builder = Instances.CONTENT_URI.buildUpon()
        ContentUris.appendId(builder, von)
        ContentUris.appendId(builder, bis)
        val felder = arrayOf(
            Instances.EVENT_ID,
            Instances.TITLE,
            Instances.BEGIN,
            Instances.END,
            Instances.ALL_DAY,
            Instances.CALENDAR_ID,
            Instances.EVENT_LOCATION,
            Instances.DISPLAY_COLOR,
            Instances.CALENDAR_DISPLAY_NAME
        )
        contentResolver.query(
            builder.build(),
            felder,
            "${Instances.VISIBLE} = 1",
            null,
            "${Instances.BEGIN} ASC"
        )?.use { c ->
            while (c.moveToNext()) {
                liste.add(
                    mapOf(
                        "eventId" to c.getLong(0).toString(),
                        "titel" to c.getString(1),
                        "start" to c.getLong(2),
                        "ende" to c.getLong(3),
                        "ganztaegig" to (c.getInt(4) == 1),
                        "kalenderId" to c.getLong(5).toString(),
                        "ort" to c.getString(6),
                        "farbe" to c.getInt(7),
                        "kalenderName" to c.getString(8)
                    )
                )
            }
        }
        return liste
    }

    // ------------------------------------------------------------ Schreiben

    /**
     * Sucht den eigenen Kalender (nur auf dem Handy) oder legt ihn an.
     * Das interne Konto heißt weiter „Ruhepol“, angezeigt wird [name].
     */
    private fun eigenerKalender(name: String, farbe: Int): String {
        var vorhanden: Long? = null
        contentResolver.query(
            Calendars.CONTENT_URI,
            arrayOf(Calendars._ID),
            "${Calendars.ACCOUNT_TYPE} = ? AND ${Calendars.ACCOUNT_NAME} = ?",
            arrayOf(CalendarContract.ACCOUNT_TYPE_LOCAL, KONTO),
            null
        )?.use { c ->
            if (c.moveToFirst()) vorhanden = c.getLong(0)
        }
        vorhanden?.let { id ->
            // Anzeigenamen nachziehen (z. B. nach der Umbenennung in „Agenda“)
            val aendern = ContentUris.withAppendedId(Calendars.CONTENT_URI, id).buildUpon()
                .appendQueryParameter(CalendarContract.CALLER_IS_SYNCADAPTER, "true")
                .appendQueryParameter(Calendars.ACCOUNT_NAME, KONTO)
                .appendQueryParameter(Calendars.ACCOUNT_TYPE, CalendarContract.ACCOUNT_TYPE_LOCAL)
                .build()
            val werte = ContentValues().apply {
                put(Calendars.CALENDAR_DISPLAY_NAME, name)
                put(Calendars.NAME, name)
            }
            try {
                contentResolver.update(aendern, werte, null, null)
            } catch (e: Exception) {
                // Umbenennen ist nicht wichtig genug, um abzubrechen.
            }
            return id.toString()
        }

        val uri = Calendars.CONTENT_URI.buildUpon()
            .appendQueryParameter(CalendarContract.CALLER_IS_SYNCADAPTER, "true")
            .appendQueryParameter(Calendars.ACCOUNT_NAME, KONTO)
            .appendQueryParameter(Calendars.ACCOUNT_TYPE, CalendarContract.ACCOUNT_TYPE_LOCAL)
            .build()
        val werte = ContentValues().apply {
            put(Calendars.ACCOUNT_NAME, KONTO)
            put(Calendars.ACCOUNT_TYPE, CalendarContract.ACCOUNT_TYPE_LOCAL)
            put(Calendars.NAME, name)
            put(Calendars.CALENDAR_DISPLAY_NAME, name)
            put(Calendars.CALENDAR_COLOR, farbe)
            put(Calendars.CALENDAR_ACCESS_LEVEL, Calendars.CAL_ACCESS_OWNER)
            put(Calendars.OWNER_ACCOUNT, KONTO)
            put(Calendars.VISIBLE, 1)
            put(Calendars.SYNC_EVENTS, 1)
            put(Calendars.CALENDAR_TIME_ZONE, TimeZone.getDefault().id)
        }
        val neu = contentResolver.insert(uri, werte)
            ?: throw IllegalStateException("Kalender konnte nicht angelegt werden")
        return ContentUris.parseId(neu).toString()
    }

    private fun eintragExistiert(id: String): Boolean {
        contentResolver.query(
            Events.CONTENT_URI,
            arrayOf(Events._ID),
            "${Events._ID} = ? AND ${Events.DELETED} = 0",
            arrayOf(id),
            null
        )?.use { c -> return c.count > 0 }
        return false
    }

    /** Ändert einen Eintrag oder legt ihn neu an. Gibt die Eintrags-ID zurück. */
    private fun eintragSpeichern(call: MethodCall): String? {
        val id = call.argument<String>("id")
        val werte = ContentValues().apply {
            put(Events.TITLE, call.argument<String>("titel") ?: "")
            put(Events.DESCRIPTION, call.argument<String>("beschreibung") ?: "")
            put(Events.DTSTART, call.argument<Number>("start")!!.toLong())
            put(Events.DTEND, call.argument<Number>("ende")!!.toLong())
            put(Events.EVENT_TIMEZONE, TimeZone.getDefault().id)
        }
        if (id != null && eintragExistiert(id)) {
            contentResolver.update(
                ContentUris.withAppendedId(Events.CONTENT_URI, id.toLong()),
                werte,
                null,
                null
            )
            return id
        }
        werte.put(Events.CALENDAR_ID, call.argument<String>("kalenderId")!!.toLong())
        val neu = contentResolver.insert(Events.CONTENT_URI, werte) ?: return null
        return ContentUris.parseId(neu).toString()
    }

    private fun eintragLoeschen(id: String): Int =
        contentResolver.delete(ContentUris.withAppendedId(Events.CONTENT_URI, id.toLong()), null, null)
}
