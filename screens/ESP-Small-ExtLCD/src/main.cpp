#include <Arduino.h>
#include <Wire.h>
#include <WiFi.h>
#include <WebServer.h>
#include <Preferences.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

#include "app_config.h"

namespace {

Adafruit_SSD1306 display(OLED_WIDTH, OLED_HEIGHT, &Wire, -1);
WebServer server(80);
Preferences preferences;

struct AppConfig {
  char title[24] = APP_TITLE;
  char wifi_ssid[33] = APP_WIFI_SSID;
  char wifi_password[65] = APP_WIFI_PASSWORD;
  char hostname[33] = APP_WIFI_HOSTNAME;
};

AppConfig config;

struct AppState {
  bool display_ready = false;
  bool wifi_configured = false;
  bool wifi_connecting = false;
  char ssid[24] = "WiFi offline";
  char status_line[24] = "Idle";
  char access_line[32] = "http unavailable";
  IPAddress ip_address{};
  int32_t rssi = -100;
  uint8_t oled_page = 0;
  bool web_server_started = false;
};

AppState state;

unsigned long last_refresh_ms = 0;
unsigned long last_wifi_check_ms = 0;
unsigned long last_wifi_attempt_ms = 0;
unsigned long last_oled_page_ms = 0;

constexpr unsigned long kRefreshMs = 1000;
constexpr unsigned long kWifiRetryMs = 15000;
constexpr unsigned long kOledPageMs = 3500;

void logLine(const char* message) {
  Serial.println(message);
  Serial.flush();
}

void setLabel(char* buffer, size_t size, const char* text) {
  snprintf(buffer, size, "%s", text);
}

bool devicePresent(uint8_t address) {
  Wire.beginTransmission(address);
  return Wire.endTransmission() == 0;
}

bool wifiCredentialsPresent() {
  return strlen(config.wifi_ssid) > 0;
}

void loadConfig() {
  preferences.begin("extlcd", true);
  preferences.getString("title", config.title, sizeof(config.title));
  preferences.getString("ssid", config.wifi_ssid, sizeof(config.wifi_ssid));
  preferences.getString("pass", config.wifi_password, sizeof(config.wifi_password));
  preferences.getString("host", config.hostname, sizeof(config.hostname));
  preferences.end();
}

void saveConfig(const String& title, const String& ssid, const String& password, const String& hostname) {
  preferences.begin("extlcd", false);
  preferences.putString("title", title);
  preferences.putString("ssid", ssid);
  preferences.putString("pass", password);
  preferences.putString("host", hostname);
  preferences.end();

  setLabel(config.title, sizeof(config.title), title.c_str());
  setLabel(config.wifi_ssid, sizeof(config.wifi_ssid), ssid.c_str());
  setLabel(config.wifi_password, sizeof(config.wifi_password), password.c_str());
  setLabel(config.hostname, sizeof(config.hostname), hostname.c_str());
}

void startWifi() {
  state.wifi_configured = wifiCredentialsPresent();
  if (!state.wifi_configured) {
    WiFi.mode(WIFI_OFF);
    setLabel(state.ssid, sizeof(state.ssid), "No WiFi config");
    setLabel(state.status_line, sizeof(state.status_line), "Set SSID/PASS");
    setLabel(state.access_line, sizeof(state.access_line), "Open /config later");
    return;
  }

  WiFi.mode(WIFI_STA);
  WiFi.setHostname(config.hostname);
  WiFi.begin(config.wifi_ssid, config.wifi_password);
  state.wifi_connecting = true;
  last_wifi_attempt_ms = millis();
  setLabel(state.ssid, sizeof(state.ssid), config.wifi_ssid);
  setLabel(state.status_line, sizeof(state.status_line), "Connecting...");
  setLabel(state.access_line, sizeof(state.access_line), "Waiting for IP");
  Serial.printf("wifi: connecting to %s\n", config.wifi_ssid);
  Serial.flush();
}

void updateWifiState() {
  if (millis() - last_wifi_check_ms < 1000) {
    return;
  }

  last_wifi_check_ms = millis();
  const wl_status_t wifi_status = WiFi.status();

  if (!state.wifi_configured) {
    return;
  }

  if (wifi_status == WL_CONNECTED) {
    state.wifi_connecting = false;
    state.ip_address = WiFi.localIP();
    state.rssi = WiFi.RSSI();
    snprintf(state.ssid, sizeof(state.ssid), "%s", WiFi.SSID().c_str());
    snprintf(state.status_line, sizeof(state.status_line), "%u.%u.%u.%u",
             state.ip_address[0], state.ip_address[1], state.ip_address[2], state.ip_address[3]);
    snprintf(state.access_line, sizeof(state.access_line), "http://%u.%u.%u.%u",
             state.ip_address[0], state.ip_address[1], state.ip_address[2], state.ip_address[3]);
    return;
  }

  state.rssi = -100;
  if (state.wifi_connecting && (millis() - last_wifi_attempt_ms) < kWifiRetryMs) {
    setLabel(state.status_line, sizeof(state.status_line), "Connecting...");
  } else {
    state.wifi_connecting = false;
    setLabel(state.status_line, sizeof(state.status_line), "Disconnected");
  }
  setLabel(state.access_line, sizeof(state.access_line), "http unavailable");

  if ((millis() - last_wifi_attempt_ms) >= kWifiRetryMs) {
    startWifi();
  }
}

void drawWifiStrengthIcon(int16_t x, int16_t y) {
  int bars = 0;
  if (WiFi.status() == WL_CONNECTED) {
    if (state.rssi > -60) {
      bars = 4;
    } else if (state.rssi > -70) {
      bars = 3;
    } else if (state.rssi > -80) {
      bars = 2;
    } else if (state.rssi > -90) {
      bars = 1;
    }
  }

  for (int i = 0; i < 4; ++i) {
    const int bar_x = x + i * 3;
    const int bar_h = 2 + i * 2;
    const int bar_y = y + 7 - bar_h;
    display.drawRect(bar_x, bar_y, 2, bar_h, SSD1306_WHITE);
    if (i < bars) {
      display.fillRect(bar_x, bar_y, 2, bar_h, SSD1306_WHITE);
    }
  }
}

void drawWifiPage() {
  char rssi_line[24];

  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);
  display.setTextSize(1);

