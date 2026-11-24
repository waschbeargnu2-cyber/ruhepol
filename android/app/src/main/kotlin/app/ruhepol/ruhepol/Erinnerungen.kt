package app.ruhepol.ruhepol

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.drawable.Icon
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject

// ---------------------------------------------------------------------------
// ERKLÄRUNG: Erinnerungen.
// Die App (Dart) berechnet, WANN woran erinnert wird, und schickt die Liste
// hierher. Hier wird für jede Erinnerung ein Android-Wecker (AlarmManager)
// gestellt. Klingelt er, zeigt ErinnerungsEmpfaenger die Benachrichtigung.
// Die Liste wird gespeichert, damit sie nach einem Neustart des Handys wieder
// gestellt werden kann (StartEmpfaenger).
// ---------------------------------------------------------------------------
object ErinnerungsPlaner {
    const val AKTION_ERINNERN = "app.ruhepol.ruhepol.ERINNERN"
    const val AKTION_ERLEDIGT = "app.ruhepol.ruhepol.ERLEDIGT"
    const val AKTION_SPAETER = "app.ruhepol.ruhepol.SPAETER"

    private const val KANAL_ID = "erinnerungen"
    private const val PREFS = "ruhepol"
    private const val KEY_PLAN = "erinnerungsPlan"
    private const val KEY_ERLEDIGT = "erledigtAusBenachrichtigung"
    private const val SPAETER_MS = 60L * 60L * 1000L

    private fun prefs(c: Context) = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /** Ersetzt alle geplanten Erinnerungen durch [liste]. */
    fun planen(c: Context, liste: List<Map<String, Any?>>) {
        alleAbbrechen(c)
        val json = JSONArray()
        for (e in liste) {
            val o = JSONObject()
            o.put("id", (e["id"] as Number).toInt())
            o.put("zeit", (e["zeit"] as Number).toLong())
            o.put("titel", (e["titel"] as? String) ?: "Agenda")
            o.put("text", (e["text"] as? String) ?: "")
            o.put("aufgabeId", (e["aufgabeId"] as? String) ?: "")
            json.put(o)
        }
        prefs(c).edit().putString(KEY_PLAN, json.toString()).apply()
        planAusfuehren(c)
    }

    /** Stellt alle gespeicherten, noch kommenden Erinnerungen (auch nach Neustart). */
    fun planAusfuehren(c: Context) {
        val jetzt = System.currentTimeMillis()
        val json = JSONArray(prefs(c).getString(KEY_PLAN, "[]") ?: "[]")
        for (i in 0 until json.length()) {
            val o = json.getJSONObject(i)
            val zeit = o.getLong("zeit")
            if (zeit <= jetzt) continue
            stellen(
                c,
                o.getInt("id"),
                zeit,
                o.optString("titel", "Agenda"),
                o.optString("text", ""),
                o.optString("aufgabeId", "")
            )
        }
    }

    private fun alleAbbrechen(c: Context) {
        val am = c.getSystemService(AlarmManager::class.java) ?: return
        val json = JSONArray(prefs(c).getString(KEY_PLAN, "[]") ?: "[]")
        for (i in 0 until json.length()) {
            am.cancel(weckerIntent(c, json.getJSONObject(i).getInt("id"), "", "", ""))
        }
    }

    private fun weckerIntent(
        c: Context,
        id: Int,
        titel: String,
        text: String,
        aufgabeId: String
    ): PendingIntent {
        val intent = Intent(c, ErinnerungsEmpfaenger::class.java).apply {
            action = AKTION_ERINNERN
            putExtra("id", id)
            putExtra("titel", titel)
            putExtra("text", text)
            putExtra("aufgabeId", aufgabeId)
        }
        return PendingIntent.getBroadcast(
            c,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    fun exakteWeckerErlaubt(c: Context): Boolean {
        if (Build.VERSION.SDK_INT < 31) return true
        val am = c.getSystemService(AlarmManager::class.java) ?: return false
        return am.canScheduleExactAlarms()
    }

    fun stellen(c: Context, id: Int, zeit: Long, titel: String, text: String, aufgabeId: String) {
        val am = c.getSystemService(AlarmManager::class.java) ?: return
        val pi = weckerIntent(c, id, titel, text, aufgabeId)
        if (exakteWeckerErlaubt(c)) {
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, zeit, pi)
        } else {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, zeit, pi)
        }
    }

