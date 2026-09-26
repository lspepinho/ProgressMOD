package com.progressmod.ondevice.patch

import java.io.File
import java.util.zip.ZipEntry
import java.util.zip.ZipFile
import java.util.zip.ZipOutputStream














object ApkMerge {

    fun unzip(apk: File, dest: File, log: (String) -> Unit = {}) {
        if (dest.isDirectory) dest.deleteRecursively()
        dest.mkdirs()
        ZipFile(apk).use { z ->
            val entries = z.entries()
            while (entries.hasMoreElements()) {
                val e = entries.nextElement()
                val out = File(dest, e.name)
                if (e.isDirectory) {
                    out.mkdirs()
                } else {
                    out.parentFile?.mkdirs()
                    z.getInputStream(e).use { ins ->
                        out.outputStream().use { ins.copyTo(it) }
                    }
                }
            }
        }
        log("unzip: ${apk.name} -> ${dest.absolutePath}")
    }

    fun mergeSplit(tree: File, splitApk: File, log: (String) -> Unit = {}) {
        ZipFile(splitApk).use { z ->
            val entries = z.entries()
            var n = 0
            while (entries.hasMoreElements()) {
                val e = entries.nextElement()
                if (e.isDirectory) continue
                val name = e.name
                if (name == "AndroidManifest.xml") continue
                if (name.startsWith("META-INF/")) continue
                if (!(name.startsWith("assets/") || name.startsWith("res/") || name.startsWith("lib/"))) continue
                val out = File(tree, name)
                out.parentFile?.mkdirs()
                z.getInputStream(e).use { ins ->
                    out.outputStream().use { ins.copyTo(it) }
                }
                n++
            }
            log("merge split: $n entries from ${splitApk.name}")
        }
    }

    fun repack(tree: File, outApk: File, log: (String) -> Unit = {}) {
        if (outApk.isFile) outApk.delete()
        outApk.parentFile?.mkdirs()
        
        val files = tree.walkTopDown().filter { it.isFile }.toList()
        ZipOutputStream(outApk.outputStream().buffered()).use { out ->
            val sorted = files.sortedBy { it.relativeTo(tree).path.replace(File.separatorChar, '/') }
            for (full in sorted) {
                val arc = full.relativeTo(tree).path.replace(File.separatorChar, '/')
                if (arc.startsWith("META-INF/")) continue
                if (arc.startsWith("original/")) continue
                if (arc.startsWith("assets/") && (arc.endsWith(".lua") || arc.endsWith(".lu"))) continue
                val fname = full.name
                if (fname in setOf("v1_manifest.json")) continue
                if (fname.endsWith(".bak") || fname.endsWith(".log")) continue
                val bytes = full.readBytes()
                val entry = ZipEntry(arc)
                entry.time = 0L 
                val stored = (arc.endsWith(".so") || arc == "resources.arsc")
                if (stored) {
                    
                    val crc = java.util.zip.CRC32()
                    crc.update(bytes)
                    entry.method = ZipEntry.STORED
                    entry.size = bytes.size.toLong()
                    entry.crc = crc.value
                    entry.compressedSize = bytes.size.toLong()
                } else {
                    entry.method = ZipEntry.DEFLATED
                }
                out.putNextEntry(entry)
                out.write(bytes)
                out.closeEntry()
            }
        }
        log("repack: ${outApk.absolutePath} (${outApk.length()} bytes)")
    }
}