  display.setCursor(0, 0);
  display.print(config.title);
  drawWifiStrengthIcon(116, 1);

  display.setCursor(0, 8);
  display.print(state.ssid);

  display.setCursor(0, 16);
  display.print(state.status_line);

  display.setCursor(0, 24);
  if (WiFi.status() == WL_CONNECTED) {
    snprintf(rssi_line, sizeof(rssi_line), "RSSI %ld dBm", static_cast<long>(state.rssi));
  } else if (state.wifi_configured) {
    snprintf(rssi_line, sizeof(rssi_line), "RSSI --");
  } else {
    snprintf(rssi_line, sizeof(rssi_line), "SDA %d SCL %d", OLED_SDA_PIN, OLED_SCL_PIN);
  }
  display.print(rssi_line);

  display.display();
}

void drawAccessPage() {
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);
  display.setTextSize(1);

  display.setCursor(0, 0);
  display.print("Web Access");
  display.drawFastHLine(0, 10, OLED_WIDTH, SSD1306_WHITE);

  display.setCursor(0, 14);
  if (WiFi.status() == WL_CONNECTED) {
    display.print("Open in browser:");
    display.setCursor(0, 24);
    display.print(state.access_line);
  } else {
    display.print("Waiting for WiFi");
    display.setCursor(0, 24);
    display.print("No IP yet");
  }

  display.display();
}

void drawScreen() {
  if (state.oled_page == 0) {
    drawWifiPage();
  } else {
    drawAccessPage();
  }
}

String htmlHeader(const char* title) {
  String html = "<!doctype html><html><head><meta name='viewport' content='width=device-width,initial-scale=1'>";
  html += "<title>";
  html += title;
  html += "</title><style>body{font-family:system-ui;margin:24px;background:#111;color:#eee}card,form{display:block;background:#1c1c1c;padding:16px;border-radius:12px;margin:0 0 16px 0}input{width:100%;padding:10px;margin:6px 0 12px;border-radius:8px;border:1px solid #444;background:#222;color:#fff}button{padding:10px 14px;border:0;border-radius:8px;background:#2d8cff;color:#fff}a{color:#7db7ff}</style></head><body>";
  return html;
}

