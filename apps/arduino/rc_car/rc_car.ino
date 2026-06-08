#include <Servo.h>
#include "../../../packages/rc_car_protocol/firmware/rc_car_protocol.h"

// ── Framing ──────────────────────────────────────────────────

// ── Pin map ──────────────────────────────────────────────────



// ── Command buffer indices ────────────────────────────────────

// ── Telemetry buffer indices ──────────────────────────────────

// ── RPM / Speed ───────────────────────────────────────────────
static const float WHEEL_CIRCUMFERENCE_M = 0.08 ; // meters, adjust to your wheel
static volatile uint16_t _pulseCount = 0;
static uint16_t _rpm = 0;
static float _speedMs = 0.0f;
static uint32_t _lastRpmCalc = 0;
static const uint16_t RPM_CALC_INTERVAL = 1000;  // ms


// ── Globals ──────────────────────────────────────────────────
Servo steeringServo;
uint8_t cmdBuf[CMD_BUF_LEN];
uint8_t prevCmdBuf[CMD_BUF_LEN];

static uint8_t _rxBuf[CMD_BUF_LEN];
static uint8_t _rxPos = 0;
static bool _rxSynced = false;



void onRpmPulse() {
  _pulseCount++;
}

// ── Setup ────────────────────────────────────────────────────
void setup() {
  Serial.begin(SERIAL_BAUD_RATE);
  steeringServo.attach(PIN_STEERING);

  pinMode(PIN_FOG_LIGHT, OUTPUT);
  pinMode(PIN_HEAD_LIGHT, OUTPUT);
  pinMode(PIN_IND_RIGHT, OUTPUT);
  pinMode(PIN_IND_LEFT, OUTPUT);
  pinMode(PIN_REVERSE_LIGHT, OUTPUT);
  pinMode(PIN_BRAKE_LIGHT, OUTPUT);
  pinMode(PIN_MOTOR_IN1, OUTPUT);
  pinMode(PIN_MOTOR_EN, OUTPUT);
  pinMode(PIN_MOTOR_IN2, OUTPUT);

  pinMode(PIN_BATTERY_VOLTAGE, INPUT);

  pinMode(PIN_RPM_SENSOR, INPUT_PULLUP);
  // attachInterrupt(digitalPinToInterrupt(PIN_RPM_SENSOR), onRpmPulse, CHANGE);
  attachInterrupt(digitalPinToInterrupt(PIN_RPM_SENSOR), onRpmPulse, RISING);

  memset(cmdBuf, 0, sizeof(cmdBuf));
  memset(prevCmdBuf, 0, sizeof(prevCmdBuf));
  steeringServo.write(50);

  while (Serial.available()) Serial.read();
}

// ── Main loop ────────────────────────────────────────────────
void loop() {
  receiveCmdBuffer();
  applyCommands();
  updateRpm();
  sendTelemetry();
  // printDebug();
}

// ── Framed receive ───────────────────────────────────────────
void receiveCmdBuffer() {
  while (Serial.available() > 0) {
    uint8_t b = (uint8_t)Serial.read();

    if (!_rxSynced) {
      if (b == START_BYTE) {
        _rxSynced = true;
        _rxPos = 0;
      }
      continue;
    }

    if (b == START_BYTE) {
      _rxPos = 0;
      continue;
    }

    _rxBuf[_rxPos++] = b;

    if (_rxPos == CMD_BUF_LEN) {
      memcpy(cmdBuf, _rxBuf, CMD_BUF_LEN);
      _rxPos = 0;
      _rxSynced = false;
    }
  }
}

