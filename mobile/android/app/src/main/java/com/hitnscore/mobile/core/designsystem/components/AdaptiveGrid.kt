package com.hitnscore.mobile.core.designsystem.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/** Tablets (600 dp wide and up, e.g. the Pritom Tab 10) show two match cards per row. */
@Composable
fun matchCardColumns(): Int = if (LocalConfiguration.current.screenWidthDp >= 600) 2 else 1

/** Cards in [columns] equal-width columns; a short last row keeps its cards the same width. */
@Composable
fun <T> CardGrid(
    items: List<T>,
    columns: Int = matchCardColumns(),
    spacing: Dp = 12.dp,
    card: @Composable (T) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(spacing)) {
        items.chunked(columns.coerceAtLeast(1)).forEach { row ->
            CardRow(row, columns, spacing, card)
        }
    }
}

/** One row of [CardGrid], also used by lazy lists that chunk their own items. */
@Composable
fun <T> CardRow(row: List<T>, columns: Int, spacing: Dp = 12.dp, card: @Composable (T) -> Unit) {
    if (columns <= 1) {
        row.forEach { card(it) }
        return
    }
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(spacing)) {
        row.forEach { item -> Box(Modifier.weight(1f)) { card(item) } }
        repeat(columns - row.size) { Spacer(Modifier.weight(1f)) }
    }
}
