package com.progressmod.ondevice.patch

import java.nio.ByteBuffer
import java.nio.ByteOrder






object LuaPatch {

    const val OP_LOADK = 1
    const val OP_LOADBOOL = 2
    const val OP_LOADNIL = 3
    const val OP_SETTABLE = 9
    const val OP_NEWTABLE = 10
    const val OP_SETLIST = 34

    val K_GAMEMODES = "GameModes".toByteArray()
    val NEW_CONSTS = listOf("alphabeth".toByteArray())

    val P95_FINGERPRINT: List<List<Any?>?> = listOf(
        listOf("Normal"),
        listOf("Relax", "pro"),
        null,
        listOf("minesweeper", "lvl", 15.0),
        listOf("progresscommander", "lvl", 20.0),
        listOf("progresstein", "lvl", 25.0)
    )
    val P96_FINGERPRINT: List<List<Any?>?> = listOf(
        listOf("Relax"), listOf("Normal"), null, listOf("minesweeper"),
        listOf("defender", "lvl", 5.0), listOf("xl", "lvl", 15.0),
        listOf("progresscommander", "pro"), listOf("klondike", "lvl", 25.0),
        listOf("progresstein", "demotimer")
    )
    val PDS_FP: List<List<Any?>?> = listOf(
        listOf("Relax"), listOf("Normal"), listOf("Hardcore"),
        listOf("Progresstrix"), listOf("progresscommander")
    )
    val P_1_FP: List<List<Any?>?> = listOf(
        listOf("Relax"), listOf("Normal"), listOf("Hardcore"),
        listOf("minesweeper"), listOf("defender")
    )
    val P31_FP: List<List<Any?>?> = listOf(
        listOf("Relax"), listOf("Normal"), listOf("Hardcore"),
        listOf("minesweeper"), listOf("defender"),
        listOf("progresstein", "demotimer")
    )
    val P98_FP: List<List<Any?>?> = listOf(
        listOf("Relax"), listOf("Normal"), listOf("Hardcore", "lvl", 1.0),
        listOf("minesweeper"), listOf("defender"),
        listOf("progresstein", "demotimer"), listOf("xl", "pro"),
        listOf("progresscommander", "pro"), listOf("klondike", "pro")
    )
    val PME10_FP: List<List<Any?>?> = listOf(
        listOf("Relax"), listOf("Normal"), listOf("Hardcore"),
        listOf("minesweeper"), listOf("defender"),
        listOf("progresstein", "demotimer"), listOf("xl", "pro"),
        listOf("pinball", "pro"), listOf("klondike", "pro"),
        listOf("Progresstrix", "pro")
    )
    val PNP9_FP: List<List<Any?>?> = listOf(
        listOf("Relax"), listOf("Normal"), listOf("Hardcore"),
        listOf("minesweeper"), listOf("defender"),
        listOf("progresstein", "demotimer"), listOf("pinball", "pro"),
        listOf("klondike", "pro"), listOf("Progresstrix", "pro")
    )

    data class Job(val label: String, val fp: List<List<Any?>?>, val exp: Int)

    val PC_JOBS: List<Job> = listOf(
        Job("PDS", PDS_FP, 1), Job("P_1", P_1_FP, 2), Job("P31", P31_FP, 1),
        Job("P95", P95_FINGERPRINT, 1), Job("P96", P96_FINGERPRINT, 1),
        Job("P98", P98_FP, 1), Job("PME10", PME10_FP, 9), Job("PNP9", PNP9_FP, 3)
    )

    val WINICON_OLD = "ico_warning".toByteArray()
    val WINICON_NEW = "ico_progressmap".toByteArray()

    
    fun a(ins: Long) = ((ins ushr 6) and 0xFF).toInt()
    fun b(ins: Long) = ((ins ushr 23) and 0x1FF).toInt()
    fun c(ins: Long) = ((ins ushr 14) and 0x1FF).toInt()
    fun bx(ins: Long) = ((ins ushr 14) and 0x3FFFF).toInt()
    fun op(ins: Long) = (ins and 0x3FL).toInt()

    fun mkNewTable(a: Int, b: Int, c: Int = 0): Long =
        (OP_NEWTABLE.toLong() or (a.toLong() shl 6) or (c.toLong() shl 14) or (b.toLong() shl 23)) and 0xFFFFFFFFL

