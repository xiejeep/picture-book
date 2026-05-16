package com.example.picture_book_app

import android.content.Intent
import android.nfc.NdefMessage
import android.nfc.NdefRecord
import android.nfc.NfcAdapter
import android.nfc.tech.Ndef
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "com.example.picture_book_app/nfc"
    private var pendingNfcUris: List<String>? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                if (call.method == "getPendingNfcIntent") {
                    result.success(pendingNfcUris)
                    pendingNfcUris = null
                } else {
                    result.notImplemented()
                }
            }
        pendingNfcUris = extractNfcUris(intent)
        if (pendingNfcUris != null) {
            android.util.Log.d("NFC", "Cached NFC intent URIs on cold start: $pendingNfcUris")
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val uris = extractNfcUris(intent)
        if (uris != null) {
            android.util.Log.d("NFC", "NFC intent URIs from onNewIntent: $uris")
            MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, channel)
                .invokeMethod("onNfcIntent", uris)
        }
    }

    @Suppress("DEPRECATION")
    private fun extractNfcUris(intent: Intent?): List<String>? {
        if (intent == null) return null
        val action = intent.action ?: return null

        if (action != NfcAdapter.ACTION_NDEF_DISCOVERED &&
            action != NfcAdapter.ACTION_TECH_DISCOVERED &&
            action != NfcAdapter.ACTION_TAG_DISCOVERED
        ) return null

        val uris = mutableListOf<String>()

        val rawMessages: Array<NdefMessage>? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableArrayExtra(NfcAdapter.EXTRA_NDEF_MESSAGES, NdefMessage::class.java)
                ?.map { it as NdefMessage }?.toTypedArray()
        } else {
            intent.getParcelableArrayExtra(NfcAdapter.EXTRA_NDEF_MESSAGES)
                ?.map { it as NdefMessage }?.toTypedArray()
        }

        if (rawMessages != null) {
            for (msg in rawMessages) {
                for (record in msg.records) {
                    val uri = record.toUri()
                    if (uri != null) {
                        uris.add(uri.toString())
                    } else {
                        uris.add(String(record.payload, Charsets.UTF_8))
                    }
                }
            }
        }

        if (uris.isEmpty()) {
            val tag: android.nfc.Tag? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                intent.getParcelableExtra(NfcAdapter.EXTRA_TAG, android.nfc.Tag::class.java)
            } else {
                intent.getParcelableExtra(NfcAdapter.EXTRA_TAG)
            }
            if (tag != null) {
                val ndef = Ndef.get(tag)
                if (ndef != null) {
                    val cachedMsg: NdefMessage? = ndef.cachedNdefMessage
                    if (cachedMsg != null) {
                        for (record in cachedMsg.records) {
                            val uri = record.toUri()
                            if (uri != null) {
                                uris.add(uri.toString())
                            } else {
                                uris.add(String(record.payload, Charsets.UTF_8))
                            }
                        }
                    }
                }
            }
        }

        return if (uris.isNotEmpty()) uris else null
    }
}
