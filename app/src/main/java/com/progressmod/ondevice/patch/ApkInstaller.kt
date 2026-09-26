package com.progressmod.ondevice.patch

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.net.Uri
import android.os.Build
import java.io.File
import kotlinx.coroutines.channels.Channel

object PipelineEvents {
    val installResults = Channel<Pair<Int, String?>>(Channel.BUFFERED)
}

object ApkInstaller {

    const val ACTION_INSTALL_COMMIT = "com.progressmod.ondevice.INSTALL_COMMIT"

    private fun senderFlags(): Int {
        return PendingIntent.FLAG_UPDATE_CURRENT or
            (if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0)
    }

    fun install(context: Context, baseApk: File, splits: List<File>, log: (String) -> Unit) {
        val installer = context.packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
        val sessionId = installer.createSession(params)
        val session = installer.openSession(sessionId)
        session.use {
            baseApk.inputStream().use { input ->
                it.openWrite("base.apk", 0, baseApk.length()).use { output ->
                    input.copyTo(output)
                }
            }
            for (split in splits) {
                split.inputStream().use { input ->
                    it.openWrite(split.name, 0, split.length()).use { output ->
                        input.copyTo(output)
                    }
                }
            }
            val intent = Intent(context, InstallResultReceiver::class.java).apply {
                action = ACTION_INSTALL_COMMIT
            }
            val sender = PendingIntent.getBroadcast(context, sessionId, intent, senderFlags())
            it.commit(sender.intentSender)
        }
        log("Install session $sessionId committed (${splits.size} splits), confirm on screen.")
    }

    fun uninstall(context: Context, pkg: String, log: (String) -> Unit) {
        val intent = Intent(Intent.ACTION_DELETE, Uri.parse("package:$pkg")).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
        log("Opened the system screen to remove $pkg.")
    }
}
