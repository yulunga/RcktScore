package com.hitnscore.mobile.feature.settings

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.res.stringResource
import com.hitnscore.mobile.R
import com.hitnscore.mobile.feature.reports.CsvExportControls
import com.hitnscore.mobile.feature.reports.ReportingPeriodRow

/** Club › Data (admins, as iOS): an aggregate CSV report of club, court and match usage. */
@Composable
internal fun ClubDataPage(organizationId: Int) {
    var period by rememberSaveable { mutableIntStateOf(30) }
    EditorCard(stringResource(R.string.club_data_title), iconRes = R.drawable.ic_tab_analytics) {
        Text(stringResource(R.string.club_data_body), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        ReportingPeriodRow(period) { period = it }
        CsvExportControls(organizationId, period)
        EditorNote(stringResource(R.string.club_data_note))
    }
}
