import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

enum VoiceState { idle, listening, processing, error }

class VoiceCommandService {
  static final VoiceCommandService _instance = VoiceCommandService._internal();
  factory VoiceCommandService() => _instance;
  VoiceCommandService._internal();

  final SpeechToText _speechToText = SpeechToText();
  InferenceModel? _gemma;
  bool _isInitialized = false;
  String _lastTranscription = '';

  final StreamController<VoiceState> _stateController =
      StreamController<VoiceState>.broadcast();
  final StreamController<String> _messageController =
      StreamController<String>.broadcast();
  final StreamController<Map<String, bool>> _commandResultController =
      StreamController<Map<String, bool>>.broadcast();

  Stream<VoiceState> get stateStream => _stateController.stream;
  Stream<String> get messageStream => _messageController.stream;
  Stream<Map<String, bool>> get commandResultStream =>
      _commandResultController.stream;

  VoiceState _currentState = VoiceState.idle;
  VoiceState get currentState => _currentState;

  static const String _modelAssetName = 'functiongemma-270M-it.task';

  // System prompt for Gemma to understand intent and descriptions
  static const String _systemPrompt =
      '''You are an intelligent assistant that understands user intent for controlling an RC car's lights and indicators.

Your task: Analyze the user's command and determine which car controls they want to activate or deactivate.

Available controls and their purposes:
1. headlights - Main forward-facing lights for illumination
2. foglights - Lower lights used in foggy/misty conditions  
3. left_indicator - Blinking light signaling a left turn
4. right_indicator - Blinking light signaling a right turn

IMPORTANT RULES:
- Understand intent, not just keywords
- "turn signal", "blinker", "indicator" all refer to turn indicators
- "lights" alone usually means headlights
- "hazards" or "emergency lights" means BOTH indicators on
- Words like "kill", "cut", "shut off", "disable", "stop" mean OFF (false)
- Words like "turn on", "activate", "enable", "start" mean ON (true)
- Descriptive phrases like "the thing that shows I'm turning" refer to indicators
- "equipment that indicates" = indicators
- "lights for poor visibility" = foglights

Output format: Return ONLY a JSON object with the controls to change.
Example outputs:
{"headlights": true}
{"right_indicator": true}
{"left_indicator": true, "right_indicator": true}
{"foglights": false, "headlights": false}

If the command is unclear or not related to these controls, return: {}

User command:''';

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Check and request microphone permission
      _emitMessage('Requesting microphone permission...');
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        _emitMessage('❌ Microphone permission denied');
        return false;
      }
      _emitMessage('✅ Microphone permission granted');

      // Initialize speech recognition
      final speechAvailable = await _speechToText.initialize(
        onError: (error) => _emitMessage('Speech error: ${error.errorMsg}'),
        onStatus: (status) => _emitMessage('Speech status: $status'),
      );

      if (!speechAvailable) {
        _emitMessage('Speech recognition not available');
        return false;
      }

      // Check if Gemma model is installed
      _emitMessage('Checking Gemma model installation...');
      bool isInstalled = false;
      try {
        isInstalled = await FlutterGemma.isModelInstalled(_modelAssetName);
        debugPrint(
          "[VoiceCommandService] Model installation check: $isInstalled",
        );
      } catch (e) {
        _emitMessage('Error checking model installation: $e');
        _emitMessage('Attempting to install model anyway...');
        isInstalled = false;
      }

      if (!isInstalled) {
        _emitMessage('Installing Gemma model from assets...');
        try {
          await FlutterGemma.installModel(
            modelType: ModelType.gemmaIt,
          ).fromAsset(_modelAssetName).install();
          _emitMessage('Gemma model installed from assets: $_modelAssetName');
        } catch (e) {
          _emitMessage('Failed to install Gemma model from assets: $e');
          _emitMessage('Voice commands will work with fallback text parsing');
          // Don't return false - we can still use fallback parsing
          _isInitialized = true;
          return true;
        }
      } else {
        _emitMessage('Gemma model already installed');
      }

      // Get the active model (the installed model should now be active)
      _emitMessage('Getting active Gemma model...');
      try {
        _gemma = await FlutterGemma.getActiveModel(
          maxTokens: 1024,
          preferredBackend: PreferredBackend.gpu,
        );
        _emitMessage('✅ Gemma model ready with GPU');
        _emitMessage('Model loaded successfully - natural language enabled!');
      } catch (e) {
        _emitMessage('Failed to get active model with GPU: $e');
        try {
          // Try without GPU preference
          _emitMessage('Retrying without GPU preference...');
          _gemma = await FlutterGemma.getActiveModel(maxTokens: 1024);
          _emitMessage('✅ Gemma model ready (CPU mode)');
          _emitMessage('Model loaded successfully - natural language enabled!');
        } catch (e2) {
          _emitMessage('❌ Could not load Gemma model: $e2');
          _emitMessage('Voice commands will use pattern matching only');
          // Continue anyway - fallback parsing will handle commands
        }
      }

      _isInitialized = true;
      return true;
    } catch (e) {
      _emitMessage('Initialization failed: $e');
      return false;
    }
  }

  Future<void> startListening() async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        _updateState(VoiceState.error);
        return;
      }
    }

    if (_speechToText.isListening) {
      await stopListening();
    }

    _lastTranscription = '';
    _updateState(VoiceState.listening);
    _emitMessage('🎤 Listening... Speak now!');

    await _speechToText.listen(
      onResult: (result) {
        _lastTranscription = result.recognizedWords;
        if (result.hasConfidenceRating && result.confidence > 0) {
          _emitMessage('Hearing: "${result.recognizedWords}"');
        }
        if (result.finalResult) {
          _onSpeechFinalized();
        }
      },
      listenFor: const Duration(seconds: 5),
      pauseFor: const Duration(seconds: 2),
      partialResults: true,
      cancelOnError: true,
      listenMode: ListenMode.confirmation,
    );
  }

  Future<void> stopListening() async {
    if (_speechToText.isListening) {
      await _speechToText.stop();
    }
    // Ensure state is reset if we're still in listening mode
    if (_currentState == VoiceState.listening) {
      _updateState(VoiceState.idle);
    }
  }

  void _onSpeechFinalized() async {
    try {
      await stopListening();

      if (_lastTranscription.isEmpty) {
        _emitMessage(
          '❌ No speech detected. Try speaking louder or closer to mic.',
        );
        _updateState(VoiceState.idle);
        return;
      }

      _emitMessage('✅ Final: "$_lastTranscription"');
      _updateState(VoiceState.processing);

      // Process command with Gemma
      final result = await _processCommand(_lastTranscription);

      if (result != null && result.isNotEmpty) {
        _emitMessage('✅ Command processed: ${result.keys.join(", ")}');
        _commandResultController.add(result); // Emit the result
        _updateState(VoiceState.idle);
      } else {
        _emitMessage(
          '❌ Could not understand command. Describe what you want to control.',
        );
        _updateState(VoiceState.error);
        // Auto-reset to idle after error
        Future.delayed(const Duration(seconds: 2), () {
          if (_currentState == VoiceState.error) {
            _updateState(VoiceState.idle);
          }
        });
      }
    } catch (e) {
      _emitMessage('Error processing speech: $e');
      _updateState(VoiceState.idle);
    }
  }

  Future<Map<String, bool>?> _processCommand(String transcription) async {
    // Try Gemma first if available, otherwise fall back to direct parsing
    if (_gemma == null) {
      _emitMessage('⚠️ Gemma LLM not loaded, using basic pattern matching');
      _emitMessage('Check earlier logs for "Could not load Gemma model" error');
      return _parseDirectCommand(transcription);
    }

    try {
      _emitMessage('🤖 Processing with Gemma LLM...');
      // Create the full prompt with system instruction
      final prompt = '$_systemPrompt "$transcription"';

      // Create a new chat session for this command
      final chat = await _gemma!.createChat();

      // Add user message
      await chat.addQueryChunk(Message.text(text: prompt, isUser: true));

      // Generate response (synchronous, waits for full response)
      final response = await chat.generateChatResponse();

      // Extract text from the response
      String responseText = '';
      if (response is TextResponse) {
        responseText = response.token;
      } else {
        // For other response types, convert to string
        responseText = response.toString();
      }

      if (responseText.isEmpty) {
        _emitMessage('Gemma returned empty response');
        return null;
      }

      _emitMessage('Gemma response: $responseText');

      // Parse the JSON response
      final parsed = _parseGemmaResponse(responseText);
      if (parsed != null && parsed.isNotEmpty) {
        return parsed;
      }

      _emitMessage('Gemma returned empty result, trying fallback parser');
      return _parseDirectCommand(transcription);
    } catch (e) {
      _emitMessage('Gemma processing error: $e');
      return _parseDirectCommand(transcription);
    }
  }

  Map<String, bool>? _parseDirectCommand(String transcription) {
    // This is a simple fallback for basic commands only
    // The LLM should handle most natural language variations
    _emitMessage('⚠️ Using basic pattern matching (Gemma unavailable)');
    final normalized = transcription.toLowerCase().trim();

    // Remove common filler words to improve matching
    final cleaned = normalized
        .replaceAll(' the ', ' ')
        .replaceAll(' a ', ' ')
        .replaceAll(' an ', ' ')
        .replaceAll(' my ', ' ');

    final result = <String, bool>{};

    // Helper to check if text contains key words
    bool hasWords(List<String> words) {
      return words.every((word) => cleaned.contains(word));
    }

    bool containsAny(List<String> options) =>
        options.any((phrase) => cleaned.contains(phrase));

    // Hazards detection (check first to avoid conflicts)
    if (containsAny([
          'hazard on',
          'hazards on',
          'turn on hazards',
          'enable hazards',
          'emergency lights',
          'emergency light on',
          'put on hazards',
        ]) ||
        hasWords(['hazard']) && hasWords(['on'])) {
      result['left_indicator'] = true;
      result['right_indicator'] = true;
    } else if (containsAny([
          'hazard off',
          'hazards off',
          'turn off hazards',
          'disable hazards',
          'kill hazards',
          'cancel hazards',
          'emergency lights off',
        ]) ||
        hasWords(['hazard']) && hasWords(['off'])) {
      result['left_indicator'] = false;
      result['right_indicator'] = false;
    }

    // Left indicator - check for key words
    if (!result.containsKey('left_indicator')) {
      if ((hasWords(['left']) && hasWords(['on'])) ||
          (hasWords(['left']) &&
              (hasWords(['indicator']) ||
                  hasWords(['signal']) ||
                  hasWords(['blinker'])) &&
              hasWords(['on']))) {
        result['left_indicator'] = true;
      } else if ((hasWords(['left']) && hasWords(['off'])) ||
          (hasWords(['left']) &&
              (hasWords(['indicator']) ||
                  hasWords(['signal']) ||
                  hasWords(['blinker'])) &&
              hasWords(['off']))) {
        result['left_indicator'] = false;
      }
    }

    // Right indicator - check for key words
    if (!result.containsKey('right_indicator')) {
      if ((hasWords(['right']) && hasWords(['on'])) ||
          (hasWords(['right']) &&
              (hasWords(['indicator']) ||
                  hasWords(['signal']) ||
                  hasWords(['blinker'])) &&
              hasWords(['on']))) {
        result['right_indicator'] = true;
      } else if ((hasWords(['right']) && hasWords(['off'])) ||
          (hasWords(['right']) &&
              (hasWords(['indicator']) ||
                  hasWords(['signal']) ||
                  hasWords(['blinker'])) &&
              hasWords(['off']))) {
        result['right_indicator'] = false;
      }
    }

    // Headlights - check for key words
    if (hasWords(['lights', 'on']) ||
        hasWords(['headlight', 'on']) ||
        hasWords(['headlights', 'on'])) {
      result['headlights'] = true;
    } else if (hasWords(['lights', 'off']) ||
        hasWords(['headlight', 'off']) ||
        hasWords(['headlights', 'off']) ||
        (hasWords(['kill']) && hasWords(['light'])) ||
        (hasWords(['cut']) && hasWords(['light']))) {
      result['headlights'] = false;
    }

    // Fog lights - check for key words
    if (hasWords(['fog']) && hasWords(['on'])) {
      result['foglights'] = true;
    } else if (hasWords(['fog']) && hasWords(['off'])) {
      result['foglights'] = false;
    }

    return result.isEmpty ? null : result;
  }

  Map<String, bool>? _parseGemmaResponse(String response) {
    try {
      // Clean up the response - remove markdown code blocks if present
      String cleaned = response.trim();

      // Remove markdown code block formatting
      if (cleaned.startsWith('```json')) {
        cleaned = cleaned.substring(7);
      } else if (cleaned.startsWith('```')) {
        cleaned = cleaned.substring(3);
      }

      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3);
      }

      cleaned = cleaned.trim();

      // Find JSON object in response
      final jsonStart = cleaned.indexOf('{');
      final jsonEnd = cleaned.lastIndexOf('}');

      if (jsonStart == -1 || jsonEnd == -1 || jsonStart > jsonEnd) {
        _emitMessage('No valid JSON found in response');
        return null;
      }

      final jsonStr = cleaned.substring(jsonStart, jsonEnd + 1);
      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;

      // Validate and convert to Map<String, bool>
      final result = <String, bool>{};
      final validKeys = {
        'left_indicator',
        'right_indicator',
        'headlights',
        'foglights',
      };

      for (final entry in parsed.entries) {
        if (validKeys.contains(entry.key) && entry.value is bool) {
          result[entry.key] = entry.value as bool;
        }
      }

      if (result.isEmpty) {
        _emitMessage('No valid light controls in JSON');
        return null;
      }

      return result;
    } catch (e) {
      _emitMessage('JSON parsing error: $e');
      return null;
    }
  }

  void _updateState(VoiceState newState) {
    _currentState = newState;
    _stateController.add(newState);
  }

  void _emitMessage(String message) {
    _messageController.add(message);
  }

  void dispose() {
    _speechToText.cancel();
    _stateController.close();
    _messageController.close();
    _commandResultController.close();
  }
}
