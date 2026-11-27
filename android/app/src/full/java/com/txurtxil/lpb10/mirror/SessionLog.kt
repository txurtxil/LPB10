/*
 * SPDX-FileCopyrightText: 2026 txurtxil
 * SPDX-License-Identifier: GPL-3.0-only
 */

package com.txurtxil.lpb10.mirror

import android.content.ContentResolver
import android.content.Context
import android.net.Uri
import android.util.Log
import androidx.core.net.toFile
import java.io.File
import java.io.IOException
import java.text.SimpleDateFormat
import java.util.Locale

/**
 * A small append-only log written exclusively by this app, kept separate from the system
 * logcat buffer. Unlike logcat, this survives regardless of how much other apps log in the
 * meantime, so it reliably captures a full drive/park cycle even if you don't export it
 * right away.
 */
object SessionLog {
    private val TAG = SessionLog::class.java.simpleName

    const val FILENAME_DEFAULT = "session_log.txt"
    const val MIMETYPE = "text/plain"

    // Trim the file once it grows past this many lines, keeping only the most recent ones.
    private const val MAX_LINES = 500

    private val dateFormat = SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.US)

    // We only need this for opening file descriptors and locating the log file.
    private lateinit var applicationContext: Context
    private lateinit var logFile: File

    fun init(context: Context) {
        applicationContext = context.applicationContext
        logFile = File(applicationContext.filesDir, FILENAME_DEFAULT)
        // Make sure the file exists from the start, so dump() never fails with
        // FileNotFoundException if the user exports before record() has ever run.
        if (!logFile.exists()) {
            try {
                logFile.createNewFile()
            } catch (e: IOException) {
                Log.e(TAG, "Failed to create session log file", e)
            }
        }
    }

    @Synchronized
    fun record(line: String) {
        if (!::logFile.isInitialized) return
        try {
            logFile.appendText("${dateFormat.format(System.currentTimeMillis())} $line\n")
            trimIfNeeded()
        } catch (e: IOException) {
            Log.e(TAG, "Failed to write to session log", e)
        }
    }

    @Synchronized
    private fun trimIfNeeded() {
        val lines = logFile.readLines()
        if (lines.size > MAX_LINES) {
            logFile.writeText(lines.takeLast(MAX_LINES).joinToString("\n", postfix = "\n"))
        }
    }

    fun dump(uri: Uri) {
        if (!::logFile.isInitialized) return
        if (uri.scheme == ContentResolver.SCHEME_FILE) {
            logFile.copyTo(uri.toFile(), overwrite = true)
            return
        }

        Log.d(TAG, "Copying session log to $uri")

        val out = applicationContext.contentResolver.openOutputStream(uri)
            ?: throw IOException("Failed to open URI: $uri")
        out.use { outStream ->
            logFile.inputStream().use { inStream ->
                inStream.copyTo(outStream)
            }
        }
    }
}