    fun mkLoadK(a: Int, bx: Int): Long =
        (OP_LOADK.toLong() or (a.toLong() shl 6) or (bx.toLong() shl 14)) and 0xFFFFFFFFL

    fun mkSetList(a: Int, b: Int, c: Int = 1): Long =
        (OP_SETLIST.toLong() or (a.toLong() shl 6) or (c.toLong() shl 14) or (b.toLong() shl 23)) and 0xFFFFFFFFL

    fun setB(ins: Long, b: Int): Long =
        ((ins and (0x1FFL shl 23).inv()) or ((b.toLong() and 0x1FF) shl 23)) and 0xFFFFFFFFL

    
    sealed class Const {
        object Nil : Const()
        data class Bool(val v: Boolean) : Const()
        data class Num(val v: Double) : Const()
        data class Str(val v: ByteArray) : Const()
    }

    class Proto {
        var src: ByteArray? = null
        var linedef: Int = 0
        var lastlinedef: Int = 0
        var nups: Int = 0
        var numparams: Int = 0
        var isvararg: Int = 0
        var maxstack: Int = 0
        val code = ArrayList<Long>()
        val consts = ArrayList<Const>()
        val subs = ArrayList<Proto>()
        val lineinfo = ArrayList<Int>()
        val locvars = ArrayList<Triple<ByteArray?, Int, Int>>()
        val upvals = ArrayList<ByteArray?>()
    }

    class Reader(val d: ByteArray) {
        var p: Int = 0
        fun raw(n: Int): ByteArray {
            val b = d.copyOfRange(p, p + n)
            p += n
            return b
        }
        fun i32(): Int {
            val v = ByteBuffer.wrap(d, p, 4).order(ByteOrder.LITTLE_ENDIAN).int
            p += 4
            return v
        }
        fun u32(): Long {
            val v = ByteBuffer.wrap(d, p, 4).order(ByteOrder.LITTLE_ENDIAN).int.toLong() and 0xFFFFFFFFL
            p += 4
            return v
        }
        fun string(): ByteArray? {
            val sz = u32().toInt()
            if (sz == 0) return null
            val s = d.copyOfRange(p, p + sz - 1)
            p += sz
            return s
        }
        fun proto(): Proto {
            val q = Proto()
            q.src = string()
            q.linedef = i32()
            q.lastlinedef = i32()
            q.nups = d[p].toInt() and 0xFF; p++
            q.numparams = d[p].toInt() and 0xFF; p++
            q.isvararg = d[p].toInt() and 0xFF; p++
            q.maxstack = d[p].toInt() and 0xFF; p++
            val ncode = i32()
            repeat(ncode) { q.code.add(u32()) }
            val nk = i32()
            repeat(nk) {
                val t = d[p].toInt() and 0xFF; p++
                when (t) {
                    0 -> q.consts.add(Const.Nil)
                    1 -> {
                        val v = d[p].toInt() != 0; p++
                        q.consts.add(Const.Bool(v))
                    }
                    3 -> {
                        val v = ByteBuffer.wrap(d, p, 8).order(ByteOrder.LITTLE_ENDIAN).double
                        p += 8
                        q.consts.add(Const.Num(v))
                    }
                    4 -> q.consts.add(Const.Str(string()!!))
                    else -> throw IllegalArgumentException("const type $t")
                }
            }
            val np = i32()
            repeat(np) { q.subs.add(proto()) }
            val nl = i32()
            repeat(nl) { q.lineinfo.add(i32()) }
            val nv = i32()
            repeat(nv) {
                val nm = string()
                val av = i32(); val bv = i32()
                q.locvars.add(Triple(nm, av, bv))
            }
            val nu = i32()
            repeat(nu) { q.upvals.add(string()) }
            return q
        }
    }

    data class Parsed(val header: ByteArray, val protos: List<Proto>)

    fun parse(data: ByteArray): Parsed {
        require(data.size >= 4 && data[0] == 0x1B.toByte() && data[1] == 'L'.code.toByte() &&
            data[2] == 'u'.code.toByte() && data[3] == 'a'.code.toByte()) { "missing Lua magic" }
        val r = Reader(data)
        val header = r.raw(12)
        val protos = listOf(r.proto())
        require(r.p == data.size) { "${data.size - r.p} bytes left after parse" }
        return Parsed(header, protos)
    }

