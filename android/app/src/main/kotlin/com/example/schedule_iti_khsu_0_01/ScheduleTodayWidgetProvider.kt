package com.example.schedule_iti_khsu_0_01

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class ScheduleTodayWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val title = widgetData.getString(
            "schedule_widget_title",
            "Расписание на сегодня"
        ) ?: "Расписание на сегодня"

        val date = widgetData.getString(
            "schedule_widget_date",
            ""
        ) ?: ""

        for (widgetId in appWidgetIds) {
            val intent = Intent(context, ScheduleTodayWidgetService::class.java)
            intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)

            val views = RemoteViews(context.packageName, R.layout.schedule_today_widget)
            views.setTextViewText(R.id.widget_title, title)
            views.setTextViewText(R.id.widget_date, date)
            views.setRemoteAdapter(R.id.widget_list, intent)
            views.setEmptyView(R.id.widget_list, R.id.widget_empty)

            val launchIntent: PendingIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java
            )
            views.setOnClickPendingIntent(R.id.widget_root, launchIntent)

            appWidgetManager.updateAppWidget(widgetId, views)
            appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_list)
        }
    }

    companion object {
        fun updateAllWidgets(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, ScheduleTodayWidgetProvider::class.java)
            val ids = manager.getAppWidgetIds(componentName)
            if (ids.isNotEmpty()) {
                manager.notifyAppWidgetViewDataChanged(ids, R.id.widget_list)
            }
        }
    }
}