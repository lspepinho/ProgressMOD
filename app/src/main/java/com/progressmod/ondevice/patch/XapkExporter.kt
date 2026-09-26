package com.progressmod.ondevice.patch

import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.os.Build
import java.io.File
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

object XapkExporter {

    data class AppMeta(
        val packageName: String,
        val label: String,
        val versionCode: Long,
        val versionName: String,
        val minSdk: Int,
        val targetSdk: Int
    )

    fun readMeta(ctx: Context, apk: File, fallbackPkg: String): AppMeta {
        val pm = ctx.packageManager
        val info = pm.getPackageArchiveInfo(apk.absolutePath, PackageManager.GET_META_DATA)
        val pkg = info?.packageName ?: fallbackPkg
        val versionName = info?.versionName ?: "1.0"
        val versionCode: Long = if (info != null && Build.VERSION.SDK_INT >= 28) {
            info.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            (info?.versionCode ?: 1).toLong()
        }
        var label = pkg
        var minSdk = 26
        var targetSdk = 34
        try {
            if (info?.applicationInfo != null) {
                info.applicationInfo.sourceDir = apk.absolutePath
                info.applicationInfo.publicSourceDir = apk.absolutePath
                label = pm.getApplicationLabel(info.applicationInfo)?.toString() ?: pkg
                if (Build.VERSION.SDK_INT >= 24) {
                    minSdk = info.applicationInfo.minSdkVersion
                }
                targetSdk = info.applicationInfo.targetSdkVersion
            }
        } catch (_: Exception) {
        }
        return AppMeta(pkg, label, versionCode, versionName, minSdk, targetSdk)
    }

    private fun esc(s: String): String =
        s.replace("\\", "\\\\").replace("\"", "\\\"")

    fun buildManifestJson(meta: AppMeta, baseFileName: String, splits: List<File>): String {
        val sb = StringBuilder()
        sb.append("{\n")
        sb.append("  \"xapk_version\": 2,\n")
        sb.append("  \"package_name\": \"${esc(meta.packageName)}\",\n")
        sb.append("  \"name\": \"${esc(meta.label)}\",\n")
        sb.append("  \"version_code\": ${meta.versionCode},\n")
        sb.append("  \"version_name\": \"${esc(meta.versionName)}\",\n")
        sb.append("  \"min_sdk_version\": ${meta.minSdk},\n")
        sb.append("  \"target_sdk_version\": ${meta.targetSdk},\n")
        sb.append("  \"split_apks\": [\n")
        sb.append("    {\"id\": \"base\", \"file\": \"${esc(baseFileName)}\"}")
        for (sp in splits) {
            val id = sp.name.removeSuffix(".apk")
            sb.append(",\n    {\"id\": \"${esc(id)}\", \"file\": \"${esc(sp.name)}\"}")
        }
        sb.append("\n  ],\n")
        sb.append("  \"expansions\": []\n")
        sb.append("}\n")
        return sb.toString()
    }

    private fun extractIconPng(ctx: Context, apk: File): ByteArray? {
        return try {
            val pm = ctx.packageManager
            val info = pm.getPackageArchiveInfo(apk.absolutePath, 0) ?: return null
            info.applicationInfo.sourceDir = apk.absolutePath
            info.applicationInfo.publicSourceDir = apk.absolutePath
            val d = pm.getApplicationIcon(info.applicationInfo) ?: return null
            val size = maxOf(d.intrinsicWidth.takeIf { it > 0 } ?: 192, 192)
            val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val canvas = android.graphics.Canvas(bmp)
            d.setBounds(0, 0, size, size)
            d.draw(canvas)
            val out = java.io.ByteArrayOutputStream()
            bmp.compress(Bitmap.CompressFormat.PNG, 100, out)
            bmp.recycle()
            out.toByteArray()
        } catch (_: Exception) {
            null
        }
    }

    fun build(
        ctx: Context,
        signedBase: File,
        signedSplits: List<File>,
        fallbackPkg: String,
        outXapk: File,
        log: (String) -> Unit = {}
    ): File {
        require(signedBase.isFile) { "signed base missing: ${signedBase.absolutePath}" }
        val meta = readMeta(ctx, signedBase, fallbackPkg)
        val manifest = buildManifestJson(meta, "base.apk", signedSplits)
        if (outXapk.isFile) outXapk.delete()
        outXapk.parentFile?.mkdirs()
        ZipOutputStream(outXapk.outputStream().buffered()).use { out ->
            fun entry(name: String, bytes: ByteArray) {
                val e = ZipEntry(name)
                e.time = 0L
                e.method = ZipEntry.DEFLATED
                out.putNextEntry(e)
                out.write(bytes)
                out.closeEntry()
            }
            entry("manifest.json", manifest.toByteArray(Charsets.UTF_8))
            signedBase.inputStream().use { ins ->
                val e = ZipEntry("base.apk")
                e.time = 0L
                e.method = ZipEntry.DEFLATED
                out.putNextEntry(e)
                ins.copyTo(out)
                out.closeEntry()
            }
            for (sp in signedSplits.sortedBy { it.name }) {
                sp.inputStream().use { ins ->
                    val e = ZipEntry(sp.name)
                    e.time = 0L
                    e.method = ZipEntry.DEFLATED
                    out.putNextEntry(e)
                    ins.copyTo(out)
                    out.closeEntry()
                }
            }
            val icon = extractIconPng(ctx, signedBase)
            if (icon != null) entry("icon.png", icon)
        }
        log("xapk: ${outXapk.name} (${outXapk.length()} bytes, base + ${signedSplits.size} splits, ${meta.packageName} v${meta.versionName}/${meta.versionCode})")
        return outXapk
    }
}
