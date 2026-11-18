package com.example.bridge_lab.bridges

import android.content.Context
import android.util.Log
import io.flutter.plugin.common.BasicMessageChannel
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.JSONMessageCodec
import org.json.JSONObject

class ShareBridge(messenger: BinaryMessenger, private val context: Context) {

    companion object {
        const val NAME = "bridge_lab/share"
        private const val TAG = "ShareBridge"
    }

    private val channel = BasicMessageChannel<Any?>(messenger, NAME, JSONMessageCodec.INSTANCE)

    init {
        channel.setMessageHandler { message, reply ->
            val type = (message as? JSONObject)?.optString("type")
            if (type == "ready") {
                // Dart is listening: push future shares live, and hand over the saved ones.
                ShareStore.listener = { item -> push(item) }
                reply.reply(JSONObject().put("pending", ShareStore.drain(context)))
            } else {
                reply.reply(JSONObject().put("error", "unknown message type: $type"))
            }
        }
    }

    private fun push(item: JSONObject) {
        channel.send(item) { ack ->
            if (ack == null) {
                // Nobody answered (for example Dart restarted). Keep it for the next "ready".
                Log.d(TAG, "No reply from Dart, keeping item")
                ShareStore.persist(context, item)
            } else {
                Log.d(TAG, "Dart replied: ${(ack as? JSONObject)?.optString("status")}")
            }
        }
    }

    fun detach() {
        ShareStore.listener = null
        channel.setMessageHandler(null)
    }
}