package com.hitnscore.mobile.feature.scoring

import androidx.compose.ui.graphics.Color

/** Shirt colours shared with iOS and the web client. Light shirts use dark text. */
data class ShirtColor(val id: String, val label: String, val fill: Color, val isLight: Boolean = false) {
    val onFill: Color get() = if (isLight) Color(0xFF102A43) else Color.White
}

object ShirtColors {
    val all = listOf(
        ShirtColor("navy", "Navy", Color(0xFF123C69)),
        ShirtColor("blue", "Blue", Color(0xFF1274D0)),
        ShirtColor("red", "Red", Color(0xFFD64545)),
        ShirtColor("green", "Green", Color(0xFF2F855A)),
        ShirtColor("black", "Black", Color(0xFF1F2933)),
        ShirtColor("white", "White", Color.White, isLight = true),
        ShirtColor("yellow", "Yellow", Color(0xFFF7D154), isLight = true),
        ShirtColor("orange", "Orange", Color(0xFFD9822B)),
        ShirtColor("purple", "Purple", Color(0xFF7C3AED)),
        ShirtColor("pink", "Pink", Color(0xFFD9468F), isLight = true),
    )

    fun of(id: String?): ShirtColor = all.firstOrNull { it.id == id?.lowercase() } ?: all.first()
}
