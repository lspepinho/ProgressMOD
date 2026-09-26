package com.progressmod.ondevice

import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageInstaller
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.view.View
import android.widget.Button
import android.widget.EditText
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.activity.result.contract.ActivityResultContracts
import androidx.lifecycle.lifecycleScope
import com.google.android.material.appbar.MaterialToolbar
import com.google.android.material.progressindicator.LinearProgressIndicator
import com.progressmod.ondevice.patch.ApkInstaller
import com.progressmod.ondevice.patch.ApkMerge
import com.progressmod.ondevice.patch.ApkPatcher
import com.progressmod.ondevice.patch.ApkSignerOnDevice
import com.progressmod.ondevice.patch.PipelineEvents
import com.progressmod.ondevice.patch.XapkExporter
import java.io.File
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity : AppCompatActivity() {

    private lateinit var statusView: TextView
    private lateinit var packageInput: EditText
    private lateinit var autoButton: Button
    private lateinit var revertButton: Button
    private lateinit var progressBar: LinearProgressIndicator
    private lateinit var stepViews: Map<TextView, String>

    private var baseApk: File? = null
    private var splitApk: File? = null
    private var isRunning = false
    private var pendingXapk: File? = null

    private val createXapkDocument =
        registerForActivityResult(ActivityResultContracts.CreateDocument("application/octet-stream")) { uri ->
            val src = pendingXapk
            if (uri == null) {
                log("XAPK: save cancelled.")
                return@registerForActivityResult
            }
            if (src == null || !src.isFile) {
                log("ERROR: temp XAPK file missing.")
                return@registerForActivityResult
            }
            try {
                contentResolver.openOutputStream(uri)?.use { out ->
                    src.inputStream().use { it.copyTo(out) }
                }
                log("XAPK saved. Install with SAI / APKPure Installer.")
            } catch (e: Exception) {
                log("ERROR saving XAPK: ${e.message}")
            } finally {
                pendingXapk = null
            }
        }

    private fun workDir(): File = File(filesDir, "work").apply { mkdirs() }
    private fun treeDir(): File = File(workDir(), "tree")
    private fun assetsWorkDir(): File = File(treeDir(), "assets").let { if (it.isDirectory) it else treeDir() }
    private fun manifestFile(): File = File(workDir(), "apk_manifest.json")
    private fun unsignedApk(): File = File(workDir(), "game-mod-unsigned.apk")
    private fun signedApk(): File = File(workDir(), "game-mod.apk")

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        statusView = findViewById(R.id.tvStatus)
        packageInput = findViewById(R.id.etPackage)
        autoButton = findViewById(R.id.btnAuto)
        revertButton = findViewById(R.id.btnRevert)
        progressBar = findViewById(R.id.progress)
        val toolbar = findViewById<MaterialToolbar>(R.id.toolbar)
        toolbar.inflateMenu(R.menu.main_menu)
        toolbar.setOnMenuItemClickListener { item ->
            when (item.itemId) {
                R.id.action_save_xapk -> {
                    runSaveXapk()
                    true
                }
                else -> false
            }
        }
        stepViews = mapOf(
            findViewById<TextView>(R.id.stepPatch) to "Patch",
            findViewById<TextView>(R.id.stepBuild) to "Rebuild",
            findViewById<TextView>(R.id.stepUninstall) to "Uninstall",
            findViewById<TextView>(R.id.stepInstall) to "Install"
        )
        autoButton.setOnClickListener { runPipeline() }
        revertButton.setOnClickListener { runRevert() }
        val savedBase = File(workDir(), "game.apk")
        if (savedBase.isFile) baseApk = savedBase
        val savedSplit = File(workDir(), "split_assets.apk")
        if (savedSplit.isFile) splitApk = savedSplit
        refreshButtons()
    }

    override fun onResume() {
        super.onResume()
        refreshButtons()
    }

    private fun log(message: String) {
        android.util.Log.d("ProgressMOD", message)
        runOnUiThread {
            statusView.text = "Status: $message"
        }
    }

    private fun setStep(id: Int, state: Int) {
        runOnUiThread {
            val view = findViewById<TextView>(id)
            val label = stepViews[stepViews.keys.first { it.id == id }] ?: ""
            view.text = glyph(state) + " " + label
        }
    }

    private fun glyph(state: Int): String {
        return when (state) {
            1 -> "◉"
            2 -> "✓"
            3 -> "✗"
            else -> "○"
        }
    }

    private fun isPatched(): Boolean {
        val assets = assetsWorkDir()
        return manifestFile().isFile &&
            File(assets, "main.lua").isFile &&
            File(assets, "patched_main.lu").isFile
    }

    private fun refreshButtons() {
        runOnUiThread {
            val patched = isPatched()
            autoButton.isEnabled = !isRunning && !patched
            revertButton.isEnabled = !isRunning && patched
        }
    }

    private fun isInstalled(pkg: String): Boolean {
        return try {
            packageManager.getApplicationInfo(pkg, 0)
            true
        } catch (_: PackageManager.NameNotFoundException) {
            false
        }
    }

    private fun isOurModInstalled(pkg: String): Boolean {
        try {
            val info = if (Build.VERSION.SDK_INT >= 28) {
                packageManager.getPackageInfo(pkg, PackageManager.GET_SIGNING_CERTIFICATES)
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(pkg, PackageManager.GET_SIGNATURES)
            }
            val installed = if (Build.VERSION.SDK_INT >= 28) {
                val signing = info.signingInfo
                if (signing.hasMultipleSigners()) signing.apkContentsSigners else signing.signingCertificateHistory
            } else {
                @Suppress("DEPRECATION")
                info.signatures
            }
            if (installed.isNullOrEmpty()) return false
            val ours = ApkSignerOnDevice.getOrCreateKey(filesDir).certs.firstOrNull()?.encoded ?: return false
            return installed.any { it.toByteArray().contentEquals(ours) }
        } catch (_: Exception) {
            return false
        }
    }

    private fun openStore(pkg: String) {
        val market = Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$pkg")).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        try {
            startActivity(market)
        } catch (_: Exception) {
            val web = Intent(Intent.ACTION_VIEW, Uri.parse("https://play.google.com/store/apps/details?id=$pkg")).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            try {
                startActivity(web)
            } catch (_: Exception) {
                log("ERROR: could not open the store.")
            }
        }
    }

    private fun detectIntoWork(pkg: String): Boolean {
        val info: ApplicationInfo = try {
            packageManager.getApplicationInfo(pkg, 0)
        } catch (_: PackageManager.NameNotFoundException) {
            log("ERROR: $pkg is not installed.")
            return false
        }
        val base = File(workDir(), "game.apk")
        File(info.sourceDir).copyTo(base, overwrite = true)
        baseApk = base
        log("Detect: base APK ${base.length()} bytes from $pkg")
        val splits = info.splitSourceDirs?.toList() ?: emptyList()
        var found: File? = null
        for (path in splits) {
            val file = File(path)
            if (file.name.contains("config.", ignoreCase = true)) continue
            if (found == null || file.length() > found.length()) found = file
        }
        if (found == null) {
            for (path in splits) {
                val file = File(path)
                if (file.length() > 10_000_000) {
                    found = file
                    break
                }
            }
        }
        if (found != null) {
            val split = File(workDir(), "split_assets.apk")
            found.copyTo(split, overwrite = true)
            splitApk = split
            log("Detect: assets split ${split.length()} bytes (${found.name})")
        } else {
            log("Detect: no split found (splits=${splits.size}), continuing with base only.")
        }
        for (old in workDir().listFiles() ?: emptyArray()) {
            if (old.isFile && old.name.startsWith("split_config") && old.name.endsWith(".apk")) old.delete()
        }
        var configs = 0
        for (path in splits) {
            val file = File(path)
            if (!file.name.contains("config.", ignoreCase = true)) continue
            file.copyTo(File(workDir(), file.name), overwrite = true)
            configs++
        }
        log("Detect: $configs config splits copied.")
        return true
    }

    private fun patchWork(): Boolean {
        val base = baseApk?.takeIf { it.isFile } ?: File(workDir(), "game.apk").takeIf { it.isFile }
        if (base == null) {
            log("ERROR: base APK is missing.")
            return false
        }
        baseApk = base
        ApkMerge.unzip(base, treeDir()) { log(it) }
        val split = splitApk?.takeIf { it.isFile }
            ?: File(workDir(), "split_assets.apk").takeIf { it.isFile }
        if (split != null) {
            splitApk = split
            ApkMerge.mergeSplit(treeDir(), split) { log(it) }
        }
        val assets = assetsWorkDir()
        for (line in ApkPatcher.discover(assets)) log(line)
        val result = ApkPatcher.patchTree(this, treeDir(), manifestFile()) { log(it) }
        if (result.startsWith("ERROR")) log(result)
        return !result.startsWith("ERROR")
    }

    private fun buildWork(): Boolean {
        if (!treeDir().isDirectory) {
            log("ERROR: run the patch step first.")
            return false
        }
        ApkMerge.repack(treeDir(), unsignedApk()) { log(it) }
        ApkSignerOnDevice.sign(unsignedApk(), signedApk(), filesDir) { log(it) }
        log("Build done: ${signedApk().absolutePath}")
        return true
    }

    private fun signedSplitsForXapk(): List<File> {
        val rawSplits = (workDir().listFiles() ?: emptyArray())
            .filter { it.isFile && it.name.startsWith("split_config") && it.name.endsWith(".apk") }
            .sortedBy { it.name }
        if (rawSplits.isEmpty()) return emptyList()
        val signedDir = File(workDir(), "signed")
        val out = ArrayList<File>()
        for (raw in rawSplits) {
            out.add(ApkSignerOnDevice.resignSplit(raw, signedDir, filesDir) { log(it) })
        }
        return out
    }

    private fun xapkTempFile(pkg: String): File {
        val safe = pkg.ifBlank { "game-mod" }.replace(Regex("[^A-Za-z0-9._-]+"), "_")
        return File(cacheDir, "$safe-mod.xapk")
    }

    private fun runSaveXapk() {
        if (isRunning) return
        isRunning = true
        refreshButtons()
        runOnUiThread { progressBar.visibility = View.VISIBLE }
        lifecycleScope.launch(Dispatchers.IO) {
            try {
                val pkg = withContext(Dispatchers.Main) { packageInput.text.toString().trim() }
                    .ifBlank { "com.spookyhousestudios.progressbar95" }
                val base = baseApk?.takeIf { it.isFile }
                    ?: File(workDir(), "game.apk").takeIf { it.isFile }
                if (base == null) {
                    if (!detectIntoWork(pkg)) {
                        log("ERROR: base APK missing. Install the game from Play first.")
                        return@launch
                    }
                }
                if (!isPatched()) {
                    setStep(R.id.stepPatch, 1)
                    if (!patchWork()) {
                        setStep(R.id.stepPatch, 3)
                        return@launch
                    }
                    setStep(R.id.stepPatch, 2)
                } else {
                    setStep(R.id.stepPatch, 2)
                }
                setStep(R.id.stepBuild, 1)
                if (!signedApk().isFile) {
                    if (!buildWork()) {
                        setStep(R.id.stepBuild, 3)
                        return@launch
                    }
                }
                setStep(R.id.stepBuild, 2)
                val splits = try {
                    signedSplitsForXapk()
                } catch (e: Exception) {
                    log("ERROR signing splits: ${e.message}")
                    return@launch
                }
                val tmp = xapkTempFile(pkg)
                try {
                    XapkExporter.build(this@MainActivity, signedApk(), splits, pkg, tmp) { log(it) }
                } catch (e: Exception) {
                    log("ERROR building XAPK: ${e.message}")
                    return@launch
                }
                pendingXapk = tmp
                withContext(Dispatchers.Main) {
                    try {
                        createXapkDocument.launch(tmp.name)
                    } catch (e: Exception) {
                        log("ERROR opening save dialog: ${e.message}")
                    }
                }
            } catch (e: Exception) {
                log("ERROR: ${e.message}")
            } finally {
                isRunning = false
                setBusy(false)
            }
        }
    }

    private fun clearPatchedState() {
        treeDir().deleteRecursively()
        manifestFile().delete()
        unsignedApk().delete()
        signedApk().delete()
        File(workDir(), "signed").deleteRecursively()
    }

    private fun drainInstall() {
        while (PipelineEvents.installResults.tryReceive().isSuccess) {
        }
    }

    private suspend fun waitUntilGone(pkg: String, timeoutMs: Long): Boolean {
        val start = SystemClock.uptimeMillis()
        while (SystemClock.uptimeMillis() - start < timeoutMs) {
            if (!isInstalled(pkg)) return true
            delay(2000)
        }
        return !isInstalled(pkg)
    }

    private suspend fun waitForInstall(pkg: String, timeoutMs: Long): Pair<Int, String?> {
        val start = SystemClock.uptimeMillis()
        while (SystemClock.uptimeMillis() - start < timeoutMs) {
            val announced = PipelineEvents.installResults.tryReceive().getOrNull()
            if (announced != null) return announced
            if (isOurModInstalled(pkg)) return PackageInstaller.STATUS_SUCCESS to null
            delay(2000)
        }
        val announced = PipelineEvents.installResults.tryReceive().getOrNull()
        if (announced != null) return announced
        if (isOurModInstalled(pkg)) return PackageInstaller.STATUS_SUCCESS to null
        return -1 to "timed out"
    }

    private fun setBusy(busy: Boolean) {
        runOnUiThread {
            progressBar.visibility = if (busy) View.VISIBLE else View.GONE
        refreshButtons()
        if (intent?.action == "com.progressmod.ondevice.AUTO_PIPELINE") {
            lifecycleScope.launch(Dispatchers.IO) {
                kotlinx.coroutines.delay(1500)
                clearPatchedState()
                runPipeline()
            }
        }
    }
    }

    private fun runPipeline() {
        if (isRunning) return
        isRunning = true
        refreshButtons()
        runOnUiThread { progressBar.visibility = View.VISIBLE }
        lifecycleScope.launch(Dispatchers.IO) {
            try {
                val pkg = withContext(Dispatchers.Main) { packageInput.text.toString().trim() }
                if (!detectIntoWork(pkg)) {
                    setStep(R.id.stepPatch, 3)
                    return@launch
                }
                setStep(R.id.stepPatch, 1)
                if (!patchWork()) {
                    setStep(R.id.stepPatch, 3)
                    return@launch
                }
                setStep(R.id.stepPatch, 2)
                setStep(R.id.stepBuild, 1)
                if (!buildWork()) {
                    setStep(R.id.stepBuild, 3)
                    return@launch
                }
                setStep(R.id.stepBuild, 2)
                setStep(R.id.stepUninstall, 1)
                if (isInstalled(pkg)) {
                    withContext(Dispatchers.Main) {
                        ApkInstaller.uninstall(this@MainActivity, pkg) { log(it) }
                    }
                    log("Waiting for uninstall confirmation on screen...")
                    if (!waitUntilGone(pkg, 180_000)) {
                        setStep(R.id.stepUninstall, 3)
                        log("ERROR: game is still installed.")
                        return@launch
                    }
                } else {
                    log("Original is not installed, skipping removal.")
                }
                setStep(R.id.stepUninstall, 2)
                setStep(R.id.stepInstall, 1)
                val apk = signedApk()
                if (!apk.isFile) {
                    setStep(R.id.stepInstall, 3)
                    log("ERROR: game-mod.apk is missing.")
                    return@launch
                }
                drainInstall()
                val rawSplits = (workDir().listFiles() ?: emptyArray())
                    .filter { it.isFile && it.name.startsWith("split_config") && it.name.endsWith(".apk") }
                    .sortedBy { it.name }
                if (rawSplits.isEmpty()) {
                    log("WARNING: no config splits found, install may fail.")
                }
                val signedDir = File(workDir(), "signed")
                val configSplits = ArrayList<File>()
                var splitsOk = true
                for (raw in rawSplits) {
                    try {
                        configSplits.add(ApkSignerOnDevice.resignSplit(raw, signedDir, filesDir) { log(it) })
                    } catch (e: Exception) {
                        log("ERROR signing split ${raw.name}: ${e.message}")
                        splitsOk = false
                        break
                    }
                }
                if (!splitsOk) {
                    setStep(R.id.stepInstall, 3)
                    return@launch
                }
                withContext(Dispatchers.Main) {
                    ApkInstaller.install(this@MainActivity, apk, configSplits) { log(it) }
                }
                log("Waiting for install confirmation on screen...")
                val result = waitForInstall(pkg, 180_000)
                if (result.first == PackageInstaller.STATUS_SUCCESS) {
                    setStep(R.id.stepInstall, 2)
                    log("Done: mod installed.")
                } else {
                    setStep(R.id.stepInstall, 3)
                    log("ERROR: install returned status=${result.first}: ${result.second}")
                }
            } catch (e: Exception) {
                log("ERROR: ${e.message}")
            } finally {
                isRunning = false
                setBusy(false)
            }
        }
    }

    private fun runRevert() {
        if (isRunning) return
        isRunning = true
        refreshButtons()
        runOnUiThread { progressBar.visibility = View.VISIBLE }
        lifecycleScope.launch(Dispatchers.IO) {
            try {
                val pkg = withContext(Dispatchers.Main) { packageInput.text.toString().trim() }
                setStep(R.id.stepUninstall, 1)
                if (isInstalled(pkg)) {
                    if (isOurModInstalled(pkg)) {
                        withContext(Dispatchers.Main) {
                            ApkInstaller.uninstall(this@MainActivity, pkg) { log(it) }
                        }
                        log("Waiting for uninstall confirmation on screen...")
                        if (!waitUntilGone(pkg, 180_000)) {
                            setStep(R.id.stepUninstall, 3)
                            log("ERROR: game is still installed.")
                            return@launch
                        }
                        setStep(R.id.stepUninstall, 2)
                    } else {
                        log("Installed app is not the mod, keeping it installed.")
                        setStep(R.id.stepUninstall, 2)
                    }
                } else {
                    log("Game is not installed, nothing to remove.")
                    setStep(R.id.stepUninstall, 2)
                }
                clearPatchedState()
                log("Reverted: local mod files cleared.")
                withContext(Dispatchers.Main) {
                    openStore(pkg)
                }
            } catch (e: Exception) {
                log("ERROR: ${e.message}")
            } finally {
                isRunning = false
                setBusy(false)
            }
        }
    }
}
