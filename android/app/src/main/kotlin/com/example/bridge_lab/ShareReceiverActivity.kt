package com.example.bridge_lab

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.OpenableColumns
import android.util.Log
import android.widget.Toast
import com.example.bridge_lab.bridges.ShareStore
import org.json.JSONObject
import java.io.File
import java.util.concurrent.Executors

/** No Flutter here: save the share natively and get out of the user's way. */
class ShareReceiverActivity : Activity() {

    private val tag = "ShareReceiver"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val intent = intent
        val ok = intent?.action == Intent.ACTION_SEND || intent?.action == Intent.ACTION_SEND_MULTIPLE
        if (savedInstanceState != null || !ok) {
            finish()
            return
        }

        val text = intent.getStringExtra(Intent.EXTRA_TEXT)
        val subject = intent.getStringExtra(Intent.EXTRA_SUBJECT)
        val uris = streamUris(intent)

        val io = Executors.newSingleThreadExecutor()
        io.execute {
            val items = mutableListOf<JSONObject>()
            if (text != null && uris.isEmpty()) items += textItem(text, subject)
            uris.forEach { copyToCache(it)?.let { item -> items += item } }

            runOnUiThread {
                items.forEach { ShareStore.add(applicationContext, it) }
                val msg = if (items.isEmpty()) "Could not save" else "Saved to Bridge Lab"
                Toast.makeText(applicationContext, msg, Toast.LENGTH_SHORT).show()
                // Finish only after copying: the URI permission lives as long as this activity.
                startActivity(
                    Intent(this, MainActivity::class.java)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                )
                finish()
            }
        }
        io.shutdown() // lets the queued task finish, then frees the thread
    }

    private fun textItem(text: String, subject: String?) = JSONObject()
        .put("kind", "text")
        .put("text", text)
        .put("subject", subject ?: JSONObject.NULL)
        .put("receivedAtMs", System.currentTimeMillis())

    private fun copyToCache(uri: Uri): JSONObject? = try {
        var name = "shared_file"
        contentResolver.query(uri, null, null, null, null)?.use { c ->
            if (c.moveToFirst()) {
                val i = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (i >= 0) c.getString(i)?.let { name = it }
            }
        }
        val dir = File(cacheDir, "shared").apply { mkdirs() }
        val target = File(dir, "${System.currentTimeMillis()}_${name.replace('/', '_')}")
        contentResolver.openInputStream(uri)!!.use { input ->
            target.outputStream().use { out -> input.copyTo(out) }
        }
        val mime = contentResolver.getType(uri) ?: "application/octet-stream"
        JSONObject()
            .put("kind", if (mime.startsWith("image/")) "image" else "file")
            .put("name", name)
            .put("path", target.absolutePath)
            .put("mimeType", mime)
            .put("sizeBytes", target.length())
            .put("receivedAtMs", System.currentTimeMillis())
    } catch (e: Exception) {
        Log.e(tag, "Could not copy $uri", e)
        null
    }

    @Suppress("DEPRECATION")
    private fun streamUris(intent: Intent): List<Uri> {
        return if (intent.action == Intent.ACTION_SEND_MULTIPLE) {
            (if (Build.VERSION.SDK_INT >= 33)
                intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
            else intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)) ?: emptyList()
        } else {
            val uri = if (Build.VERSION.SDK_INT >= 33)
                intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            else intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
            listOfNotNull(uri)
        }
    }
}