    class Writer {
        val b = java.io.ByteArrayOutputStream()
        fun raw(x: ByteArray) = b.write(x)
        fun i32(v: Int) {
            val bb = ByteBuffer.allocate(4).order(ByteOrder.LITTLE_ENDIAN).putInt(v)
            b.write(bb.array())
        }
        fun u32(v: Long) {
            val bb = ByteBuffer.allocate(4).order(ByteOrder.LITTLE_ENDIAN).putInt((v and 0xFFFFFFFFL).toInt())
            b.write(bb.array())
        }
        fun string(s: ByteArray?) {
            if (s == null) u32(0)
            else {
                u32((s.size + 1).toLong())
                b.write(s)
                b.write(0)
            }
        }
        fun proto(q: Proto) {
            string(q.src)
            i32(q.linedef); i32(q.lastlinedef)
            b.write(byteArrayOf(q.nups.toByte(), q.numparams.toByte(), q.isvararg.toByte(), q.maxstack.toByte()))
            i32(q.code.size)
            for (ins in q.code) u32(ins)
            i32(q.consts.size)
            for (k in q.consts) {
                when (k) {
                    is Const.Nil -> b.write(byteArrayOf(0))
                    is Const.Bool -> b.write(byteArrayOf(1, if (k.v) 1 else 0))
                    is Const.Num -> {
                        b.write(byteArrayOf(3))
                        val bb = ByteBuffer.allocate(8).order(ByteOrder.LITTLE_ENDIAN).putDouble(k.v)
                        b.write(bb.array())
                    }
                    is Const.Str -> {
                        b.write(byteArrayOf(4))
                        string(k.v)
                    }
                }
            }
            i32(q.subs.size)
            for (s in q.subs) proto(s)
            i32(q.lineinfo.size)
            for (ln in q.lineinfo) i32(ln)
            i32(q.locvars.size)
            for ((nm, av, bv) in q.locvars) {
                string(nm); i32(av); i32(bv)
            }
            i32(q.upvals.size)
            for (nm in q.upvals) string(nm)
        }
    }

    fun serialize(header: ByteArray, protos: List<Proto>): ByteArray {
        val w = Writer()
        w.raw(header)
        for (q in protos) w.proto(q)
        return w.b.toByteArray()
    }

    fun parseProtoOnly(data: ByteArray): Proto {
        val r = Reader(data)
        val p = r.proto()
        require(r.p == data.size) { "${data.size - r.p} bytes left after parse" }
        return p
    }

    fun serializeProtoOnly(p: Proto): ByteArray {
        val w = Writer()
        w.proto(p)
        return w.b.toByteArray()
    }

    
    data class Site(
        val loadk: Int, val hint: Int, val n: Int = 0, val lastReg: Int = 0,
        val setlist: Int, val settable: Int, val startReg: Int = 0,
        val entriesRegs: List<Int> = emptyList()
    )

