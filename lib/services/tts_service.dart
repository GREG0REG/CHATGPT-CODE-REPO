// CHATGPT-CODE-REPO-TEST/lib/services/tts_service.dart
// NEW FILE - Text-to-Speech for Audio Flashcards

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Text-to-Speech service for audio flashcards.
/// Supports multiple languages, speeds, and voice selection.
class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _isSpeaking = false;
  double _speechRate = 0.5; // 0.0 - 1.0
  double _volume = 1.0;
  double _pitch = 1.0;

  // Language codes for common study languages
  static const Map<String, String> languages = {
    'English': 'en-US',
    'Spanish': 'es-ES',
    'French': 'fr-FR',
    'German': 'de-DE',
    'Italian': 'it-IT',
    'Portuguese': 'pt-BR',
    'Chinese': 'zh-CN',
    'Japanese': 'ja-JP',
    'Korean': 'ko-KR',
    'Russian': 'ru-RU',
    'Arabic': 'ar-SA',
    'Hindi': 'hi-IN',
  };

  String _currentLanguage = 'en-US';

  bool get isSpeaking => _isSpeaking;

  Future<void> init() async {
    if (_initialized) return;
    
    await _tts.setLanguage(_currentLanguage);
    await _tts.setSpeechRate(_speechRate);
    await _tts.setVolume(_volume);
    await _tts.setPitch(_pitch);
    
    _tts.setCompletionHandler(() {
      _isSpeaking = false;
    });
    
    _tts.setErrorHandler((msg) {
      debugPrint('TTS Error: $msg');
      _isSpeaking = false;
    });
    
    _initialized = true;
  }

  Future<void> speak(String text, {String? languageCode}) async {
    if (text.trim().isEmpty) return;
    await init();
    
    if (languageCode != null && languageCode != _currentLanguage) {
      await _tts.setLanguage(languageCode);
      _currentLanguage = languageCode;
    }
    
    _isSpeaking = true;
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
    _isSpeaking = false;
  }

  Future<void> pause() async {
    // flutter_tts doesn't support pause, only stop
    await stop();
  }

  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.1, 1.0);
    await _tts.setSpeechRate(_speechRate);
  }

  Future<void> setVolume(double vol) async {
    _volume = vol.clamp(0.0, 1.0);
    await _tts.setVolume(_volume);
  }

  Future<void> setPitch(double p) async {
    _pitch = p.clamp(0.5, 2.0);
    await _tts.setPitch(_pitch);
  }

  Future<void> setLanguage(String languageCode) async {
    _currentLanguage = languageCode;
    await _tts.setLanguage(languageCode);
  }

  Future<List<dynamic>> getAvailableLanguages() async {
    await init();
    return await _tts.getLanguages;
  }

  Future<bool> isLanguageAvailable(String language) async {
    await init();
    return await _tts.isLanguageAvailable(language);
  }

  void dispose() {
    _tts.stop();
  }
}
