package com.example.bridge_lab.bridges

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/** Hand-off between the share receiver and the Flutter bridge. Main thread only. */
object ShareStore {
    private const val PREFS = "bridge_lab_share"
    private const val KEY = "pending"

    /** Set only while Flutter is running and Dart has said "ready". */
    var listener: ((JSONObject) -> Unit)? = null

    fun add(context: Context, item: JSONObject) {
        val live = listener
        if (live != null) live(item) else persist(context, item)
    }

    fun persist(context: Context, item: JSONObject) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val all = JSONArray(prefs.getString(KEY, "[]"))
        all.put(item)
        prefs.edit().putString(KEY, all.toString()).commit() // commit: survive the process dying
    }

    fun drain(context: Context): JSONArray {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val stored = JSONArray(prefs.getString(KEY, "[]"))
        prefs.edit().remove(KEY).commit()
        return stored
    }
}