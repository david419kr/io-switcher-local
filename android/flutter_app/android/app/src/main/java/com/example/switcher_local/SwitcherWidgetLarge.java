package com.example.switcher_local;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.Context;
import android.content.Intent;
import android.widget.RemoteViews;

public class SwitcherWidgetLarge extends AppWidgetProvider {

    private static final String ACTION_SWITCH1_ON = "com.example.switcher_local.SWITCH1_ON_L";
    private static final String ACTION_SWITCH1_OFF = "com.example.switcher_local.SWITCH1_OFF_L";
    private static final String ACTION_SWITCH2_ON = "com.example.switcher_local.SWITCH2_ON_L";
    private static final String ACTION_SWITCH2_OFF = "com.example.switcher_local.SWITCH2_OFF_L";

    @Override
    public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds) {
        for (int appWidgetId : appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId);
        }
    }

    private void updateAppWidget(Context context, AppWidgetManager appWidgetManager, int appWidgetId) {
        RemoteViews views = new RemoteViews(context.getPackageName(), getResId(context, "layout", "widget_large"));

        // Switch1 ON
        Intent s1OnIntent = new Intent(context, SwitcherWidgetLarge.class);
        s1OnIntent.setAction(ACTION_SWITCH1_ON);
        PendingIntent s1OnPI = PendingIntent.getBroadcast(context, 11, s1OnIntent, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        views.setOnClickPendingIntent(getResId(context, "id", "switch1_on"), s1OnPI);

        // Switch1 OFF
        Intent s1OffIntent = new Intent(context, SwitcherWidgetLarge.class);
        s1OffIntent.setAction(ACTION_SWITCH1_OFF);
        PendingIntent s1OffPI = PendingIntent.getBroadcast(context, 12, s1OffIntent, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        views.setOnClickPendingIntent(getResId(context, "id", "switch1_off"), s1OffPI);

        // Switch2 ON
        Intent s2OnIntent = new Intent(context, SwitcherWidgetLarge.class);
        s2OnIntent.setAction(ACTION_SWITCH2_ON);
        PendingIntent s2OnPI = PendingIntent.getBroadcast(context, 21, s2OnIntent, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        views.setOnClickPendingIntent(getResId(context, "id", "switch2_on"), s2OnPI);

        // Switch2 OFF
        Intent s2OffIntent = new Intent(context, SwitcherWidgetLarge.class);
        s2OffIntent.setAction(ACTION_SWITCH2_OFF);
        PendingIntent s2OffPI = PendingIntent.getBroadcast(context, 22, s2OffIntent, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        views.setOnClickPendingIntent(getResId(context, "id", "switch2_off"), s2OffPI);

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
        } else if (ACTION_SWITCH2_ON.equals(action)) {
            launchFlutterTask(context, "2", "on");
        } else if (ACTION_SWITCH2_OFF.equals(action)) {
            launchFlutterTask(context, "2", "off");
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

    private int getResId(Context context, String type, String resName) {
        return context.getResources().getIdentifier(resName, type, context.getPackageName());
    }
}