void handleRoot() {
  String html = htmlHeader("ESP Small LCD");
  html += "<h1>ESP Small LCD</h1>";
  html += "<card><h2>Status</h2>";
  html += "<p><strong>SSID:</strong> " + String(state.ssid) + "</p>";
  html += "<p><strong>Connection:</strong> " + String(state.status_line) + "</p>";
  html += "<p><strong>RSSI:</strong> ";
  html += (WiFi.status() == WL_CONNECTED ? String(state.rssi) + " dBm" : "--");
  html += "</p>";
  html += "<p><strong>HTTP:</strong> " + String(state.access_line) + "</p>";
  html += "<p><strong>Hostname:</strong> " + String(config.hostname) + "</p>";
  html += "<p><a href='/config'>Open configuration</a></p>";
  html += "<p><a href='/api/status'>View JSON status</a></p>";
  html += "</card></body></html>";
  server.send(200, "text/html", html);
}

void handleConfigGet() {
  String html = htmlHeader("Configuration");
  html += "<h1>Configuration</h1><form method='post' action='/config'>";
  html += "<label>Screen title</label><input name='title' maxlength='23' value='" + String(config.title) + "'>";
  html += "<label>WiFi SSID</label><input name='ssid' maxlength='32' value='" + String(config.wifi_ssid) + "'>";
  html += "<label>WiFi Password</label><input name='password' maxlength='64' value='" + String(config.wifi_password) + "'>";
  html += "<label>Hostname</label><input name='hostname' maxlength='32' value='" + String(config.hostname) + "'>";
  html += "<button type='submit'>Save</button></form><p><a href='/'>Back</a></p></body></html>";
  server.send(200, "text/html", html);
}

void handleConfigPost() {
  const String title = server.arg("title");
  const String ssid = server.arg("ssid");
  const String password = server.arg("password");
  const String hostname = server.arg("hostname");

  saveConfig(title, ssid, password, password.length() ? hostname : hostname);
  startWifi();

  String html = htmlHeader("Saved");
  html += "<h1>Saved</h1><p>Configuration stored. WiFi reconnect started.</p><p><a href='/'>Back to status</a></p></body></html>";
  server.send(200, "text/html", html);
}

void handleApiStatus() {
  String json = "{";
  json += "\"ssid\":\"" + String(state.ssid) + "\",";
  json += "\"status\":\"" + String(state.status_line) + "\",";
  json += "\"access\":\"" + String(state.access_line) + "\",";
  json += "\"rssi\":" + String(state.rssi) + ",";
  json += "\"connected\":" + String(WiFi.status() == WL_CONNECTED ? "true" : "false");
  json += "}";
  server.send(200, "application/json", json);
}

void startWebServer() {
  if (state.web_server_started) {
    return;
  }

  server.on("/", HTTP_GET, handleRoot);
  server.on("/config", HTTP_GET, handleConfigGet);
  server.on("/config", HTTP_POST, handleConfigPost);
  server.on("/api/status", HTTP_GET, handleApiStatus);
  server.begin();
  state.web_server_started = true;
  logLine("web: server started on port 80");
}

void initialiseDisplay() {
  logLine("boot: wire begin");
  Wire.begin(OLED_SDA_PIN, OLED_SCL_PIN);
  Wire.setClock(100000);

  uint8_t address = 0;
  if (devicePresent(OLED_PRIMARY_ADDRESS)) {
    address = OLED_PRIMARY_ADDRESS;
  } else if (devicePresent(OLED_FALLBACK_ADDRESS)) {
    address = OLED_FALLBACK_ADDRESS;
  } else {
    logLine("boot: oled not detected");
    return;
  }

  Serial.printf("boot: oled found at 0x%02X\n", address);
  Serial.flush();

  if (!display.begin(SSD1306_SWITCHCAPVCC, address)) {
    logLine("boot: display.begin failed");
    return;
  }

  state.display_ready = true;
  logLine("boot: display init complete");
}

}  // namespace

void setup() {
  Serial.begin(115200);
  delay(250);
  logLine("boot: serial ready");

  loadConfig();
  initialiseDisplay();
  startWifi();

  if (state.display_ready) {
    drawScreen();
    logLine("boot: screen drawn");
  }
}

void loop() {
  updateWifiState();
  if (WiFi.status() == WL_CONNECTED) {
    startWebServer();
  }
  if (state.web_server_started) {
    server.handleClient();
  }

  if (!state.display_ready) {
    delay(100);
    return;
  }

  if (millis() - last_oled_page_ms >= kOledPageMs) {
    last_oled_page_ms = millis();
    state.oled_page = (state.oled_page + 1) % 2;
  }

  if (millis() - last_refresh_ms >= kRefreshMs) {
    last_refresh_ms = millis();
    drawScreen();
  }

  delay(20);
}
