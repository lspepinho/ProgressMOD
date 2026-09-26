package com.progressmod.ondevice.patch

import android.content.Context
import java.io.File










object ApkPatcher {

    const val MOD_ID = "alpha-pibe-quark-v29"
    val LOADER_FILES = listOf(
        "main.lua", "config.lua",
        "alpha_rules.lua", "alpha_board.lua", "alpha_hud.lua",
        "alpha_end.lua", "alpha_flow.lua", "pibe_quark.lua",
        "mod_defender_firewall.lua"
    )
    val CAR_LU = listOf(
        "bit8help.lu", "inet.lu", "leveldata.lu",
        "plugin_apple_iap.lu", "plugin_applovinMax.lu", "plugin_att.lu",
        "plugin_google_iap_billing_v2.lu", "plugin_google_iap_v3.lu",
        "plugin_gpgs_v3.lu", "plugin_icloud.lu",
        "plugin_notifications_v2.lu"
    )
    val LANGS = listOf("de", "en", "es", "fr", "it", "ja", "pl", "pt", "ro", "ru", "tr", "ua")
    const val ORIG_MAIN = "orig_main.lu"
    const val PATCHED_MAIN = "patched_main.lu"
    const val MANIFEST_NAME = "v1_manifest.json"
    const val PROGRESS_MAP = "Progress Map"

    data class PatchResult(val ok: Boolean, val log: String)