    private fun aktionIntent(
        c: Context,
        aktion: String,
        code: Int,
        id: Int,
        titel: String,
        text: String,
        aufgabeId: String
    ): PendingIntent {
        val intent = Intent(c, ErinnerungsEmpfaenger::class.java).apply {
            action = aktion
            putExtra("id", id)
            putExtra("titel", titel)
            putExtra("text", text)
            putExtra("aufgabeId", aufgabeId)
        }
        return PendingIntent.getBroadcast(
            c,
            code,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    fun benachrichtigungenErlaubt(c: Context): Boolean {
        val nm = c.getSystemService(NotificationManager::class.java) ?: return false
        if (Build.VERSION.SDK_INT >= 33 &&
            c.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) return false
        return nm.areNotificationsEnabled()
    }

    fun zeigen(c: Context, id: Int, titel: String, text: String, aufgabeId: String) {
        if (!benachrichtigungenErlaubt(c)) return
        // Schon über die Benachrichtigung erledigt? Dann nicht mehr erinnern.
        if (aufgabeId.isNotEmpty() && erledigte(c).contains(aufgabeId)) return

        val nm = c.getSystemService(NotificationManager::class.java) ?: return
        val kanal = NotificationChannel(
            KANAL_ID,
            "Erinnerungen",
            NotificationManager.IMPORTANCE_HIGH
        ).apply { description = "Erinnerungen an Aufgaben, Fristen und die Tagesübersicht" }
        nm.createNotificationChannel(kanal)

        val oeffnen = c.packageManager.getLaunchIntentForPackage(c.packageName)
            ?: Intent(c, MainActivity::class.java)
        oeffnen.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        val oeffnenPi = PendingIntent.getActivity(
            c,
            id,
            oeffnen,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = Notification.Builder(c, KANAL_ID)
            .setSmallIcon(R.drawable.ic_benachrichtigung)
            .setContentTitle(titel)
            .setContentText(text)
            .setStyle(Notification.BigTextStyle().bigText(text))
            .setContentIntent(oeffnenPi)
            .setAutoCancel(true)
            .setCategory(Notification.CATEGORY_REMINDER)

        if (aufgabeId.isNotEmpty()) {
            builder.addAction(
                Notification.Action.Builder(
                    null as Icon?,
                    "Erledigt",
                    aktionIntent(c, AKTION_ERLEDIGT, id * 3 + 1, id, titel, text, aufgabeId)
                ).build()
            )
            builder.addAction(
                Notification.Action.Builder(
                    null as Icon?,
                    "In 1 Std.",
                    aktionIntent(c, AKTION_SPAETER, id * 3 + 2, id, titel, text, aufgabeId)
                ).build()
            )
        }
        nm.notify(id, builder.build())
    }

    fun spaeter(c: Context, id: Int, titel: String, text: String, aufgabeId: String) {
        stellen(c, id, System.currentTimeMillis() + SPAETER_MS, titel, text, aufgabeId)
    }

    fun alsErledigtMerken(c: Context, aufgabeId: String) {
        val p = prefs(c)
        val menge = HashSet(p.getStringSet(KEY_ERLEDIGT, emptySet()) ?: emptySet())
        menge.add(aufgabeId)
        p.edit().putStringSet(KEY_ERLEDIGT, menge).apply()
    }

    private fun erledigte(c: Context): Set<String> =
        prefs(c).getStringSet(KEY_ERLEDIGT, emptySet()) ?: emptySet()

    /** Gibt die per Benachrichtigung erledigten Aufgaben zurück und leert die Liste. */
    fun erledigteAbholen(c: Context): List<String> {
        val liste = erledigte(c).toList()
        prefs(c).edit().remove(KEY_ERLEDIGT).apply()
        return liste
    }

    fun abbrechenAnzeige(c: Context, id: Int) {
        c.getSystemService(NotificationManager::class.java)?.cancel(id)
    }
}

/** Wird vom Wecker oder von den Knöpfen in der Benachrichtigung aufgerufen. */
class ErinnerungsEmpfaenger : BroadcastReceiver() {
    override fun onReceive(c: Context, intent: Intent) {
        val id = intent.getIntExtra("id", 0)
        val titel = intent.getStringExtra("titel") ?: "Agenda"
        val text = intent.getStringExtra("text") ?: ""
        val aufgabeId = intent.getStringExtra("aufgabeId") ?: ""
        when (intent.action) {
            ErinnerungsPlaner.AKTION_ERINNERN ->
                ErinnerungsPlaner.zeigen(c, id, titel, text, aufgabeId)
            ErinnerungsPlaner.AKTION_ERLEDIGT -> {
                if (aufgabeId.isNotEmpty()) ErinnerungsPlaner.alsErledigtMerken(c, aufgabeId)
                ErinnerungsPlaner.abbrechenAnzeige(c, id)
            }
            ErinnerungsPlaner.AKTION_SPAETER -> {
                ErinnerungsPlaner.abbrechenAnzeige(c, id)
                ErinnerungsPlaner.spaeter(c, id, titel, text, aufgabeId)
            }
        }
    }
}

/** Stellt nach einem Neustart oder App-Update alle Erinnerungen wieder. */
class StartEmpfaenger : BroadcastReceiver() {
    override fun onReceive(c: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            ErinnerungsPlaner.planAusfuehren(c)
        }
    }
}