    fun constStrIdx(p: Proto, want: ByteArray): Int? {
        for ((i, k) in p.consts.withIndex()) {
            if (k is Const.Str && k.v.contentEquals(want)) return i
        }
        return null
    }

    
    fun findGamemodesSite(p: Proto, firstName: ByteArray): List<Site> {
        val strIdx = constStrIdx(p, K_GAMEMODES) ?: throw IllegalArgumentException("missing GameModes const")
        val firstIdx = constStrIdx(p, firstName) ?: throw IllegalArgumentException("missing const ${firstName.toString(Charsets.UTF_8)}")
        val code = p.code
        val out = ArrayList<Site>()
        for (i in code.indices) {
            val ins = code[i]
            if (!(op(ins) == OP_LOADK && bx(ins) == strIdx && a(ins) == 5)) continue
            if (i + 1 >= code.size) continue
            if (!(op(code[i + 1]) == OP_NEWTABLE && a(code[i + 1]) == 6)) continue
            if (b(code[i + 1]) != 10) continue
            if (i + 4 >= code.size) continue
            val e0 = code.subList(i + 2, i + 5)
            if (!((op(e0[0]) == OP_NEWTABLE && a(e0[0]) == 7) &&
                    (op(e0[1]) == OP_LOADK && a(e0[1]) == 8 && bx(e0[1]) == firstIdx) &&
                    (op(e0[2]) == OP_SETLIST && a(e0[2]) == 7 && b(e0[2]) == 1))
            ) continue
            
            var j = i + 2
            var ok = true
            val regs = ArrayList<Int>()
            for (k in 0 until 10) {
                if (j >= code.size) { ok = false; break }
                val ins2 = code[j]
                if (!(op(ins2) == OP_NEWTABLE && a(ins2) == 7 + k)) { ok = false; break }
                var m = j + 1
                while (true) {
                    if (m >= code.size) { ok = false; break }
                    val ins3 = code[m]
                    if (op(ins3) == OP_SETLIST && a(ins3) == 7 + k) break
                    if (op(ins3) == OP_NEWTABLE && a(ins3) != 7 + k) { ok = false; break }
                    m++
                    if (m - j > 8) { ok = false; break }
                }
                if (!ok) break
                regs.add(7 + k)
                j = m + 1
            }
            if (!ok || regs != (7..16).toList()) continue
            if (j >= code.size) continue
            val fin = code[j]
            if (!((op(fin) == OP_SETLIST && a(fin) == 6 && b(fin) == 10))) continue
            val st = code.getOrNull(j + 1) ?: continue
            if (!((op(st) == OP_SETTABLE && a(st) == 4 && b(st) == 5 && c(st) == 6))) continue
            out.add(Site(loadk = i, hint = i + 1, setlist = j, settable = j + 1, entriesRegs = regs))
        }
        return out
    }

    fun constPy(p: Proto, idx: Int): Any? {
        return when (val k = p.consts[idx]) {
            is Const.Nil -> null
            is Const.Bool -> k.v
            is Const.Num -> k.v
            is Const.Str -> k.v.toString(Charsets.UTF_8)
        }
    }

    
    fun walkEntries(p: Proto, i: Int): Pair<List<List<Any?>?>, Int> {
        val code = p.code
        val entries = ArrayList<List<Any?>?>()
        var expectReg = 7
        var j = i + 2
        while (true) {
            var guardS = 0
            while (j < code.size) {
                val o = op(code[j])
                if (o == OP_LOADK || o == OP_LOADBOOL || (o == OP_SETTABLE && a(code[j]) == 6)) j++
                else break
                guardS++
                if (guardS > 10) throw IllegalArgumentException("scratch too long at $j")
            }
            if (j >= code.size) break
            val ins2 = code[j]
            val op2 = op(ins2)
            if (op2 == OP_NEWTABLE) {
                if (a(ins2) != expectReg) throw IllegalArgumentException("NEWTABLE out of order at $j")
                val reg = expectReg
                val vals = ArrayList<Any?>()
                var m = j + 1
                var guard = 0
                while (true) {
                    val ins3 = code[m]
                    val o3 = op(ins3)
                    if (o3 == OP_LOADK) {
                        vals.add(constPy(p, bx(ins3)))
                        m++
                    } else if (o3 == OP_SETLIST && a(ins3) == reg) {
                        if (b(ins3) != vals.size) throw IllegalArgumentException("SETLIST B!=nvals at $m")
                        m++
                        break
                    } else throw IllegalArgumentException("unexpected pattern in entry (instr $m op $o3)")
                    guard++
                    if (guard > 12) throw IllegalArgumentException("entry too long at $j")
                }
                entries.add(vals)
                expectReg++
                j = m
            } else if (op2 == OP_LOADNIL) {
                if (!(a(ins2) == expectReg && b(ins2) == expectReg)) throw IllegalArgumentException("unexpected LOADNIL at $j")
                entries.add(null)
                expectReg++
                j++
            } else break
        }
        return Pair(entries, j)
    }

