package com.hitnscore.mobile.feature.reports

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import com.hitnscore.mobile.HitNScoreApplication
import com.hitnscore.mobile.R
import com.hitnscore.mobile.core.network.ApiResult
import java.io.File
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** Reporting periods, as iOS: days, with 0 meaning all time. */
val REPORTING_PERIODS = listOf(7 to "7 days", 30 to "30 days", 90 to "90 days", 365 to "12 months", 0 to "All time")

/** "Reporting period" with a drop-down, as iOS. */
@Composable
fun ReportingPeriodRow(days: Int, onSelect: (Int) -> Unit) {
    var open by remember { mutableStateOf(false) }
    val label = REPORTING_PERIODS.firstOrNull { it.first == days }?.second ?: "$days days"
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(stringResource(R.string.analytics_period), style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
        Box {
            TextButton(onClick = { open = true }) {
                Text(label, style = MaterialTheme.typography.titleMedium)
                Icon(painterResource(R.drawable.ic_expand_more), contentDescription = null)
            }
            DropdownMenu(expanded = open, onDismissRequest = { open = false }) {
                REPORTING_PERIODS.forEach { (value, text) ->
                    DropdownMenuItem(text = { Text(text) }, onClick = {
                        open = false
                        onSelect(value)
                    })
                }
            }
        }
    }
}

/**
 * Prepare a CSV report for [organizationId] and [periodDays], then share it or save it to the
 * phone (iOS "Prepare CSV report" + "Share CSV"). The file is kept in the app's cache only.
 */
@Composable
fun CsvExportControls(organizationId: Int, periodDays: Int, isOnline: Boolean = true) {
    val context = LocalContext.current
    val api = remember(context) { (context.applicationContext as HitNScoreApplication).container.analyticsExportApi }
    val scope = rememberCoroutineScope()
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    // The prepared report, tied to the organisation and period it was made for.
    var prepared by remember { mutableStateOf<Prepared?>(null) }
    val report = prepared?.takeIf { it.organizationId == organizationId && it.periodDays == periodDays }

    val saver = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("text/csv")) { uri ->
        val file = report?.file ?: return@rememberLauncherForActivityResult
        if (uri != null) {
            scope.launch {
                val ok = withContext(Dispatchers.IO) {
                    runCatching { context.contentResolver.openOutputStream(uri)?.use { out -> file.inputStream().use { it.copyTo(out) } } }.isSuccess
                }
                if (!ok) error = context.getString(R.string.export_save_failed)
            }
        }
    }

    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
            OutlinedButton(
                onClick = {
                    if (!isOnline) {
                        error = context.getString(R.string.export_offline)
                    } else {
                    busy = true
                    error = null
                    scope.launch {
                        when (val result = api.export(organizationId, periodDays)) {
                            is ApiResult.Success -> {
                                val file = withContext(Dispatchers.IO) { runCatching { writeReport(context, result.value.filename, result.value.csvContent) }.getOrNull() }
                                if (file == null) error = context.getString(R.string.export_failed) else prepared = Prepared(organizationId, periodDays, file)
                            }
                            is ApiResult.Failure -> error = result.error.message
                        }
                        busy = false
                    }
                    }
                },
                enabled = !busy,
            ) {
                if (busy) {
                    CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp)
                } else {
                    Text(stringResource(R.string.export_prepare))
                }
            }
            if (report != null) {
                Button(onClick = { share(context, report.file) }) { Text(stringResource(R.string.export_share)) }
                TextButton(onClick = { saver.launch(report.file.name) }) { Text(stringResource(R.string.export_save)) }
            }
        }
        error?.let { Text(it, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error) }
    }
}

private data class Prepared(val organizationId: Int, val periodDays: Int, val file: File)

private fun writeReport(context: Context, filename: String, csv: String): File {
    val dir = File(context.cacheDir, "exports").apply { mkdirs() }
    // Keep only the latest report; never let the server's name leave the folder.
    dir.listFiles()?.forEach { it.delete() }
    val safe = filename.substringAfterLast('/').replace(Regex("[^A-Za-z0-9._-]"), "-").ifBlank { "hitnscore-report.csv" }
    return File(dir, if (safe.endsWith(".csv", ignoreCase = true)) safe else "$safe.csv").apply { writeText(csv) }
}

private fun share(context: Context, file: File) {
    val uri: Uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
    val send = Intent(Intent.ACTION_SEND)
        .setType("text/csv")
        .putExtra(Intent.EXTRA_STREAM, uri)
        .putExtra(Intent.EXTRA_SUBJECT, file.name)
        .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    context.startActivity(Intent.createChooser(send, null))
}
