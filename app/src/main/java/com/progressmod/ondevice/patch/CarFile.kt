package com.progressmod.ondevice.patch

import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder







object CarFile {
    val MAGIC = byteArrayOf(0x72, 0x61, 0x63, 0x01) 

    data class Entry(val off: Int, val name: String)

    fun padLen(length: Int, kind: String): Int {
        var p = (length + (4 - length % 4)) - length
        if (kind == "data" && p >= 4) p = 0
        return p
    }

    fun readIndex(car: File): List<Entry> {
        val bytes = car.readBytes()
        val bb = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
        val magic = ByteArray(4)
        bb.get(magic)
        require(magic.contentEquals(MAGIC)) { "invalid magic: not a resource.car" }
        val rev = bb.int
        bb.int 
        val n = bb.int
        require(rev == 1) { "resource.car revision = $rev (expected 1)" }
        val out = ArrayList<Entry>(n)
        repeat(n) {
            val dtype = bb.int
            val off = bb.int
            val ln = bb.int
            require(dtype == 1) { "unexpected index entry ($dtype)" }
            val nameBytes = ByteArray(ln)
            bb.get(nameBytes)
            val pad = padLen(ln, "index")
            repeat(pad) { bb.get() }
            out.add(Entry(off, nameBytes.toString(Charsets.UTF_8)))
        }
        return out
    }

    fun extract(car: File, want: String): ByteArray {
        val entries = readIndex(car)
        val size = car.length()
        val raf = car.inputStream().use { it.readBytes() }
        for ((off, name) in entries) {
            if (name != want) continue
            val bb = ByteBuffer.wrap(raf, off, raf.size - off).order(ByteOrder.LITTLE_ENDIAN)
            val dtype = bb.int
            bb.int 
            val ln = bb.int
            require(dtype == 2) { "invalid data entry for '$want'" }
            require(off + 12L + ln <= size) { "entry '$want' exceeds file" }
            return raf.copyOfRange(off + 12, off + 12 + ln)
        }
        throw NoSuchElementException("file '$want' not found in .car")
    }

    fun verify(car: File): List<String> {
        val entries = readIndex(car)
        val names = entries.map { it.name }
        require("main.lu" in names) { "main.lu missing from index" }
        val bytes = car.readBytes()
        val size = bytes.size
        for ((off, name) in entries) {
            val bb = ByteBuffer.wrap(bytes, off, size - off).order(ByteOrder.LITTLE_ENDIAN)
            val dtype = bb.int
            bb.int
            val ln = bb.int
            require(dtype == 2 && off + 12L + ln <= size) { "corrupt entry: '$name'" }
        }
        return names
    }

    fun sha256Hex(f: File): String {
        val d = java.security.MessageDigest.getInstance("SHA-256")
        f.inputStream().use { ins ->
            val buf = ByteArray(65536)
            while (true) {
                val r = ins.read(buf)
                if (r <= 0) break
                d.update(buf, 0, r)
            }
        }
        return d.digest().joinToString("") { "%02x".format(it) }
    }

    fun sha256HexBytes(b: ByteArray): String {
        val d = java.security.MessageDigest.getInstance("SHA-256")
        return d.digest(b).joinToString("") { "%02x".format(it) }
    }

    private fun padIndex(length: Int): Int {
        return (length + (4 - length % 4)) - length
    }

    private fun padData(length: Int): Int {
        val p = (length + (4 - length % 4)) - length
        return if (p >= 4) 0 else p
    }

    fun rebuildCar(
        orig: ByteArray,
        replacements: Map<String, ByteArray>,
        additions: Map<String, ByteArray> = emptyMap()
    ): ByteArray {
        require(orig.size >= 16 && orig[0] == 0x72.toByte() && orig[1] == 0x61.toByte() &&
            orig[2] == 0x63.toByte() && orig[3] == 0x01.toByte()) { "invalid magic: not a resource.car" }
        val h = ByteBuffer.wrap(orig, 4, 12).order(ByteOrder.LITTLE_ENDIAN)
        val rev = h.int
        val unk = h.int
        val n = h.int
        require(rev == 1) { "resource.car revision = $rev (expected 1)" }
        var p = 16
        val index = ArrayList<Pair<Int, String>>()
        repeat(n) {
            val e = ByteBuffer.wrap(orig, p, 12).order(ByteOrder.LITTLE_ENDIAN)
            p += 12
            val dtype = e.int
            val off = e.int
            val ln = e.int
            require(dtype == 1) { "unexpected index entry ($dtype)" }
            val name = orig.copyOfRange(p, p + ln).toString(Charsets.UTF_8)
            p += ln + padIndex(ln)
            index.add(off to name)
        }
        val blobs = LinkedHashMap<String, ByteArray>()
        var origEnd = 0
        for ((off, name) in index) {
            val e = ByteBuffer.wrap(orig, off, 12).order(ByteOrder.LITTLE_ENDIAN)
            val dtype = e.int
            e.int
            val ln = e.int
            require(dtype == 2) { "invalid data entry for '$name'" }
            blobs[name] = orig.copyOfRange(off + 12, off + 12 + ln)
            origEnd = maxOf(origEnd, off + 12 + ln + padData(ln))
        }
        for ((k, v) in replacements) {
            require(blobs.containsKey(k)) { "entry '$k' not found in .car" }
            blobs[k] = v
        }
        val order = ArrayList<String>()
        for ((_, name) in index) order.add(name)
        for ((k, v) in additions) {
            require(!blobs.containsKey(k)) { "entry '$k' already in .car" }
            blobs[k] = v
            order.add(k)
        }
        val out = java.io.ByteArrayOutputStream()
        fun w32(v: Int) {
            out.write(ByteBuffer.allocate(4).order(ByteOrder.LITTLE_ENDIAN).putInt(v).array())
        }
        out.write(orig, 0, 4)
        w32(rev)
        w32(unk)
        w32(order.size)
        var cursor = 16
        for (name in order) {
            val nb = name.toByteArray(Charsets.UTF_8)
            cursor += 12 + nb.size + padIndex(nb.size)
        }
        val parts = ArrayList<Triple<Int, ByteArray, Int>>()
        for (name in order) {
            val nb = name.toByteArray(Charsets.UTF_8)
            val blob = blobs[name]!!
            w32(1)
            w32(cursor)
            w32(nb.size)
            out.write(nb)
            repeat(padIndex(nb.size)) { out.write(0) }
            val nxt = blob.size + padData(blob.size) + 4
            parts.add(Triple(cursor, blob, nxt))
            cursor += 12 + blob.size + padData(blob.size)
        }
        for ((_, blob, nxt) in parts) {
            w32(2)
            w32(nxt)
            w32(blob.size)
            out.write(blob)
            repeat(padData(blob.size)) { out.write(0) }
        }
        out.write(orig, origEnd, orig.size - origEnd)
        return out.toByteArray()
    }
}
