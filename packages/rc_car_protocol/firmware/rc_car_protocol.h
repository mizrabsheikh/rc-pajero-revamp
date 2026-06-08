#pragma once

#include <Arduino.h>

static const uint8_t START_BYTE = 0xFF;
static const uint8_t TEL_START = 0xFE;

static const uint32_t SERIAL_BAUD_RATE = 115200;

static const uint8_t PIN_RPM_SENSOR = 2;
static const uint8_t PIN_HEAD_LIGHT = 3;
static const uint8_t PIN_STEERING = 4;
static const uint8_t PIN_BRAKE_LIGHT = 5;
static const uint8_t PIN_FOG_LIGHT = 6;
static const uint8_t PIN_IND_LEFT = 7;
static const uint8_t PIN_REVERSE_LIGHT = 8;
static const uint8_t PIN_IND_RIGHT = 9;
static const uint8_t PIN_MOTOR_IN1 = 10;
static const uint8_t PIN_MOTOR_EN = 11;
static const uint8_t PIN_MOTOR_IN2 = 12;
static const uint8_t PIN_BATTERY_VOLTAGE = A1;

static const uint8_t CMD_BUF_LEN = 16;
static const uint8_t IDX_HEAD_LIGHT = 0;
static const uint8_t IDX_FOG_LIGHT = 1;
static const uint8_t IDX_IND_RIGHT = 2;
static const uint8_t IDX_IND_LEFT = 3;
static const uint8_t IDX_REVERSE_LIGHT = 4;
static const uint8_t IDX_BRAKE_LIGHT = 5;
static const uint8_t IDX_HORN = 6;
static const uint8_t IDX_STEERING = 7;
static const uint8_t IDX_MOTOR_EN = 8;
static const uint8_t IDX_MOTOR_IN1 = 9;
static const uint8_t IDX_MOTOR_IN2 = 10;

static const uint8_t TEL_BUF_LEN = 8;
static const uint8_t TEL_IDX_BATTERY_H = 0;
static const uint8_t TEL_IDX_BATTERY_L = 1;
static const uint8_t TEL_IDX_RPM_H = 2;
static const uint8_t TEL_IDX_RPM_L = 3;
static const uint8_t TEL_IDX_SPEED_H = 4;
static const uint8_t TEL_IDX_SPEED_L = 5;
static const uint8_t TEL_IDX_BATTERY_PERCENT = 6;
