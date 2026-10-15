package com.farfarfun.funclash.service.models

data class NotificationParams(
    val title: String = "FunClash",
    val stopText: String = "STOP",
    val onlyStatisticsProxy: Boolean = false,
    val showStopAction: Boolean = true,
)
