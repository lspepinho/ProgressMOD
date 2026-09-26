package com.progressmod.ondevice.patch

import com.android.apksig.ApkSigner
import java.io.File
import java.math.BigInteger
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.PrivateKey
import java.security.cert.X509Certificate
import java.util.Calendar
import java.util.Date
import java.util.zip.ZipEntry
import java.util.zip.ZipFile
import java.util.zip.ZipOutputStream
import org.bouncycastle.asn1.x500.X500Name
import org.bouncycastle.cert.jcajce.JcaX509CertificateConverter
import org.bouncycastle.cert.jcajce.JcaX509v3CertificateBuilder
import org.bouncycastle.operator.jcajce.JcaContentSignerBuilder








object ApkSignerOnDevice {

    private const val KS_NAME = "ondevice-testkey.bks"
    private const val ALIAS = "testkey"
    private const val PASS = "android"

    data class KeyAndCert(val key: PrivateKey, val certs: List<X509Certificate>)

    @Synchronized
    fun getOrCreateKey(filesDir: File): KeyAndCert {
        val ksFile = File(filesDir, KS_NAME)
        if (ksFile.isFile) {
            try {
                val ks = KeyStore.getInstance("BKS")
                ksFile.inputStream().use { ks.load(it, PASS.toCharArray()) }
                val key = ks.getKey(ALIAS, PASS.toCharArray()) as PrivateKey
                val cert = ks.getCertificate(ALIAS) as X509Certificate
                return KeyAndCert(key, listOf(cert))
            } catch (_: Exception) {
                ksFile.delete()
            }
        }
        val kpg = KeyPairGenerator.getInstance("RSA")
        kpg.initialize(2048)
        val kp = kpg.generateKeyPair()
        val cert = selfSign(kp.private, kp.public)
        val ks = KeyStore.getInstance("BKS")
        ks.load(null, PASS.toCharArray())
        ks.setKeyEntry(ALIAS, kp.private, PASS.toCharArray(), arrayOf(cert))
        ksFile.outputStream().use { ks.store(it, PASS.toCharArray()) }
        return KeyAndCert(kp.private, listOf(cert))
    }

    private fun selfSign(priv: PrivateKey, pub: java.security.PublicKey): X509Certificate {
        val now = Date()
        val cal = Calendar.getInstance()
        cal.time = now
        cal.add(Calendar.YEAR, 30)
        val notAfter = cal.time
        val serial = BigInteger.valueOf(System.currentTimeMillis())
        val owner = X500Name("CN=ProgressMOD-OnDevice-Test")
        val builder = JcaX509v3CertificateBuilder(
            owner, serial, now, notAfter, owner, pub
        )
        val signer = JcaContentSignerBuilder("SHA256withRSA").build(priv)
        val holder = builder.build(signer)
        return JcaX509CertificateConverter().getCertificate(holder)
    }

    fun sign(unsignedApk: File, signedApk: File, filesDir: File, log: (String) -> Unit = {}) {
        val (key, certs) = getOrCreateKey(filesDir)
        if (signedApk.isFile) signedApk.delete()
        unsignedApk.copyTo(signedApk)
        val signerConfig = ApkSigner.SignerConfig.Builder("ondevice", key, certs).build()
        val signer = ApkSigner.Builder(listOf(signerConfig))
            .setInputApk(unsignedApk)
            .setOutputApk(signedApk)
            .setV1SigningEnabled(true)
            .setV2SigningEnabled(true)
            .setV3SigningEnabled(false)
            .setV4SigningEnabled(false)
            .setOtherSignersSignaturesPreserved(false)
            .build()
        signer.sign()
        log("signed: ${signedApk.absolutePath} (${signedApk.length()} bytes, v1+v2)")
    }

    fun resignSplit(src: File, outDir: File, filesDir: File, log: (String) -> Unit = {}): File {
        outDir.mkdirs()
        val stripped = File(outDir, src.name + ".tmp")
        if (stripped.isFile) stripped.delete()
        ZipFile(src).use { zip ->
            ZipOutputStream(stripped.outputStream().buffered()).use { out ->
                val entries = zip.entries()
                while (entries.hasMoreElements()) {
                    val entry = entries.nextElement()
                    if (entry.name.startsWith("META-INF/")) continue
                    val fresh = ZipEntry(entry.name)
                    fresh.time = entry.time
                    fresh.method = entry.method
                    if (entry.method == ZipEntry.STORED) {
                        fresh.size = entry.size
                        fresh.crc = entry.crc
                    }
                    out.putNextEntry(fresh)
                    zip.getInputStream(entry).use { it.copyTo(out) }
                    out.closeEntry()
                }
            }
        }
        val out = File(outDir, src.name)
        sign(stripped, out, filesDir, log)
        stripped.delete()
        return out
    }
}
