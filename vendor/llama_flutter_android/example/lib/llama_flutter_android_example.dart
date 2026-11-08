// ignore_for_file: avoid_print
import 'package:llama_flutter_android/llama_flutter_android.dart';

/// Minimal example showing GPU detection and text generation.
///
/// For a full chat app example, see [main.dart] in this directory.
Future<void> main() async {
  final controller = LlamaController();

  // 1. Detect GPU capabilities
  final gpu = await controller.detectGpu();
  print('GPU: ${gpu.gpuName}');
  print('Vulkan: ${gpu.vulkanSupported}');
  print('Recommended layers: ${gpu.recommendedGpuLayers}');

  // 2. Load a GGUF model with auto GPU/CPU selection
  await controller.loadModel(
    modelPath: '/path/to/model.gguf',
    threads: 4,
    contextSize: 2048,
    gpuLayers: gpu.recommendedGpuLayers, // 0=CPU, 16=partial GPU, 99=full GPU
  );

  // 3. Stream tokens
  final buffer = StringBuffer();
  await for (final token in controller.generate(
    prompt: 'Explain what a large language model is in one sentence.',
    maxTokens: 100,
    temperature: 0.7,
  )) {
    buffer.write(token);
    print(token);
  }

  // 4. Or use chat mode with automatic template detection
  controller.generateChat(
    messages: [
      ChatMessage(role: 'system', content: 'You are a helpful assistant.'),
      ChatMessage(role: 'user', content: 'What is Flutter?'),
    ],
    // template: 'chatml', // optional — auto-detected from model filename
  ).listen(print);

  // 5. Clean up
  await controller.dispose();
}