    fun findFlex(p: Proto, fingerprint: List<List<Any?>?>): List<Site> {
        val strIdx = constStrIdx(p, K_GAMEMODES) ?: throw IllegalArgumentException("missing GameModes const")
        val code = p.code
        val out = ArrayList<Site>()
        for (i in code.indices) {
            val ins = code[i]
            if (!((op(ins) == OP_LOADK && bx(ins) == strIdx && a(ins) == 5))) continue
            if (i + 1 >= code.size) continue
            if (!(op(code[i + 1]) == OP_NEWTABLE && a(code[i + 1]) == 6)) continue
            val (entries, j) = try {
                walkEntries(p, i)
            } catch (_: Exception) { continue }
            if (entries != fingerprint) continue
            val n = entries.size
            if (b(code[i + 1]) != n) continue
            
            var k = j
            var ok = true
            var guard = 0
            while (true) {
                if (k >= code.size) { ok = false; break }
                val o = op(code[k])
                if (o == OP_SETLIST && a(code[k]) == 6) break
                if (o == OP_LOADK || o == OP_LOADBOOL || (o == OP_SETTABLE && a(code[k]) == 6)) k++
                else { ok = false; break }
                guard++
                if (guard > 10) { ok = false; break }
            }
            if (!ok) continue
            if (b(code[k]) != n) continue
            val st = code.getOrNull(k + 1) ?: continue
            if (!((op(st) == OP_SETTABLE && a(st) == 4 && b(st) == 5 && c(st) == 6))) continue
            out.add(Site(loadk = i, hint = i + 1, n = n, lastReg = 6 + n, setlist = k, settable = k + 1))
        }
        return out
    }

    data class ApplyReport(
        val newConsts: Map<String, Int>,
        val sites: List<Map<String, Any>>,
        val p24Lines: List<Int>,
        val winicon: Map<String, Any>
    )

    fun applyUnused4(protos: List<Proto>): Triple<ApplyReport, Proto, List<Int>> {
        val p24 = protos[0].subs[0].subs[24]
        val p24Lines = listOf(p24.linedef, p24.lastlinedef)
        for (ins in p24.code) {
            if (op(ins) in listOf(22, 31, 32)) throw IllegalArgumentException("unexpected jump in target prototype")
        }
        val have = HashMap<String, Int>()
        for ((idx, k) in p24.consts.withIndex()) {
            if (k is Const.Str) have.putIfAbsent(k.v.toString(Charsets.UTF_8), idx)
        }
        val newIdx = HashMap<String, Int>()
        for (name in NEW_CONSTS) {
            val s = name.toString(Charsets.UTF_8)
            if (s in have) newIdx[s] = have[s]!!
            else {
                newIdx[s] = p24.consts.size
                p24.consts.add(Const.Str(name))
            }
        }
        val newConstsReport = newIdx.filter { (k, _) -> k == "alphabeth" && k !in have }

        data class Plan(val loadk: Int, val label: String, val site: Site, val startReg: Int, val append: List<ByteArray>, val newB: Int)
        val plan = ArrayList<Plan>()
        val pairs = listOf(
            Triple("RelaxShine".toByteArray(), listOf("alphabeth".toByteArray()), 11),
            Triple("Shine".toByteArray(), listOf("alphabeth".toByteArray()), 11)
        )
        for ((key, append, newB) in pairs) {
            val found = findGamemodesSite(p24, key)
            require(found.size == 1) { "${key.toString(Charsets.UTF_8)}: ${found.size} sites (expected 1)" }
            val s = found[0]
            plan.add(Plan(s.loadk, key.toString(Charsets.UTF_8), s, 17, append, newB))
        }
        for (job in PC_JOBS) {
            val found = findFlex(p24, job.fp)
            require(found.size == job.exp) { "${job.label}: ${found.size} sites (expected ${job.exp})" }
            val newB = job.fp.size + 1
            for (s in found) {
                plan.add(Plan(s.loadk, job.label, s.copy(startReg = s.lastReg + 1), s.lastReg + 1, listOf("alphabeth".toByteArray()), newB))
            }
        }
        plan.sortByDescending { it.loadk }
        val sitesReport = ArrayList<Map<String, Any>>()
        for (item in plan) {
            val label = item.label
            val site = item.site
            val app = item.append
            val newB = item.newB
            val startReg = item.startReg
            val nNew = app.size
            val block = ArrayList<Long>()
            for ((k, mode) in app.withIndex()) {
                val re = startReg + k
                val rt = startReg + k + 1
                val key = mode.toString(Charsets.UTF_8)
                block.add(mkNewTable(re, 1, 0))
                block.add(mkLoadK(rt, newIdx[key]!!))
                block.add(mkSetList(re, 1, 1))
            }
            val at = site.setlist
            require(p24.maxstack >= startReg + nNew + 1) { "maxstack too small for $label" }
            p24.code.addAll(at, block)
            if (p24.lineinfo.isNotEmpty()) {
                repeat(nNew * 3) { p24.lineinfo.add(at, p24.lineinfo[at]) }
            }
            p24.code[site.hint] = setB(p24.code[site.hint], newB)
            p24.code[at + 3 * nNew] = setB(p24.code[at + 3 * nNew], newB)
            val fin = p24.code[at + 3 * nNew]
            require(op(fin) == OP_SETLIST && a(fin) == 6 && b(fin) == newB) { "SETLIST post-check failed ($label)" }
            sitesReport.add(mapOf("first" to label, "loadk" to site.loadk, "insert_at" to at, "added" to nNew, "final_B" to newB))
        }
        val report = ApplyReport(newConstsReport, sitesReport, p24Lines, emptyMap())
        return Triple(report, p24, p24Lines)
    }

    
    data class Audit(val hintB: Int, val finalB: Int, val entries: List<List<Any?>?>, val loadk: Int, val setlist: Int)

