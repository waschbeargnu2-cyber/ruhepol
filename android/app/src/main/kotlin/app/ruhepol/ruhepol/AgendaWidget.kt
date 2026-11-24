package app.ruhepol.ruhepol

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.time.LocalDate
import java.util.Date
import java.util.Locale

// ---------------------------------------------------------------------------
// ERKLÄRUNG: Homescreen-Widget „Heute“.
// Die App (Dart) schickt bei jeder Änderung eine kleine Zusammenfassung
// (Aufgaben, Termine, Farben) hierher. Das Widget zeigt daraus die Aufgaben
// von heute. Ein Tipp auf den Kreis hakt ab: Das Widget merkt sich das, und
// die App übernimmt es beim nächsten Öffnen (wie bei den Benachrichtigungen).
// Layout: res/layout/widget_heute.xml
// ---------------------------------------------------------------------------
class AgendaWidget : AppWidgetProvider() {

    override fun onUpdate(c: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) manager.updateAppWidget(id, WidgetDaten.ansicht(c))
    }

    override fun onReceive(c: Context, intent: Intent) {
        super.onReceive(c, intent)
        if (intent.action == WidgetDaten.AKTION_ABHAKEN) {
            val aufgabeId = intent.getStringExtra("aufgabeId") ?: return
            ErinnerungsPlaner.alsErledigtMerken(c, aufgabeId)
            WidgetDaten.alsErledigtMarkieren(c, aufgabeId)
        }
    }
}

object WidgetDaten {
    const val AKTION_ABHAKEN = "app.ruhepol.ruhepol.WIDGET_ABHAKEN"
    private const val PREFS = "ruhepol"
    private const val KEY = "widgetDaten"
    private const val MAX_ZEILEN = 5

    private val ZEILEN = intArrayOf(R.id.zeile0, R.id.zeile1, R.id.zeile2, R.id.zeile3, R.id.zeile4)
    private val KREISE = intArrayOf(R.id.kreis0, R.id.kreis1, R.id.kreis2, R.id.kreis3, R.id.kreis4)
    private val TEXTE = intArrayOf(R.id.text0, R.id.text1, R.id.text2, R.id.text3, R.id.text4)
    private val INFOS = intArrayOf(R.id.info0, R.id.info1, R.id.info2, R.id.info3, R.id.info4)

