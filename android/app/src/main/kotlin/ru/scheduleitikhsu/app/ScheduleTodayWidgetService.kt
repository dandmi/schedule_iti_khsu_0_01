package ru.scheduleitikhsu.app

import android.content.Intent
import android.widget.RemoteViewsService

class ScheduleTodayWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return ScheduleTodayWidgetFactory(applicationContext, intent)
    }
}