    fun auditGamemodes(p: Proto, firstName: ByteArray): Audit {
        val strIdx = constStrIdx(p, K_GAMEMODES)!!
        val firstIdx = constStrIdx(p, firstName)!!
        val code = p.code
        for (i in code.indices) {
            val ins = code[i]
            if (!(op(ins) == OP_LOADK && bx(ins) == strIdx && a(ins) == 5)) continue
            if (i + 4 >= code.size) continue
            val e0 = code.subList(i + 2, i + 5)
            if (!((op(e0[0]) == OP_NEWTABLE && a(e0[0]) == 7) &&
                    (op(e0[1]) == OP_LOADK && bx(e0[1]) == firstIdx))
            ) continue
            val hint = b(code[i + 1])
            val (entries, j) = walkEntries(p, i)
            val fin = code[j]
            require(op(fin) == OP_SETLIST && a(fin) == 6) { "SETLIST final missing" }
            return Audit(hint, b(fin), entries, i, j)
        }
        throw IllegalArgumentException("site ${firstName.toString(Charsets.UTF_8)} not found")
    }

    fun auditPrefix(p: Proto, prefix: List<List<Any?>?>): Audit {
        val strIdx = constStrIdx(p, K_GAMEMODES)!!
        val code = p.code
        val hits = ArrayList<Audit>()
        for (i in code.indices) {
            val ins = code[i]
            if (!((op(ins) == OP_LOADK && bx(ins) == strIdx && a(ins) == 5))) continue
            if (i + 1 >= code.size) continue
            if (!(op(code[i + 1]) == OP_NEWTABLE && a(code[i + 1]) == 6)) continue
            val (entries, j) = try { walkEntries(p, i) } catch (_: Exception) { continue }
            if (entries.take(prefix.size) != prefix) continue
            val fin = code.getOrNull(j) ?: continue
            if (!(op(fin) == OP_SETLIST && a(fin) == 6)) continue
            hits.add(Audit(b(code[i + 1]), b(fin), entries, i, j))
        }
        require(hits.size == 1) { "prefix: ${hits.size} sites (expected 1)" }
        return hits[0]
    }