    private fun daten(c: Context): JSONObject =
        try {
            JSONObject(c.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, "{}") ?: "{}")
        } catch (e: Exception) {
            JSONObject()
        }

    fun speichern(c: Context, json: String) {
        c.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY, json).apply()
        alleAktualisieren(c)
    }

    fun alleAktualisieren(c: Context) {
        val manager = AppWidgetManager.getInstance(c)
        val ids = manager.getAppWidgetIds(ComponentName(c, AgendaWidget::class.java))
        if (ids.isEmpty()) return
        val ansicht = ansicht(c)
        for (id in ids) manager.updateAppWidget(id, ansicht)
    }

    /** Sofortige Rückmeldung im Widget, bevor die App es übernimmt. */
    fun alsErledigtMarkieren(c: Context, aufgabeId: String) {
        val d = daten(c)
        val alt = d.optJSONArray("aufgaben") ?: JSONArray()
        val neu = JSONArray()
        for (i in 0 until alt.length()) {
            val a = alt.getJSONObject(i)
            if (a.optString("id") != aufgabeId) neu.put(a)
        }
        d.put("aufgaben", neu)
        val heute = LocalDate.now().toString()
        val bisher = if (d.optString("erledigtAm") == heute) d.optInt("erledigtHeute") else 0
        d.put("erledigtHeute", bisher + 1)
        d.put("erledigtAm", heute)
        speichern(c, d.toString())
    }

    private fun farbenFuer(c: Context, d: JSONObject): JSONObject {
        val modus = d.optString("modus", "system")
        val nacht = when (modus) {
            "hell" -> false
            "dunkel" -> true
            else -> (c.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
                Configuration.UI_MODE_NIGHT_YES
        }
        return d.optJSONObject(if (nacht) "dunkel" else "hell") ?: JSONObject()
    }

    private fun farbe(f: JSONObject, name: String, standard: Long): Int =
        if (f.has(name)) f.optLong(name).toInt() else standard.toInt()

    fun ansicht(c: Context): RemoteViews {
        val v = RemoteViews(c.packageName, R.layout.widget_heute)
        val d = daten(c)
        val f = farbenFuer(c, d)

        val hintergrund = farbe(f, "hintergrund", 0xFFE7F0E9)
        val text = farbe(f, "text", 0xFF1C1E23)
        val text2 = farbe(f, "text2", 0xFF5D616B)
        val akzent = farbe(f, "akzent", 0xFF4C6C57)
        val akzentText = farbe(f, "akzentText", 0xFFFFFFFF)
        val pill = farbe(f, "pill", 0xFFD3E9D9)
        val pillText = farbe(f, "pillText", 0xFF1B3324)
        val prio = f.optJSONArray("prio")

        v.setInt(R.id.hintergrund, "setColorFilter", hintergrund)
        v.setTextColor(R.id.titel, text)
        v.setTextColor(R.id.datum, text2)
        v.setTextColor(R.id.termin, text2)
        v.setTextColor(R.id.mehr, text2)
        v.setTextColor(R.id.leer, text2)
        v.setInt(R.id.pillHg, "setColorFilter", pill)
        v.setTextColor(R.id.fortschritt, pillText)
        v.setInt(R.id.neuHg, "setColorFilter", akzent)
        v.setInt(R.id.neuPlus, "setColorFilter", akzentText)

        v.setTextViewText(R.id.datum, SimpleDateFormat("EEEE, d. MMMM", Locale.GERMANY).format(Date()))

        // Aufgaben von heute (inkl. überfällige)
        val heute = LocalDate.now().toString()
        val alle = d.optJSONArray("aufgaben") ?: JSONArray()
        val faellig = mutableListOf<JSONObject>()
        for (i in 0 until alle.length()) {
            val a = alle.getJSONObject(i)
            val tag = a.optString("faellig")
            if (tag.isNotEmpty() && tag <= heute) faellig.add(a)
        }
        val erledigt = if (d.optString("erledigtAm") == heute) d.optInt("erledigtHeute") else 0
        val gesamt = faellig.size + erledigt
        v.setTextViewText(R.id.fortschritt, if (gesamt == 0) "frei" else "$erledigt/$gesamt")

        // Nächster Termin heute
        v.setViewVisibility(R.id.termin, View.GONE)
        val termine = d.optJSONArray("termine") ?: JSONArray()
        val jetzt = System.currentTimeMillis()
        val uhr = SimpleDateFormat("HH:mm", Locale.GERMANY)
        for (i in 0 until termine.length()) {
            val t = termine.getJSONObject(i)
            if (t.optString("tag") != heute) continue
            val ende = t.optLong("ende")
            if (!t.optBoolean("ganztaegig") && ende < jetzt) continue
            val zeit = if (t.optBoolean("ganztaegig")) "Ganztägig" else uhr.format(Date(t.optLong("start")))
            v.setTextViewText(R.id.termin, "◷  $zeit  ${t.optString("titel")}")
            v.setViewVisibility(R.id.termin, View.VISIBLE)
            break
        }

        // Zeilen
        for (i in 0 until MAX_ZEILEN) {
            if (i >= faellig.size) {
                v.setViewVisibility(ZEILEN[i], View.GONE)
                continue
            }
            val a = faellig[i]
            val id = a.optString("id")
            v.setViewVisibility(ZEILEN[i], View.VISIBLE)
            v.setTextViewText(TEXTE[i], a.optString("titel"))
            v.setTextColor(TEXTE[i], text)

            val teile = mutableListOf<String>()
            if (a.optString("faellig") < heute) teile.add("Überfällig")
            if (a.has("uhrzeit") && !a.isNull("uhrzeit")) {
                val m = a.optInt("uhrzeit")
                teile.add(String.format(Locale.GERMANY, "%02d:%02d", m / 60, m % 60))
            }
            val info = a.optString("info")
            if (info.isNotEmpty()) teile.add(info)
            v.setTextViewText(INFOS[i], teile.joinToString(" · "))
            v.setTextColor(INFOS[i], text2)

            val p = a.optInt("prio")
            val ring = if (prio != null && p < prio.length()) prio.optLong(p).toInt() else akzent
            v.setInt(KREISE[i], "setColorFilter", ring)

            val abhaken = Intent(c, AgendaWidget::class.java).apply {
                action = AKTION_ABHAKEN
                putExtra("aufgabeId", id)
            }
            v.setOnClickPendingIntent(
                KREISE[i],
                PendingIntent.getBroadcast(
                    c,
                    100 + i,
                    abhaken,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            )
            v.setOnClickPendingIntent(ZEILEN[i], oeffnen(c))
        }

        val rest = faellig.size - MAX_ZEILEN
        v.setViewVisibility(R.id.mehr, if (rest > 0) View.VISIBLE else View.GONE)
        v.setTextViewText(R.id.mehr, "+ $rest weitere")

        v.setViewVisibility(R.id.leer, if (faellig.isEmpty()) View.VISIBLE else View.GONE)
        v.setTextViewText(
            R.id.leer,
            if (d.length() == 0) "Öffne Agenda einmal, dann erscheinen hier deine Aufgaben."
            else if (erledigt > 0) "Alles geschafft für heute. Stark!"
            else "Heute steht nichts an. Genieß den Tag!"
        )

        v.setOnClickPendingIntent(R.id.kopf, oeffnen(c))
        v.setOnClickPendingIntent(R.id.leer, oeffnen(c))
        val neu = Intent(c, MainActivity::class.java).apply {
            action = MainActivity.AKTION_NEU
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        v.setOnClickPendingIntent(
            R.id.neu,
            PendingIntent.getActivity(
                c,
                201,
                neu,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        )
        return v
    }

    private fun oeffnen(c: Context): PendingIntent {
        val intent = c.packageManager.getLaunchIntentForPackage(c.packageName)
            ?: Intent(c, MainActivity::class.java)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        return PendingIntent.getActivity(
            c,
            200,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}