    fun discover(assetsDir: File, log: (String) -> Unit = {}): List<String> {
        val res = ArrayList<String>()
        val car = File(assetsDir, "resource.car")
        if (!car.isFile) {
            res.add("resource.car MISSING in ${assetsDir.absolutePath}")
            return res
        }
        try {
            val names = CarFile.verify(car)
            res.add("car: OK (${names.size} entries)")
        } catch (e: Exception) {
            res.add("car: FAIL (${e.message})")
            return res
        }
        val nstr = LANGS.count { File(assetsDir, "international/$it/strings.xml").isFile }
        res.add("strings: $nstr/12")
        var ni = 0
        var nt = 0
        File(assetsDir, "art").walkTopDown().forEach {
            if (it.isFile) {
                if (it.name == "ico32_gamemode_alphabeth.png") ni++
                else if (it.name == "ico_progressmap.png") nt++
            }
        }
        res.add("icons: mode=$ni title=$nt")
        try {
            val mb = CarFile.extract(car, "main.lu")
            res.add("main.lu: ${mb.size} bytes")
        } catch (e: Exception) {
            res.add("main.lu: MISSING (${e.message})")
        }
        res.forEach(log)
        return res
    }

    
    fun patchTree(ctx: Context, treeDir: File, manifestFile: File, log: (String) -> Unit): String {
        val assets = File(treeDir, "assets").let { if (it.isDirectory) it else treeDir }
        val car = File(assets, "resource.car")
        if (!car.isFile) return "ERROR: resource.car not found in ${car.absolutePath}"
        val manPath = manifestFile.absolutePath
        if (File(assets, "main.lua").isFile && !manifestFile.isFile) {
            return "ERROR: foreign main.lua already exists (no manifest). Clear work dir to force."
        }
        var carHashBefore = CarFile.sha256Hex(car)
        val names = try {
            CarFile.verify(car)
        } catch (e: Exception) {
            return "ERROR: car verify failed (${e.message})"
        }
        log("car: OK (${names.size} entries, sha ${carHashBefore.take(12)}...) intact")

        val mainBytes = try {
            CarFile.extract(car, "main.lu")
        } catch (e: Exception) {
            return "ERROR: main.lu missing (${e.message})"
        }
        require(mainBytes.size >= 4 && mainBytes[0] == 0x1B.toByte()) { "extracted main.lu without Lua header" }
        File(assets, ORIG_MAIN).writeBytes(mainBytes)

        val patched = try {
            LuaPatch.buildPatchedMain(mainBytes)
        } catch (e: Exception) {
            android.util.Log.e("ProgressMOD", "surgery failed", e)
            File(assets, PATCHED_MAIN).delete()
            return "ERROR in bytecode surgery: ${e.javaClass.simpleName} ${e.message} (nothing installed; game intact)"
        }
        File(assets, PATCHED_MAIN).writeBytes(patched.bytes)
        log("bytecode: patched (+63 code, alphabeth const, winicon) p24=${patched.p24Lines}")
        val bootEntries = LinkedHashMap<String, ByteArray>()
        for (name in listOf("pmod_boot", "alpha_rules", "alpha_board", "alpha_hud", "alpha_end", "alpha_flow", "pibe_quark", "mod_defender_firewall")) {
            try {
                ctx.assets.open("payload/luaboot/$name.lu").use { bootEntries["$name.lu"] = it.readBytes() }
            } catch (e: Exception) {
                return "ERROR: payload/luaboot/$name.lu missing (${e.message})"
            }
        }
        bootEntries["pmod_game.lu"] = patched.bytes
        val mainEntry = bootEntries.remove("pmod_boot.lu")!!
        val rebuilt = try {
            CarFile.rebuildCar(car.readBytes(), mapOf("main.lu" to mainEntry), bootEntries)
        } catch (e: Exception) {
            android.util.Log.e("ProgressMOD", "car rebuild failed", e)
            return "ERROR rebuilding resource.car: ${e.javaClass.simpleName} ${e.message}"
        }
        car.writeBytes(rebuilt)
        carHashBefore = CarFile.sha256Hex(car)
        log("car: rebuilt with boot entries (main.lu + ${bootEntries.size} modules, car ${rebuilt.size} bytes)")

        
        val am = ctx.assets
        val installed = LinkedHashMap<String, String>()
        for (fn in LOADER_FILES) {
            try {
                am.open("payload/$fn").use { ins ->
                    File(assets, fn).outputStream().use { ins.copyTo(it) }
                }
                installed[fn] = CarFile.sha256Hex(File(assets, fn))
            } catch (e: Exception) {
                return "ERROR: payload/$fn missing in app assets (${e.message})"
            }
        }
        log("loader installed (${LOADER_FILES.joinToString(", ")})")

        
        val carLu = LinkedHashMap<String, String>()
        val skippedLu = ArrayList<String>()
        for (fn in CAR_LU) {
            try {
                val data = CarFile.extract(car, fn)
                File(assets, fn).writeBytes(data)
                carLu[fn] = CarFile.sha256Hex(File(assets, fn))
            } catch (_: Exception) {
                skippedLu.add(fn)
            }
        }
        if (skippedLu.isNotEmpty()) log("car_lu skipped (not in car): ${skippedLu.joinToString(",")}")

        
        val artIcons = LinkedHashMap<String, String>()
        val artList = am.list("payload/art")?.toList() ?: emptyList()
        if (artList.isEmpty()) {
            
            for (top in listOf("payload/art/assets", "payload/art/skins")) {
                copyAssetDir(am, top, File(assets, "art"), artIcons, assets)
            }
        } else {
            copyAssetDir(am, "payload/art", File(assets, "art"), artIcons, assets)
        }
        log("art: ${artIcons.size} icons")
        File(assets, "art/skins").listFiles()?.forEach { dir ->
            if (dir.isDirectory) {
                for (fn in listOf("pibe_banner.png", "quark_banner.png")) {
                    val stale = File(dir, fn)
                    if (stale.isFile) stale.delete()
                }
            }
        }
        val navIcons = mapOf(
            "ico32_gamemode_Pibe.png" to "payload/art/skins/95/ico32_gamemode_Pibe.png",
            "ico32_gamemode_Quark.png" to "payload/art/skins/95/ico32_gamemode_Quark.png",
            "ico32_gamemode_Back.png" to "payload/art/skins/95/ico32_gamemode_Back.png"
        )
        var nn = 0
        File(assets, "art/skins").listFiles()?.forEach { dir ->
            if (dir.isDirectory) {
                for ((dst, asset) in navIcons) {
                    try {
                        am.open(asset).use { ins ->
                            File(dir, dst).outputStream().use { ins.copyTo(it) }
                        }
                        nn++
                    } catch (_: Exception) { }
                }
            }
        }
        log("nav icons: $nn files force-copied")
        var nf = 0
        val donor95 = File(assets, "art/skins/95")
        if (donor95.isDirectory) {
            val donorFiles = donor95.listFiles()
                ?.filter { it.isFile && it.name.startsWith("ico32_gamemode_") }
                ?: emptyList()
            val artRoots = ArrayList<File>()
            File(assets, "art/skins").listFiles()?.forEach { if (it.isDirectory) artRoots.add(it) }
            val assetsDir = File(assets, "art/assets")
            if (assetsDir.isDirectory) {
                assetsDir.listFiles()?.forEach { if (it.isDirectory) artRoots.add(it) }
            }
            for (dir in artRoots) {
                for (src in donorFiles) {
                    val dst = File(dir, src.name)
                    if (!dst.isFile) {
                        try {
                            src.copyTo(dst)
                            nf++
                        } catch (_: Exception) { }
                    }
                }
            }
        }
        log("icon fallback: $nf files copied from 95")

        
        val stringsRes = LinkedHashMap<String, String>()
        val stringsHash = LinkedHashMap<String, String>()
        for (lang in LANGS) {
            val sp = File(assets, "international/$lang/strings.xml")
            if (!sp.isFile) {
                stringsRes[lang] = "ERROR: file missing"
                continue
            }
            val bak = File(sp.absolutePath + ".bak")
            val raw = sp.readBytes()
            val want = ("<t name='GameModealphabeth'>$PROGRESS_MAP</t>").toByteArray(Charsets.UTF_8)
            val wantNav = ("<t name='GameModeQuark'>Quark</t>").toByteArray(Charsets.UTF_8)
            if (raw.containsMarker("name='GameModealphabeth'".toByteArray()) && raw.containsBytes(want) && raw.containsBytes(wantNav)) {
                stringsRes[lang] = "ok-already-applied (key already present with expected value)"
                stringsHash[lang] = CarFile.sha256Hex(sp)
                continue
            }
            if (!bak.isFile) sp.copyTo(bak)
            val (st, det) = patchStringsLang(sp, lang)
            stringsRes[lang] = "$st ($det)"
            if (st.startsWith("ERROR")) {
                for (lg2 in LANGS) {
                    val b2 = File(assets, "international/$lg2/strings.xml.bak")
                    if (b2.isFile) b2.copyTo(File(assets, "international/$lg2/strings.xml"), overwrite = true)
                }
                return "ERROR in texts [$lang]: $det (texts reverted from .bak)"
            }
            stringsHash[lang] = CarFile.sha256Hex(sp)
        }

        val carHashAfter = CarFile.sha256Hex(car)
        if (carHashAfter != carHashBefore) return "ERROR: resource.car changed during apply (aborted)"
        CarFile.verify(car)

        
        manifestFile.parentFile?.mkdirs()
        val sb = StringBuilder()
        sb.append("{\n")
        sb.append("  \"mod\": \"$MOD_ID\",\n")
        sb.append("  \"vector\": \"loose-override assets/main.lua + patched_main.lu (on-device)\",\n")
        sb.append("  \"car_sha256\": \"$carHashAfter\",\n")
        sb.append("  \"orig_main_sha256\": \"${CarFile.sha256Hex(File(assets, ORIG_MAIN))}\",\n")
        sb.append("  \"patched_main_sha256\": \"${CarFile.sha256Hex(File(assets, PATCHED_MAIN))}\",\n")
        sb.append("  \"car_entries\": ${names.size},\n")
        sb.append("  \"files\": {${installed.entries.joinToString(", ") { "\"${it.key}\": \"${it.value}\"" }}},\n")
        sb.append("  \"strings_detail\": {${stringsRes.entries.joinToString(", ") { "\"${it.key}\": \"${it.value.replace("\"", "'")}\"" }}},\n")
        sb.append("  \"art_icons\": ${artIcons.size},\n")
        sb.append("  \"car_lu\": {${carLu.entries.joinToString(", ") { "\"${it.key}\": \"${it.value}\"" }}}\n")
        sb.append("}\n")
        manifestFile.writeText(sb.toString())
        return "OK apply $MOD_ID: car=${car.absolutePath} (${names.size} entries, sha ${carHashAfter.take(12)}...) intact; " +
            "loader installed (${LOADER_FILES.joinToString(", ")}); alphabeth texts in 12/12 languages."
    }

    
    fun patchStringsLang(path: File, lang: String): Pair<String, String> {
        val (st, det) = ensureStringsKey(path, "GameModealphabeth".toByteArray(), PROGRESS_MAP, "GameModeHardcoreShine".toByteArray())
        if (st.startsWith("ERROR")) return st to det
        var prev = "GameModealphabeth"
        var details = ArrayList<String>()
        details.add(det)
        val navs = listOf(
            Triple("GameModePibe", "Pibe", "GameModealphabeth"),
            Triple("GameModeQuark", "Quark", "GameModePibe"),
            Triple("GameModeBack", "Back", "GameModeQuark")
        )
        for ((key, value, anchor) in navs) {
            val (stn, detn) = ensureStringsKey(path, key.toByteArray(), value, anchor.toByteArray())
            if (stn.startsWith("ERROR")) return stn to detn
            details.add("$key: $detn")
            prev = key
        }
        val (st2, det2) = ensureStringsKey(path, "CharacterMap".toByteArray(), PROGRESS_MAP, prev.toByteArray())
        if (st2.startsWith("ERROR")) return st2 to "CharacterMap: $det2"
        if (st == "ok-already-applied" && st2 == "ok-already-applied") {
            return "ok-already-applied" to "2 keys already present ($det; $det2)"
        }
        return "ok-applied" to "$det; CharacterMap: $det2"
    }

    fun ensureStringsKey(path: File, key: ByteArray, value: String, anchor: ByteArray): Pair<String, String> {
        val raw = path.readBytes()
        val marker = "name='".toByteArray() + key + "'".toByteArray()
        val want = "<t name='".toByteArray() + key + "'>".toByteArray() + value.toByteArray(Charsets.UTF_8) + "</t>".toByteArray()
        if (raw.containsBytes(marker)) {
            if (raw.containsBytes(want)) {
                return "ok-already-applied" to "key already present with expected value"
            }
            val lines = raw.splitLines()
            val hit = lines.indices.filter { lines[it].containsBytes(marker) }
            if (hit.size != 1) return "ERROR" to "key '${key.toString(Charsets.UTF_8)}' found ${hit.size}x (expected 1x)"
            val idx = hit[0]
            val oldLine = lines[idx]
            val eol = if (oldLine.endsWith("\r".toByteArray())) "\r".toByteArray() else ByteArray(0)
            val indent = oldLine.leadingWhitespace()
            lines[idx] = indent + want + eol
            path.writeBytes(lines.joinLines())
            return "ok-migrated" to "value updated to '$value'"
        }
        val lines = raw.splitLines()
        val hits = lines.indices.filter { lines[it].containsBytes(anchor) && lines[it].containsBytes("<t ".toByteArray()) }
        if (hits.size != 1) return "ERROR" to "anchor '${anchor.toString(Charsets.UTF_8)}' found ${hits.size}x (expected 1x)"
        val idx = hits[0]
        val anchorLine = lines[idx]
        val eol = if (anchorLine.endsWith("\r".toByteArray())) "\r".toByteArray() else ByteArray(0)
        val indent = anchorLine.leadingWhitespace()
        val newLine = indent + want + eol
        val out = ArrayList<ByteArray>()
        out.addAll(lines.take(idx + 1))
        out.add(newLine)
        out.addAll(lines.drop(idx + 1))
        val joined = out.joinLines()
        if (joined.containsCount(marker) != 1) return "ERROR" to "post-write check failed"
        if (joined.splitLines().size != lines.size + 1) return "ERROR" to "unexpected line count after insert"
        path.writeBytes(joined)
        return "ok-applied" to "1 line inserted after '${anchor.toString(Charsets.UTF_8)}'"
    }

    
    private fun copyAssetDir(
        am: android.content.res.AssetManager,
        assetDir: String,
        destRoot: File,
        artIcons: MutableMap<String, String>,
        assetsDir: File
    ) {
        val list = try { am.list(assetDir)?.toList() ?: emptyList() } catch (_: Exception) { emptyList() }
        if (list.isEmpty()) {
            
            try {
                am.open(assetDir).use { ins ->
                    val rel = assetDir.removePrefix("payload/art/").replace('/', File.separatorChar)
                    val dst = File(destRoot, rel)
                    
                    dst.parentFile?.mkdirs()
                    dst.outputStream().use { ins.copyTo(it) }
                    val key = dst.relativeTo(assetsDir).path.replace(File.separatorChar, '/')
                    artIcons[key] = CarFile.sha256Hex(dst)
                }
            } catch (_: Exception) {  }
            return
        }
        for (name in list) {
            val child = if (assetDir.isEmpty()) name else "$assetDir/$name"
            val sub = try { am.list(child)?.toList() ?: emptyList() } catch (_: Exception) { emptyList() }
            if (sub.isEmpty()) {
                try {
                    am.open(child).use { ins ->
                        val rel = child.removePrefix("payload/art/").replace('/', File.separatorChar)
                        val dst = File(destRoot, rel)
                        dst.parentFile?.mkdirs()
                        dst.outputStream().use { ins.copyTo(it) }
                        val key = runCatching { dst.relativeTo(assetsDir).path.replace(File.separatorChar, '/') }.getOrDefault(rel)
                        artIcons[key] = CarFile.sha256Hex(dst)
                    }
                } catch (_: Exception) { }
            } else {
                copyAssetDir(am, child, destRoot, artIcons, assetsDir)
            }
        }
    }

    
    private fun ByteArray.containsBytes(needle: ByteArray): Boolean {
        if (needle.isEmpty()) return true
        outer@ for (i in 0..size - needle.size) {
            for (j in needle.indices) if (this[i + j] != needle[j]) continue@outer
            return true
        }
        return false
    }

    private fun ByteArray.containsMarker(m: ByteArray) = containsBytes(m)

    private fun ByteArray.containsCount(needle: ByteArray): Int {
        var n = 0
        var i = 0
        while (i <= size - needle.size) {
            var ok = true
            for (j in needle.indices) if (this[i + j] != needle[j]) { ok = false; break }
            if (ok) { n++; i += maxOf(1, needle.size) } else i++
        }
        return n
    }

    
    private fun ByteArray.splitLines(): ArrayList<ByteArray> {
        val tmp = ArrayList<ByteArray>()
        var cur = java.io.ByteArrayOutputStream()
        for (b in this) {
            if (b == '\n'.code.toByte()) {
                tmp.add(cur.toByteArray())
                cur = java.io.ByteArrayOutputStream()
            } else cur.write(b.toInt())
        }
        tmp.add(cur.toByteArray())
        return tmp
    }

    private fun List<ByteArray>.joinLines(): ByteArray {
        val out = java.io.ByteArrayOutputStream()
        for ((i, l) in withIndex()) {
            out.write(l)
            if (i < size - 1) out.write('\n'.code)
        }
        return out.toByteArray()
    }

    private fun ByteArray.leadingWhitespace(): ByteArray {
        var i = 0
        while (i < size && (this[i] == ' '.code.toByte() || this[i] == '\t'.code.toByte())) i++
        return copyOfRange(0, i)
    }

    private fun ByteArray.endsWith(suffix: ByteArray): Boolean {
        if (suffix.size > size) return false
        for (i in suffix.indices) if (this[size - suffix.size + i] != suffix[i]) return false
        return true
    }

    private operator fun ByteArray.plus(other: ByteArray): ByteArray {
        val r = ByteArray(size + other.size)
        System.arraycopy(this, 0, r, 0, size)
        System.arraycopy(other, 0, r, size, other.size)
        return r
    }
}
