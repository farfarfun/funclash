package com.farfarfun.funclash.models

data class InstalledPackage(
    val packageName: String,
    val label: String,
    val system: Boolean,
    val internet: Boolean,
    val lastUpdateTime: Long,
)
