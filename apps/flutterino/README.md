# Flutterino

A specialized Flutter package providing high-performance, real-time, low-latency I/O control of an Arduino via USB-OTG. 

Flutterino maps physical Arduino pins to local reactive streams, enabling asynchronous communication directly on the main thread. It executes serial I/O parsing, byte reassembly, framing, and CRC8 validation with high efficiency.

## Single Line Setup

```dart
var board = await Flutterino.connect(Baud.b115200);
```

### Simulation Mode
Need to build the UI without an Arduino attached to your Android device? Utilize the mock simulation engine which automatically echoes state telemetry:
```dart
var board = await Flutterino.connect(Baud.b115200, simulationMode: true);
```

## Features
- **Zero-Isolate Architecture:** Simplified serial `Rx`/`Tx` flow avoids isolate-related overhead and runtime issues.
- **Strictly Framed Packets:** Includes built-in CRC8 checking to drop corrupted frames over noisy serial connections.
- **Auto-Sync Resilience:** Automatically resends `PIN_MODE` commands and output values immediately if USB detachment and reconnection occur.
- **Reactive Stream API:** Directly listen to pins as `Stream<int>` or `Stream<bool>`.

## Usage
Include `flutterino` in your `pubspec.yaml` dependencies. 

Load the included C++ Header File `Flutterino.h` in your Arduino IDE sketch:
```cpp
#include <Flutterino.h>

void setup() {
  Flutterino.begin(115200);
}

void loop() {
  Flutterino.update();
}
```

Then in Flutter:
```dart
var board = await Flutterino.connect(Baud.b115200);

// Initialize pins
board.pinMode(13, PinMode.output);
board.pinMode(A0, PinMode.input);

// Write to pins
board.digitalWrite(13, true);
board.analogWrite(9, 128); // PWM

// Listen to pins dynamically
board.subscribeAnalog(A0).listen((val) {
   print("A0 Value: $val");
});
```
