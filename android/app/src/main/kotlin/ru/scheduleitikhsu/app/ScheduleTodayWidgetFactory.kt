package ru.scheduleitikhsu.app

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class ScheduleTodayWidgetFactory(
    private val context: Context,
    intent: Intent
) : RemoteViewsService.RemoteViewsFactory {

    private val items = mutableListOf<Pair<String, String>>()
    private val forcedDateKey: String? = intent.getStringExtra("date_key")

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
        val rawJson = prefs.getString("schedule_widget_payload_json", "{}") ?: "{}"
        val dateKey = forcedDateKey ?: currentDateKey()

        try {
            val root = JSONObject(rawJson)

            if (root.has(dateKey)) {
                val dayObject = root.getJSONObject(dateKey)
                val array = dayObject.optJSONArray("items") ?: JSONArray()

                for (i in 0 until array.length()) {
                    val obj = array.getJSONObject(i)
                    val title = obj.optString("title", "")
                    val subtitle = obj.optString("subtitle", "")
                    items.add(title to subtitle)
                }
            }
        } catch (_: Exception) {
        }

        if (items.isEmpty()) {
            items.add("Откройте приложение для обновления виджета" to "")
        }
    }

    private fun currentDateKey(): String {
        val formatter = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
        return formatter.format(Date())
    }
}