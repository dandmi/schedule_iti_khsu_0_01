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
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class ScheduleTodayWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        updateWidgetViews(context, appWidgetManager, appWidgetIds, widgetData)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        val action = intent.action
        if (
            action == Intent.ACTION_DATE_CHANGED ||
            action == Intent.ACTION_TIME_CHANGED ||
            action == Intent.ACTION_TIMEZONE_CHANGED ||
            action == AppWidgetManager.ACTION_APPWIDGET_UPDATE
        ) {
            updateAllWidgets(context)
        }
    }

    private fun updateWidgetViews(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val targetName = widgetData.getString(
            "schedule_widget_target_name",
            "Расписание"
        ) ?: "Расписание"

        val currentDateKey = currentDateKey()
        val payloadJson = widgetData.getString(
            "schedule_widget_payload_json",
            "{}"
        ) ?: "{}"

        var dateLabel = ""
        try {
            val root = JSONObject(payloadJson)
            if (root.has(currentDateKey)) {
                val dayObject = root.getJSONObject(currentDateKey)
                dateLabel = dayObject.optString("dateLabel", "")
            }
        } catch (_: Exception) {
        }

        for (widgetId in appWidgetIds) {
            val serviceIntent = Intent(context, ScheduleTodayWidgetService::class.java)
            serviceIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            serviceIntent.putExtra("date_key", currentDateKey)
            serviceIntent.data = android.net.Uri.parse(serviceIntent.toUri(Intent.URI_INTENT_SCHEME))

            val views = RemoteViews(context.packageName, R.layout.schedule_today_widget)
            views.setTextViewText(R.id.widget_title, "Сегодня • $targetName")
            views.setTextViewText(R.id.widget_date, dateLabel)
            views.setRemoteAdapter(R.id.widget_list, serviceIntent)
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
            if (ids.isEmpty()) return

            val prefs = es.antonborri.home_widget.HomeWidgetPlugin.getData(context)
            val provider = ScheduleTodayWidgetProvider()
            provider.updateWidgetViews(context, manager, ids, prefs)
        }

        private fun currentDateKey(): String {
            val formatter = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
            return formatter.format(Date())
        }
    }
}