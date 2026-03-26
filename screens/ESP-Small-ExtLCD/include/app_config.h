#pragma once

// Most 0.91-inch SSD1306 modules are 128x32 on address 0x3C.
#define OLED_WIDTH 128
#define OLED_HEIGHT 32

// Default ESP32 I2C pins. Change these if your board is wired differently.
#define OLED_SDA_PIN 21
#define OLED_SCL_PIN 22

// Common OLED I2C addresses are 0x3C and 0x3D.
#define OLED_PRIMARY_ADDRESS 0x3C
#define OLED_FALLBACK_ADDRESS 0x3D

#define APP_TITLE "ESP Small LCD"

// Fill these in to connect the ESP32 to Wi-Fi.
#define APP_WIFI_SSID "MILLFI"
#define APP_WIFI_PASSWORD "ba48eab983"
#define APP_WIFI_HOSTNAME "esp-small-extlcd"
