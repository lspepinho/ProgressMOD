package com.progressmod.ondevice.patch

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.os.Build
import android.widget.Toast

class InstallResultReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val status = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, -999)
        val message = intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE)
        if (status == PackageInstaller.STATUS_PENDING_USER_ACTION) {
            val confirm: Intent? = if (Build.VERSION.SDK_INT >= 33) {
                intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(Intent.EXTRA_INTENT)
            }
            if (confirm != null) {
                confirm.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                try {
                    context.startActivity(confirm)
                    Toast.makeText(context, "Confirm the install on screen.", Toast.LENGTH_LONG).show()
                } catch (_: Exception) {
                    PipelineEvents.installResults.trySend(status to message)
                }
            } else {
                PipelineEvents.installResults.trySend(status to message)
            }
            return
        }
        PipelineEvents.installResults.trySend(status to message)
        val text = when (status) {
            PackageInstaller.STATUS_SUCCESS -> "Install finished."
            PackageInstaller.STATUS_FAILURE_CONFLICT ->
                "Signature conflict: remove the original Progressbar95 and try again. ($message)"
            else -> "Install status=$status: $message"
        }
        Toast.makeText(context, text, Toast.LENGTH_LONG).show()
    }
}