// ── Apply command buffer to hardware ─────────────────────────
void applyCommands() {
  if (cmdBuf[IDX_HEAD_LIGHT] != prevCmdBuf[IDX_HEAD_LIGHT])
    analogWrite(PIN_HEAD_LIGHT, cmdBuf[IDX_HEAD_LIGHT]);

  if (cmdBuf[IDX_FOG_LIGHT] != prevCmdBuf[IDX_FOG_LIGHT])
    digitalWrite(PIN_FOG_LIGHT, cmdBuf[IDX_FOG_LIGHT] ? HIGH : LOW);

  if (cmdBuf[IDX_IND_RIGHT] != prevCmdBuf[IDX_IND_RIGHT])
    digitalWrite(PIN_IND_RIGHT, cmdBuf[IDX_IND_RIGHT] ? HIGH : LOW);

  if (cmdBuf[IDX_IND_LEFT] != prevCmdBuf[IDX_IND_LEFT])
    digitalWrite(PIN_IND_LEFT, cmdBuf[IDX_IND_LEFT] ? HIGH : LOW);

  if (cmdBuf[IDX_REVERSE_LIGHT] != prevCmdBuf[IDX_REVERSE_LIGHT])
    digitalWrite(PIN_REVERSE_LIGHT, cmdBuf[IDX_REVERSE_LIGHT] ? HIGH : LOW);

  if (cmdBuf[IDX_BRAKE_LIGHT] != prevCmdBuf[IDX_BRAKE_LIGHT])
    analogWrite(PIN_BRAKE_LIGHT, cmdBuf[IDX_BRAKE_LIGHT]);

  if (cmdBuf[IDX_STEERING] != prevCmdBuf[IDX_STEERING])
    steeringServo.write(cmdBuf[IDX_STEERING]);

  if (cmdBuf[IDX_MOTOR_EN] != prevCmdBuf[IDX_MOTOR_EN])
    analogWrite(PIN_MOTOR_EN, cmdBuf[IDX_MOTOR_EN]);

  if (cmdBuf[IDX_MOTOR_IN1] != prevCmdBuf[IDX_MOTOR_IN1])
    digitalWrite(PIN_MOTOR_IN1, cmdBuf[IDX_MOTOR_IN1] ? HIGH : LOW);

  if (cmdBuf[IDX_MOTOR_IN2] != prevCmdBuf[IDX_MOTOR_IN2])
    digitalWrite(PIN_MOTOR_IN2, cmdBuf[IDX_MOTOR_IN2] ? HIGH : LOW);

  memcpy(prevCmdBuf, cmdBuf, CMD_BUF_LEN);
}

void sendTelemetry() {
  static const uint8_t FRAME_LEN = TEL_BUF_LEN + 1;
  static uint16_t _telSkip = 0;
  if (++_telSkip < 100) return;
  _telSkip = 0;
  if (Serial.availableForWrite() < FRAME_LEN) return;

  uint16_t battery = analogRead(PIN_BATTERY_VOLTAGE);
  uint16_t speedMs = (uint16_t)(_speedMs * 100.0f);

  uint8_t frame[FRAME_LEN];
  frame[0] = TEL_START;
  memset(frame + 1, 0, TEL_BUF_LEN);

  frame[1 + TEL_IDX_BATTERY_H] = battery >> 8;
  frame[1 + TEL_IDX_BATTERY_L] = battery & 0xFF;
  frame[1 + TEL_IDX_RPM_H] = _rpm >> 8;
  frame[1 + TEL_IDX_RPM_L] = _rpm & 0xFF;
  frame[1 + TEL_IDX_SPEED_H] = speedMs >> 8;
  frame[1 + TEL_IDX_SPEED_L] = speedMs & 0xFF;

  Serial.write(frame, FRAME_LEN);
}

void updateRpm() {
  uint32_t now = millis();
  if (now - _lastRpmCalc < RPM_CALC_INTERVAL) return;

  noInterrupts();
  uint16_t pulses = _pulseCount;
  _pulseCount = 0;
  interrupts();

  float revs   = pulses;
  float elapsed = (now - _lastRpmCalc) / 60000.0f;
  uint16_t newRpm = (uint16_t)(revs / elapsed);

  // _rpm     = (_rpm * 0.7f) + (newRpm * 0.3f);  // low-pass filter, adjust weights
  _rpm = newRpm;
  _speedMs = ((_rpm / 60.0f) * WHEEL_CIRCUMFERENCE_M);
  _lastRpmCalc = now;
}


void printDebug() {
  Serial.print("RPM: ");
  Serial.print(_rpm);
  Serial.print("  Speed: ");
  Serial.print(_speedMs * 3.6f);
  Serial.println(" km/h");
}
