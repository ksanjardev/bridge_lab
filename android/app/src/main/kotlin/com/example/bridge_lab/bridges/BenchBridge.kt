package com.example.bridge_lab.bridges

import io.flutter.plugin.common.BasicMessageChannel
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec

/**
 * Do-nothing handlers used only by the Compare page's race. Each one just
 * returns what it receives, so the race measures the cost of crossing the
 * bridge, not the cost of any work behind it.
 */
object BenchBridge {
    fun register(messenger: BinaryMessenger) {
        // MethodChannel: a named method plus an argument.
        MethodChannel(messenger, "bridge_lab/bench").setMethodCallHandler { call, result ->
            if (call.method == "ping") result.success(call.arguments) else result.notImplemented()
        }

        // BasicMessageChannel: no method names, just messages in and replies out.
        BasicMessageChannel(messenger, "bridge_lab/bench_msg", StandardMessageCodec.INSTANCE)
            .setMessageHandler { message, reply -> reply.reply(message) }
    }
}