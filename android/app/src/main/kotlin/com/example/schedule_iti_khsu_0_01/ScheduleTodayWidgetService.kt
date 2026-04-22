package com.example.schedule_iti_khsu_0_01

import android.content.Intent
import android.widget.RemoteViewsService

class ScheduleTodayWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return ScheduleTodayWidgetFactory(applicationContext, intent)
    }
}