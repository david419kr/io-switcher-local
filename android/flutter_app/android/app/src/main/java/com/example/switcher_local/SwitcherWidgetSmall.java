package com.example.switcher_local;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.widget.RemoteViews;

import io.flutter.embedding.android.FlutterActivity;

public class SwitcherWidgetSmall extends AppWidgetProvider {

    private static final String ACTION_SWITCH1_ON = "com.example.switcher_local.SWITCH1_ON";
    private static final String ACTION_SWITCH1_OFF = "com.example.switcher_local.SWITCH1_OFF";

    @Override
    public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds) {
        for (int appWidgetId : appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId);
        }
    }

    private void updateAppWidget(Context context, AppWidgetManager appWidgetManager, int appWidgetId) {
        RemoteViews views = new RemoteViews(context.getPackageName(), io.flutter.plugins.GeneratedPluginRegistrant.class.getPackage().getName().replace(".plugins", "") + ":layout/widget_small");

        // Switch1 ON button
        Intent switch1OnIntent = new Intent(context, SwitcherWidgetSmall.class);
        switch1OnIntent.setAction(ACTION_SWITCH1_ON);
        PendingIntent switch1OnPendingIntent = PendingIntent.getBroadcast(context, 1, switch1OnIntent, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        views.setOnClickPendingIntent(getResId(context, "switch1_on"), switch1OnPendingIntent);

        // Switch1 OFF button
        Intent switch1OffIntent = new Intent(context, SwitcherWidgetSmall.class);
        switch1OffIntent.setAction(ACTION_SWITCH1_OFF);
        PendingIntent switch1OffPendingIntent = PendingIntent.getBroadcast(context, 2, switch1OffIntent, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        views.setOnClickPendingIntent(getResId(context, "switch1_off"), switch1OffPendingIntent);

        appWidgetManager.updateAppWidget(appWidgetId, views);
    }

    @Override
    public void onReceive(Context context, Intent intent) {
        super.onReceive(context, intent);
        String action = intent.getAction();
        
        if (ACTION_SWITCH1_ON.equals(action)) {
            launchFlutterTask(context, "1", "on");
        } else if (ACTION_SWITCH1_OFF.equals(action)) {
            launchFlutterTask(context, "1", "off");
        }
    }

    private void launchFlutterTask(Context context, String switchNum, String action) {
        Intent intent = new Intent(context, MainActivity.class);
        intent.setAction("WIDGET_ACTION");
        intent.putExtra("switch", switchNum);
        intent.putExtra("action", action);
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        context.startActivity(intent);
    }

    private int getResId(Context context, String resName) {
        return context.getResources().getIdentifier(resName, "id", context.getPackageName());
    }
}
