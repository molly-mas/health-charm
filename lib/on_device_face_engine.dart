import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart';

import 'face_prompt.dart';

class LocalModelStore {
  static const _channel = MethodChannel('facebolt/model');

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<String?> modelPath() async =>
      supported ? _channel.invokeMethod<String>('modelPath') : null;

  static Future<String?> importModel() async =>
      supported ? _channel.invokeMethod<String>('importModel') : null;

  static Future<void> openModelPage() async {
    if (supported) await _channel.invokeMethod<void>('openModelPage');
  }
}

class OnDeviceFaceEngine {
  LlamaController? _controller;
  bool _loaded = false;

  bool get isLoaded => _loaded;

  Future<void> load(String modelPath) async {
    if (_loaded) return;
    final controller = LlamaController();
    try {
      // CPU mmap is the safest starting point for the S23 Ultra's 8/12 GB RAM.
      // GPU offload can be tuned after a real-device memory and latency check.
      await controller.loadModel(
        modelPath: modelPath,
        threads: 4,
        contextSize: 1024,
        gpuLayers: 0,
      );
      _controller = controller;
      _loaded = true;
    } catch (_) {
      await controller.dispose();
      rethrow;
    }
  }

  Future<FaceOption> choose(FaceSelectionRequest request) async {
    final controller = _controller;
    if (!_loaded || controller == null) {
      throw StateError('Nemotron is not loaded');
    }
    await controller.clearContext();
    // NVIDIA's template uses ChatML and an empty think block for direct answers.
    final prompt = '<|im_start|>system\n${request.system}<|im_end|>\n'
        '<|im_start|>user\n${request.user}<|im_end|>\n'
        '<|im_start|>assistant\n<think></think>';
    final output = await controller
        .generate(
          prompt: prompt,
          maxTokens: 32,
          temperature: 0.1,
        )
        .join();
    return parseFaceSelection(output);
  }

  Future<void> dispose() async {
    _loaded = false;
    final controller = _controller;
    _controller = null;
    if (controller != null) await controller.dispose();
  }
}