    fun auditSites(p: Proto, fingerprint: List<List<Any?>?>): List<Audit> {
        val strIdx = constStrIdx(p, K_GAMEMODES)!!
        val code = p.code
        val hits = ArrayList<Audit>()
        for (i in code.indices) {
            val ins = code[i]
            if (!((op(ins) == OP_LOADK && bx(ins) == strIdx && a(ins) == 5))) continue
            if (i + 1 >= code.size) continue
            if (!(op(code[i + 1]) == OP_NEWTABLE && a(code[i + 1]) == 6)) continue
            val (entries, j) = try { walkEntries(p, i) } catch (_: Exception) { continue }
            if (entries.take(fingerprint.size) != fingerprint) continue
            var k = j
            var ok = true
            var guard = 0
            while (true) {
                if (k >= code.size) { ok = false; break }
                val o = op(code[k])
                if (o == OP_SETLIST && a(code[k]) == 6) break
                if (o == OP_LOADK || o == OP_LOADBOOL || (o == OP_SETTABLE && a(code[k]) == 6)) k++
                else { ok = false; break }
                guard++
                if (guard > 10) { ok = false; break }
            }
            if (!ok) continue
            hits.add(Audit(b(code[i + 1]), b(code[k]), entries, i, k))
        }
        return hits
    }

    
    fun applyWinicon(protos: List<Proto>): Map<String, Any> {
        val cands = ArrayList<Pair<Int, Proto>>()
        for ((si, s) in protos[0].subs[0].subs.withIndex()) {
            val hasC = s.consts.any { it is Const.Str && it.v.contentEquals("CharacterMap".toByteArray()) }
            val hasW = s.consts.any { it is Const.Str && it.v.contentEquals(WINICON_OLD) }
            if (hasC && hasW) cands.add(si to s)
        }
        require(cands.isNotEmpty()) { "no prototype with CharacterMap/ico_warning consts" }
        val hits = ArrayList<Pair<Int, Int>>()
        for ((si, proto) in cands) {
            var idxWarn: Int? = null
            var idxCharmap: Int? = null
            for ((i, k) in proto.consts.withIndex()) {
                if (k is Const.Str && k.v.contentEquals(WINICON_OLD) && idxWarn == null) idxWarn = i
                if (k is Const.Str && k.v.contentEquals("CharacterMap".toByteArray()) && idxCharmap == null) idxCharmap = i
            }
            if (idxWarn == null || idxCharmap == null) continue
            val code = proto.code
            for (i in code.indices) {
                val ins = code[i]
                if (!((op(ins) == OP_LOADK && a(ins) == 31 && bx(ins) == idxCharmap))) continue
                if (i + 2 >= code.size) continue
                if (op(code[i + 1]) != 28) continue
                val ins2 = code[i + 2]
                if (!((op(ins2) == OP_LOADK && a(ins2) == 31 && bx(ins2) == idxWarn))) continue
                hits.add(si to (i + 2))
            }
        }
        require(hits.size == 1) { "winicon site: ${hits.size} matches (expected 1)" }
        val (si, at) = hits[0]
        val target = protos[0].subs[0].subs[si]
        var newIdx: Int? = null
        for ((i, k) in target.consts.withIndex()) {
            if (k is Const.Str && k.v.contentEquals(WINICON_NEW)) { newIdx = i; break }
        }
        if (newIdx == null) {
            newIdx = target.consts.size
            target.consts.add(Const.Str(WINICON_NEW))
        }
        val old = target.code[at]
        target.code[at] = (old and (0x3FFFFL shl 14).inv()) or ((newIdx!!.toLong() and 0x3FFFF) shl 14)
        val check = target.code[at]
        require(op(check) == OP_LOADK && a(check) == 31 && bx(check) == newIdx) { "LOADK post-check failed (winicon)" }
        return mapOf(
            "proto_lines" to listOf(target.linedef, target.lastlinedef),
            "instr" to at, "const_idx" to newIdx!!, "icon" to "ico_progressmap"
        )
    }

    fun constKey(k: Const): String = when (k) {
        is Const.Nil -> "nil"
        is Const.Bool -> "bool:${k.v}"
        is Const.Num -> "num:${k.v}"
        is Const.Str -> "str:" + k.v.toString(Charsets.UTF_8)
    }

    fun walkAll(p: Proto, out: MutableList<Proto>) {
        out.add(p)
        for (s in p.subs) walkAll(s, out)
    }

