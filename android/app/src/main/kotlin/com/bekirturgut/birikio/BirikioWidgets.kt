package com.bekirturgut.birikio

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

abstract class BirikioWidgetBase(private val layoutId: Int) : HomeWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager,
                          ids: IntArray, data: SharedPreferences) {
        ids.forEach { id ->
            val view = RemoteViews(context.packageName, layoutId)
            fun value(key: String, fallback: String) = data.getString(key, fallback) ?: fallback
            when (layoutId) {
                R.layout.widget_mini -> {
                    view.setTextViewText(R.id.mini_percent, "${data.getInt("progress", 0)}%")
                }
                R.layout.widget_balance -> {
                    view.setTextViewText(R.id.balance_amount, value("balance", "Bakiye gizli"))
                }
                R.layout.widget_goal -> {
                    view.setTextViewText(R.id.goal_title, value("goalTitle", "Yeni hedefini belirle"))
                    view.setTextViewText(R.id.goal_percent, "${data.getInt("progress", 0)}%")
                    view.setProgressBar(R.id.goal_progress, 100, data.getInt("progress", 0).coerceIn(0, 100), false)
                }
                R.layout.widget_budget -> {
                    view.setTextViewText(R.id.budget_remaining, value("budget", "Limit belirle"))
                    view.setTextViewText(R.id.budget_spent, "Harcanan ${value("expense", "0,00 ₺")}")
                    view.setTextViewText(R.id.budget_percent,
                        if (value("budget", "Limit belirle") == "Limit belirle") "—"
                        else "%${data.getInt("budgetPercent", 0)}")
                    view.setProgressBar(R.id.budget_progress, 100, data.getInt("budgetProgress", 0).coerceIn(0, 100), false)
                }
                R.layout.widget_overview -> {
                    view.setTextViewText(R.id.overview_balance, value("balance", "Bakiye gizli"))
                    view.setTextViewText(R.id.overview_income, value("income", "0,00 ₺"))
                    view.setTextViewText(R.id.overview_expense, value("expense", "0,00 ₺"))
                    view.setTextViewText(R.id.overview_goal, "${value("goalTitle", "Yeni hedef")} · ${data.getInt("progress", 0)}%")
                    view.setProgressBar(R.id.overview_progress, 100, data.getInt("progress", 0).coerceIn(0, 100), false)
                    view.setTextViewText(R.id.overview_budget, value("budget", "Limit belirle"))
                    view.setProgressBar(R.id.overview_budget_progress, 100, data.getInt("budgetProgress", 0).coerceIn(0, 100), false)
                }
            }
            view.setOnClickPendingIntent(R.id.widget_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java))
            manager.updateAppWidget(id, view)
        }
    }
}

class BirikioMiniWidget : BirikioWidgetBase(R.layout.widget_mini)
class BirikioBalanceWidget : BirikioWidgetBase(R.layout.widget_balance)
class BirikioGoalWidget : BirikioWidgetBase(R.layout.widget_goal)
class BirikioBudgetWidget : BirikioWidgetBase(R.layout.widget_budget)
class BirikioOverviewWidget : BirikioWidgetBase(R.layout.widget_overview)
