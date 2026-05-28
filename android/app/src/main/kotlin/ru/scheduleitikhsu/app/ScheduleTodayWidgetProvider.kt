package ru.scheduleitikhsu.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
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

        val widgetData = HomeWidgetPlugin.getData(context)

        when (intent.action) {
            ACTION_PREVIOUS_DAY -> {
                changeDayOffset(context, widgetData, -1)
            }

            ACTION_NEXT_DAY -> {
                changeDayOffset(context, widgetData, 1)
            }

            ACTION_TODAY -> {
                widgetData.edit().putInt(KEY_DAY_OFFSET, 0).apply()
                updateAllWidgets(context)
            }

            Intent.ACTION_DATE_CHANGED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            AppWidgetManager.ACTION_APPWIDGET_UPDATE -> {
                // При наступлении нового дня возвращаем виджет к сегодняшней дате.
                widgetData.edit().putInt(KEY_DAY_OFFSET, 0).apply()
                updateAllWidgets(context)
            }
        }
    }

    private fun changeDayOffset(
        context: Context,
        widgetData: SharedPreferences,
        delta: Int
    ) {
        val newOffset = (readDayOffset(widgetData) + delta).coerceIn(
            MIN_DAY_OFFSET,
            MAX_DAY_OFFSET
        )

        widgetData.edit().putInt(KEY_DAY_OFFSET, newOffset).apply()
        updateAllWidgets(context)
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

        val dayOffset = readDayOffset(widgetData)
        val selectedDateKey = dateKeyForOffset(dayOffset)
        val payloadJson = widgetData.getString(
            "schedule_widget_payload_json",
            "{}"
        ) ?: "{}"

        var dateLabel = formatDateForOffset(dayOffset)
        try {
            val root = JSONObject(payloadJson)
            if (root.has(selectedDateKey)) {
                val dayObject = root.getJSONObject(selectedDateKey)
                dateLabel = dayObject.optString("dateLabel", dateLabel)
            }
        } catch (_: Exception) {
        }

        for (widgetId in appWidgetIds) {
            val serviceIntent = Intent(context, ScheduleTodayWidgetService::class.java)
            serviceIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            serviceIntent.putExtra("date_key", selectedDateKey)
            serviceIntent.data = Uri.parse(serviceIntent.toUri(Intent.URI_INTENT_SCHEME))

            val views = RemoteViews(context.packageName, R.layout.schedule_today_widget)
            views.setTextViewText(R.id.widget_title, "${dayTitle(dayOffset)} • $targetName")
            views.setTextViewText(R.id.widget_date, dateLabel)
            views.setRemoteAdapter(R.id.widget_list, serviceIntent)
            views.setEmptyView(R.id.widget_list, R.id.widget_empty)

            val launchIntent: PendingIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java
            )
            views.setOnClickPendingIntent(R.id.widget_root, launchIntent)

            views.setOnClickPendingIntent(
                R.id.widget_previous_day,
                widgetActionPendingIntent(
                    context = context,
                    widgetId = widgetId,
                    action = ACTION_PREVIOUS_DAY,
                    requestCodeSalt = 10
                )
            )
            views.setOnClickPendingIntent(
                R.id.widget_next_day,
                widgetActionPendingIntent(
                    context = context,
                    widgetId = widgetId,
                    action = ACTION_NEXT_DAY,
                    requestCodeSalt = 20
                )
            )
            views.setOnClickPendingIntent(
                R.id.widget_date,
                widgetActionPendingIntent(
                    context = context,
                    widgetId = widgetId,
                    action = ACTION_TODAY,
                    requestCodeSalt = 30
                )
            )

            appWidgetManager.updateAppWidget(widgetId, views)
            appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_list)
        }
    }

    companion object {
        private const val KEY_DAY_OFFSET = "schedule_widget_day_offset"

        private const val ACTION_PREVIOUS_DAY =
            "ru.scheduleitikhsu.app.widget.PREVIOUS_DAY"
        private const val ACTION_NEXT_DAY =
            "ru.scheduleitikhsu.app.widget.NEXT_DAY"
        private const val ACTION_TODAY =
            "ru.scheduleitikhsu.app.widget.TODAY"

        private const val MIN_DAY_OFFSET = -2
        private const val MAX_DAY_OFFSET = 7

        fun updateAllWidgets(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, ScheduleTodayWidgetProvider::class.java)
            val ids = manager.getAppWidgetIds(componentName)
            if (ids.isEmpty()) return

            val prefs = HomeWidgetPlugin.getData(context)
            val provider = ScheduleTodayWidgetProvider()
            provider.updateWidgetViews(context, manager, ids, prefs)
        }

        private fun readDayOffset(widgetData: SharedPreferences): Int {
            return widgetData.getInt(KEY_DAY_OFFSET, 0).coerceIn(
                MIN_DAY_OFFSET,
                MAX_DAY_OFFSET
            )
        }

        private fun widgetActionPendingIntent(
            context: Context,
            widgetId: Int,
            action: String,
            requestCodeSalt: Int
        ): PendingIntent {
            val intent = Intent(context, ScheduleTodayWidgetProvider::class.java).apply {
                this.action = action
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            }

            return PendingIntent.getBroadcast(
                context,
                widgetId + requestCodeSalt,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        private fun dateKeyForOffset(offset: Int): String {
            val formatter = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
            return formatter.format(dateForOffset(offset))
        }

        private fun formatDateForOffset(offset: Int): String {
            val formatter = SimpleDateFormat("dd.MM.yyyy", Locale.getDefault())
            return formatter.format(dateForOffset(offset))
        }

        private fun dateForOffset(offset: Int): Date {
            return Calendar.getInstance().apply {
                add(Calendar.DAY_OF_YEAR, offset)
            }.time
        }

        private fun dayTitle(offset: Int): String {
            return when {
                offset == 0 -> "Сегодня"
                offset == 1 -> "Завтра"
                offset == -1 -> "Вчера"
                offset > 1 -> "Через $offset дн."
                else -> "${-offset} дн. назад"
            }
        }
    }
}