    fun verifyPatch(origBytes: ByteArray, patchedBytes: ByteArray, dCode: Int = 63, p24Lines: List<Int>) {
        val (_, po) = parse(origBytes)
        val (_, pn) = parse(patchedBytes)
        val lo = ArrayList<Proto>()
        val ln = ArrayList<Proto>()
        walkAll(po[0], lo)
        walkAll(pn[0], ln)
        require(lo.size == ln.size) { "prototype count changed" }
        val changed = ArrayList<Pair<List<Int>, List<String>>>()
        for ((a, b) in lo.zip(ln)) {
            val diffs = ArrayList<String>()
            if (a.linedef to a.lastlinedef != b.linedef to b.lastlinedef ||
                a.nups != b.nups || a.numparams != b.numparams
            ) diffs.add("header")
            if (a.consts.map { constKey(it) } != b.consts.map { constKey(it) }) diffs.add("consts ${a.consts.size}->${b.consts.size}")
            if (a.code != b.code) diffs.add("code ${a.code.size}->${b.code.size}")
            if (a.lineinfo != b.lineinfo) diffs.add("lineinfo")
            if (diffs.isNotEmpty()) changed.add(listOf(a.linedef, a.lastlinedef) to diffs)
        }
        require(changed.size == 2) { "changed prototype count = ${changed.size} (expected 2)" }
        require(changed.any { it.first == p24Lines }) { "gamemodes prototype not among changed: $changed" }
        val a = lo.first { listOf(it.linedef, it.lastlinedef) == p24Lines }
        val b = ln.first { listOf(it.linedef, it.lastlinedef) == p24Lines }
        require(b.consts.size - a.consts.size == 1) { "delta consts != 1" }
        val tail = (b.consts.last() as Const.Str).v
        require(tail.contentEquals("alphabeth".toByteArray())) { "unexpected new consts" }
        require(a.consts.map { constKey(it) } == b.consts.dropLast(1).map { constKey(it) }) { "pre-existing consts changed" }
        require(b.code.size - a.code.size == dCode) { "delta code != $dCode" }
        val others = changed.map { it.first }.filter { it != p24Lines }
        require(others.size == 1) { "winicon prototype not unique: $changed" }
        val a2 = lo.first { listOf(it.linedef, it.lastlinedef) == others[0] }
        val b2 = ln.first { listOf(it.linedef, it.lastlinedef) == others[0] }
        require(b2.consts.size - a2.consts.size == 1) { "winicon: delta consts != 1" }
        require((b2.consts.last() as Const.Str).v.contentEquals(WINICON_NEW)) { "winicon: unexpected new const" }
        require(a2.code.size == b2.code.size) { "winicon: code size changed" }
        val dw = a2.code.indices.filter { a2.code[it] != b2.code[it] }
        require(dw.size == 1) { "winicon: ${dw.size} words changed (expected 1)" }
        val ins = b2.code[dw[0]]
        require(op(ins) == OP_LOADK && a(ins) == 31 && bx(ins) == b2.consts.size - 1) { "winicon: changed word is not the expected LOADK" }
    }

    data class PatchedMain(val bytes: ByteArray, val p24Lines: List<Int>)

    fun buildPatchedMain(mainBytes: ByteArray): PatchedMain {
        val (header, protos) = parse(mainBytes)
        require(serialize(header, protos).contentEquals(mainBytes)) { "parser round-trip NOT identical (aborted)" }
        val (report, _, p24Lines) = applyUnused4(protos)
        applyWinicon(protos)
        val patched = serialize(header, protos)
        verifyPatch(mainBytes, patched, 63, p24Lines)
        
        val (_, protos2) = parse(patched)
        val p24 = protos2[0].subs[0].subs[24]
        for (first in listOf("Shine", "RelaxShine")) {
            val au = auditGamemodes(p24, first.toByteArray())
            val got = au.entries.map { if (it is List<*>) it.getOrNull(0) as? String else null }
            require(got.takeLast(1) == listOf("alphabeth")) { "unexpected tail in '$first': $got" }
        }
        val a95 = auditPrefix(p24, P95_FINGERPRINT)
        require(a95.entries.size == 7) { "P95: n=${a95.entries.size} (expected 7)" }
        require(a95.entries.take(6) == P95_FINGERPRINT) { "P95: original prefix changed" }
        for (job in PC_JOBS) {
            if (job.label == "P95") continue
            val hits = auditSites(p24, job.fp).filter { it.entries == job.fp + listOf(listOf("alphabeth")) }
            require(hits.size == job.exp) { "${job.label}: audit found ${hits.size} sites (expected ${job.exp})" }
        }
        return PatchedMain(patched, p24Lines)
    }
}
