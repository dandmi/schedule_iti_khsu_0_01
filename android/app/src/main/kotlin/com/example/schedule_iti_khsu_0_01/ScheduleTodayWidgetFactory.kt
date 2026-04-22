package com.example.schedule_iti_khsu_0_01

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray

class ScheduleTodayWidgetFactory(
    private val context: Context,
    intent: Intent
) : RemoteViewsService.RemoteViewsFactory {

    private val items = mutableListOf<Pair<String, String>>()
    private val appWidgetId: Int =
        intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)

    override fun onCreate() {
        loadData()
    }

    override fun onDataSetChanged() {
        loadData()
    }

    override fun onDestroy() {
        items.clear()
    }

    override fun getCount(): Int = items.size

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.schedule_today_widget_item)

        if (position in items.indices) {
            val item = items[position]
            views.setTextViewText(R.id.widget_item_title, item.first)
            views.setTextViewText(R.id.widget_item_subtitle, item.second)
        }

        return views
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = true

    private fun loadData() {
        items.clear()

        val prefs = HomeWidgetPlugin.getData(context)
        val rawJson = prefs.getString("schedule_widget_items_json", "[]") ?: "[]"

        try {
            val array = JSONArray(rawJson)
            for (i in 0 until array.length()) {
                val obj = array.getJSONObject(i)
                val title = obj.optString("title", "")
                val subtitle = obj.optString("subtitle", "")
                items.add(title to subtitle)
            }
        } catch (_: Exception) {
            // ignore parse errors
        }

        if (items.isEmpty()) {
            items.add("Нет занятий" to "")
        }
    }
}