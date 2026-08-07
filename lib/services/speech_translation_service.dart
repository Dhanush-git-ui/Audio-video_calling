// @dart=3.3
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'dart:js_interop';
import 'dart:js_util' as js_util;
import 'package:web/web.dart' as web;
import 'dart:async';

// JS Interop definitions for SpeechRecognition API
@JS('SpeechRecognition')
extension type SpeechRecognition._(JSObject _) implements JSObject {
  external factory SpeechRecognition();
  external set continuous(bool value);
  external set interimResults(bool value);
  external set maxAlternatives(int value);
  external set lang(String value);
  external void start();
  external void stop();
  
  external set onstart(JSFunction value);
  external set onaudiostart(JSFunction value);
  external set onspeechstart(JSFunction value);
  external set onspeechend(JSFunction value);
  external set onaudioend(JSFunction value);
  external set onresult(JSFunction value);
  external set onend(JSFunction value);
  external set onnomatch(JSFunction value);
  external set onerror(JSFunction value);
}

@JS('webkitSpeechRecognition')
extension type WebkitSpeechRecognition._(JSObject _) implements SpeechRecognition {
  external factory WebkitSpeechRecognition();
}

@JS('window')
external JSObject get _window;

class SpeechTranslationService {
  static final SpeechTranslationService _instance = SpeechTranslationService._internal();
  factory SpeechTranslationService() => _instance;
  SpeechTranslationService._internal();

  SpeechRecognition? _recognition;
  bool isListening = false;
  bool _isInit = false;
  String currentSpokenLanguage = 'en-US';
  
  // Callback when local speech is transcribed (String text, bool isFinal)
  Function(String, bool)? onLocalSpeech;
  
  // Callback when an error occurs
  Function(String)? onSpeechError;

  void init() {
    if (!kIsWeb || _isInit) return;
    try {
      // Check if SpeechRecognition or webkitSpeechRecognition is available
      bool hasSpeechRecognition = js_util.hasProperty(_window, 'SpeechRecognition');
      bool hasWebkitSpeechRecognition = js_util.hasProperty(_window, 'webkitSpeechRecognition');

      if (!hasSpeechRecognition && !hasWebkitSpeechRecognition) {
        debugPrint('SpeechRecognition not supported in this browser.');
        if (onSpeechError != null) onSpeechError!('Speech Recognition is not supported in this browser.');
        return;
      }
      
      _recognition = hasSpeechRecognition ? SpeechRecognition() : WebkitSpeechRecognition();
      _recognition!.continuous = true;
      _recognition!.interimResults = true;
      _recognition!.maxAlternatives = 1;
      _recognition!.lang = currentSpokenLanguage;
      
      // Events
      _recognition!.onstart = (web.Event event) {
        debugPrint('Recognition started');
      }.toJS;

      _recognition!.onaudiostart = (web.Event event) {
        debugPrint('Audio started');
      }.toJS;
      
      _recognition!.onspeechstart = (web.Event event) {
        debugPrint('Speech Started');
      }.toJS;

      _recognition!.onspeechend = (web.Event event) {
        debugPrint('Speech Ended');
      }.toJS;

      _recognition!.onaudioend = (web.Event event) {
        debugPrint('Audio ended');
      }.toJS;

      _recognition!.onresult = (JSAny event) {
        try {
          final resultsList = js_util.getProperty(event, 'results');
          final length = js_util.getProperty(resultsList, 'length');
          
          if (length > 0) {
            final lastResult = js_util.getProperty(resultsList, length - 1);
            final isFinal = js_util.getProperty(lastResult, 'isFinal') ?? false;
            
            final alternative = js_util.getProperty(lastResult, 0);
            final transcript = js_util.getProperty(alternative, 'transcript');
            
            debugPrint('Transcript received: "$transcript" (isFinal: $isFinal)');
            
            if (onLocalSpeech != null) {
               onLocalSpeech!(transcript.toString().trim(), isFinal);
            }
          }
        } catch (e) {
          debugPrint("STT Parse Error: $e");
          if (onSpeechError != null) onSpeechError!("STT Error: $e");
        }
      }.toJS;
      
      _recognition!.onend = (web.Event event) {
        debugPrint('Recognition stopped');
        // Auto-restart if we are supposed to be listening
        if (isListening) {
          try {
            debugPrint('Restarting recognition...');
            _recognition!.start();
          } catch (e) {
            debugPrint('SpeechRecognition restart error: $e');
          }
        }
      }.toJS;

      _recognition!.onnomatch = (web.Event event) {
        debugPrint('No match found');
        if (onSpeechError != null) onSpeechError!('No speech detected.');
      }.toJS;

      _recognition!.onerror = (JSAny event) {
        final error = js_util.getProperty(event, 'error');
        debugPrint('SpeechRecognition error: $error');
        
        if (error == 'not-allowed') {
          stopListening();
          if (onSpeechError != null) onSpeechError!('Microphone permission denied.');
        } else if (error == 'language-not-supported' || error == 'service-not-allowed') {
          stopListening();
          if (onSpeechError != null) onSpeechError!('Speech recognition is not supported for the selected language in this browser.');
        } else if (error == 'network') {
          stopListening();
          if (onSpeechError != null) onSpeechError!('Network error occurred during speech recognition.');
        } else if (error == 'aborted') {
          // Typically happens when stopped manually, no need to show an error message
          stopListening();
        } else if (error == 'no-speech') {
          // just ignore or notify
          debugPrint('No speech heard...');
        } else {
          stopListening();
          if (onSpeechError != null) onSpeechError!('Unable to access microphone: $error');
        }
      }.toJS;
      
      _isInit = true;
    } catch (e) {
      debugPrint('SpeechRecognition initialization error: $e');
      if (onSpeechError != null) onSpeechError!('Browser does not support Web Speech API.');
    }
  }

  void startListening() {
    if (!_isInit) init();
    if (isListening) return; // Prevent duplicate instances
    isListening = true;
    try {
      _recognition?.start();
    } catch (e) {
      debugPrint('SpeechRecognition start error: $e');
    }
  }

  void stopListening() {
    isListening = false;
    try {
      _recognition?.stop();
    } catch (e) {
      debugPrint('SpeechRecognition stop error: $e');
    }
  }

  void setSpokenLanguage(String langCode) {
    if (currentSpokenLanguage == langCode) return;
    currentSpokenLanguage = langCode;
    
    if (_recognition != null) {
      bool wasListening = isListening;
      stopListening();
      
      // Destroy and recreate the recognition object to apply the language change reliably
      Future.delayed(const Duration(milliseconds: 300), () {
        _isInit = false; // Force re-init
        if (wasListening) {
          startListening();
        }
      });
    }
  }

  Future<String> translateText(String text, String targetLang) async {
    if (text.trim().isEmpty) return text;
    try {
      debugPrint('Translation started for: "$text" to language: "$targetLang"');
      final url = 'https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=$targetLang&dt=t&q=${Uri.encodeComponent(text)}';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final translated = jsonResponse[0][0][0].toString();
        debugPrint('Translation completed: "$translated"');
        return translated;
      }
    } catch (e) {
      debugPrint("Translation error: $e");
    }
    return text; // fallback to original
  }
}
