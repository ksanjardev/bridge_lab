package com.example.bridge_lab.work

import android.content.Context
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import androidx.work.workDataOf
import kotlinx.coroutines.delay
import java.util.concurrent.TimeUnit

class SyncWorker(context: Context, params: WorkerParameters) :
    CoroutineWorker(context, params) {

    companion object {
        const val PREFS = "bridge_lab_sync"
        const val KEY_COUNT = "run_count"
        const val KEY_LAST = "last_run_ms"
    }

    override suspend fun doWork(): Result {
        Log.d("SyncWorker", "sync started")
        delay(3000) // pretend to talk to a server
        val prefs = applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.edit()
            .putInt(KEY_COUNT, prefs.getInt(KEY_COUNT, 0) + 1)
            .putLong(KEY_LAST, System.currentTimeMillis())
            .apply()
        Log.d("SyncWorker", "sync finished")
        val loopSeconds = inputData.getLong("loopSeconds", 0L)
        if (loopSeconds > 0) {
            val next = OneTimeWorkRequestBuilder<SyncWorker>()
                .setInitialDelay(loopSeconds, TimeUnit.SECONDS)
                .setInputData(workDataOf("loopSeconds" to loopSeconds))
                .addTag("loop")
                .build()
            WorkManager.getInstance(applicationContext)
                .enqueueUniqueWork("loop_sync", ExistingWorkPolicy.APPEND_OR_REPLACE, next)
        }
        return Result.success()
    }
}