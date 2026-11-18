package com.example.bridge_lab.bridges

import android.os.Handler
import android.os.Looper

/** Events can happen before Dart is listening (app was closed). Buffer them until it does. */
object NotificationEvents {
    private val main = Handler(Looper.getMainLooper())
    private val buffer = mutableListOf<NotificationEvent>()
    private var sender: ((NotificationEvent) -> Unit)? = null

    fun dispatch(event: NotificationEvent) {
        main.post {
            val s = sender
            if (s != null) s(event) else buffer.add(event)
        }
    }

    fun attach(s: (NotificationEvent) -> Unit) {
        sender = s
        buffer.forEach(s)
        buffer.clear()
    }

    fun detach() {
        sender = null
    }
}