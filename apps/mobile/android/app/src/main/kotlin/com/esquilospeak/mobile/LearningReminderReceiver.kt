package com.esquilospeak.mobile

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import java.util.Calendar

class LearningReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val title = intent.getStringExtra(extraTitle) ?: context.getString(R.string.app_name)
        val body = intent.getStringExtra(extraBody)
            ?: context.getString(R.string.learning_reminder_body)
        createChannel(context)
        val manager = context.getSystemService(NotificationManager::class.java)
        if (manager.areNotificationsEnabled()) {
            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(context, channelId)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(context)
            }
            manager.notify(
                notificationId,
                builder
                    .setSmallIcon(R.mipmap.ic_launcher)
                    .setContentTitle(title)
                    .setContentText(body)
                    .setAutoCancel(true)
                    .build(),
            )
        }
        val preferences = context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)
        val hour = preferences.getInt(extraHour, -1)
        val minute = preferences.getInt(extraMinute, -1)
        if (hour in 0..23 && minute in 0..59) {
            LearningReminderScheduler.schedule(context, hour, minute, title, body)
        }
    }

    private fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                channelId,
                context.getString(R.string.learning_reminder_channel),
                NotificationManager.IMPORTANCE_DEFAULT,
            ),
        )
    }

    companion object {
        const val preferencesName = "learning-reminder"
        const val extraTitle = "title"
        const val extraBody = "body"
        const val extraHour = "hour"
        const val extraMinute = "minute"
        const val channelId = "learning-reminders"
        const val notificationId = 4201
    }
}

object LearningReminderScheduler {
    fun schedule(
        context: Context,
        hour: Int,
        minute: Int,
        title: String,
        body: String,
    ) {
        context.getSharedPreferences(
            LearningReminderReceiver.preferencesName,
            Context.MODE_PRIVATE,
        ).edit()
            .putInt(LearningReminderReceiver.extraHour, hour)
            .putInt(LearningReminderReceiver.extraMinute, minute)
            .putString(LearningReminderReceiver.extraTitle, title)
            .putString(LearningReminderReceiver.extraBody, body)
            .apply()
        val calendar = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (timeInMillis <= System.currentTimeMillis()) add(Calendar.DAY_OF_YEAR, 1)
        }
        val alarmManager = context.getSystemService(AlarmManager::class.java)
        alarmManager.setAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            calendar.timeInMillis,
            pendingIntent(context, title, body),
        )
    }

    fun cancel(context: Context) {
        val preferences = context.getSharedPreferences(
            LearningReminderReceiver.preferencesName,
            Context.MODE_PRIVATE,
        )
        val title = preferences.getString(
            LearningReminderReceiver.extraTitle,
            context.getString(R.string.app_name),
        ) ?: context.getString(R.string.app_name)
        val body = preferences.getString(
            LearningReminderReceiver.extraBody,
            context.getString(R.string.learning_reminder_body),
        ) ?: context.getString(R.string.learning_reminder_body)
        context.getSystemService(AlarmManager::class.java).cancel(
            pendingIntent(context, title, body),
        )
        preferences.edit().clear().apply()
    }

    private fun pendingIntent(
        context: Context,
        title: String,
        body: String,
    ): PendingIntent {
        val intent = Intent(context, LearningReminderReceiver::class.java)
            .putExtra(LearningReminderReceiver.extraTitle, title)
            .putExtra(LearningReminderReceiver.extraBody, body)
        return PendingIntent.getBroadcast(
            context,
            LearningReminderReceiver.notificationId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
