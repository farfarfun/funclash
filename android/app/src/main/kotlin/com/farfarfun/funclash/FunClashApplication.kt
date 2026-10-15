package com.farfarfun.funclash

import android.app.Application
import android.content.Context
import com.farfarfun.funclash.common.GlobalState

class FunClashApplication : Application() {
    override fun attachBaseContext(base: Context?) {
        super.attachBaseContext(base)
        GlobalState.init(this)
    }
}
