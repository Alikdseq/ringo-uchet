import { httpClient } from "./httpClient";
import type {
  NotificationLog,
  NotificationPreferences,
} from "@/shared/types/notifications";
import {
  mapNotificationLogFromApi,
  mapNotificationPreferencesFromApi,
  mapNotificationPreferencesToApi,
} from "@/shared/types/notifications";

export const NotificationsApi = {
  async getPreferences(): Promise<NotificationPreferences> {
    const response = await httpClient.get("/notifications/preferences/preferences/");
    return mapNotificationPreferencesFromApi(response.data);
  },

  async updatePreferences(
    prefs: NotificationPreferences,
  ): Promise<NotificationPreferences> {
    const payload = mapNotificationPreferencesToApi(prefs);
    const response = await httpClient.post(
      "/notifications/preferences/preferences/",
      payload,
    );
    return mapNotificationPreferencesFromApi(response.data);
  },

  async getLogs(): Promise<NotificationLog[]> {
    const response = await httpClient.get("/notifications/preferences/logs/");
    const raw = response.data;
    if (!Array.isArray(raw)) {
      return [];
    }
    return raw.map((item) => mapNotificationLogFromApi(item));
  },
};


