package com.example.bridge_lab.bridges
import androidx.work.workDataOf
import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkQuery
import com.example.bridge_lab.work.SyncWorker
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.TimeUnit

class SyncMethodChannel(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val NAME = "bridge_lab/sync"
        private const val PERIODIC = "periodic_sync"
        private const val ONE_SHOT = "oneshot_sync"
        private const val LOOP = "loop_sync"
    }

    private val workManager get() = WorkManager.getInstance(context)
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "schedulePeriodic" -> {
                val minutes = call.argument<Int>("intervalMinutes")
                if (minutes == null || minutes < 15) {
                    result.error("BAD_ARGS", "intervalMinutes must be >= 15 (WorkManager minimum)", null)
                    return
                }
                val request = PeriodicWorkRequestBuilder<SyncWorker>(minutes.toLong(), TimeUnit.MINUTES)
                    .setConstraints(constraintsFrom(call))
                    .addTag("periodic")
                    .build()
                workManager.enqueueUniquePeriodicWork(PERIODIC, ExistingPeriodicWorkPolicy.UPDATE, request)
                result.success(null)
            }

            "runNow" -> {
                val request = OneTimeWorkRequestBuilder<SyncWorker>().addTag("oneshot").build()
                workManager.enqueueUniqueWork(ONE_SHOT, ExistingWorkPolicy.KEEP, request)
                result.success(null)
            }

            "cancel" -> {
                workManager.cancelUniqueWork(PERIODIC)
                workManager.cancelUniqueWork(ONE_SHOT)
                workManager.cancelUniqueWork(LOOP)
                result.success(null)
            }

            "getStatus" -> {
                val future = workManager.getWorkInfos(
                    WorkQuery.Builder.fromUniqueWorkNames(listOf(PERIODIC, ONE_SHOT, LOOP)).build()
                )
                future.addListener({
                    try {
                        val infos = future.get()
                        fun stateOf(tag: String) =
                            infos.firstOrNull { tag in it.tags }?.state?.name ?: "NOT_SCHEDULED"
                        val prefs = context.getSharedPreferences(SyncWorker.PREFS, Context.MODE_PRIVATE)
                        result.success(
                            mapOf(
                                "periodic" to stateOf("periodic"),
                                "oneShot" to stateOf("oneshot"),
                                "runCount" to prefs.getInt(SyncWorker.KEY_COUNT, 0),
                                "lastRunMs" to prefs.getLong(SyncWorker.KEY_LAST, 0L),
                                "loop" to stateOf("loop"),
                            )
                        )
                    } catch (e: Exception) {
                        result.error("STATUS_FAILED", e.message, null)
                    }
                }, { runnable -> mainHandler.post(runnable) })
            }
            "startLoop" -> {
                val seconds = call.argument<Int>("seconds")
                if (seconds == null || seconds < 5) {
                    result.error("BAD_ARGS", "seconds must be >= 5", null)
                    return
                }
                val request = OneTimeWorkRequestBuilder<SyncWorker>()
                    .setInputData(workDataOf("loopSeconds" to seconds.toLong()))
                    .addTag("loop")
                    .build()
                workManager.enqueueUniqueWork(LOOP, ExistingWorkPolicy.REPLACE, request)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun constraintsFrom(call: MethodCall): Constraints {
        val wifiOnly = call.argument<Boolean>("wifiOnly") ?: false
        val chargingOnly = call.argument<Boolean>("chargingOnly") ?: false
        return Constraints.Builder()
            .setRequiredNetworkType(if (wifiOnly) NetworkType.UNMETERED else NetworkType.CONNECTED)
            .setRequiresCharging(chargingOnly)
            .build()
    }
}