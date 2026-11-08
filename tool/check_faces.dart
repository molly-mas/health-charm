import 'dart:io';

import 'package:facebolt_flutter/face_prompt.dart';

void main() {
  final ids = <String>{};
  for (final face in faceOptions) {
    if (!ids.add(face.id)) throw StateError('Duplicate face ID: ${face.id}');
    if (face.ascii.trim().isEmpty || face.ascii.contains('\n')) {
      throw StateError('Invalid app face: ');
    }
    if (parseFaceSelection('  ${face.id.toUpperCase()}\n').id != face.id) {
      throw StateError('Could not parse face ID: ${face.id}');
    }
  }
  try {
    parseFaceSelection('a made up face');
    throw StateError('Unknown ID was accepted');
  } on FormatException {
    // Unlisted model output must never reach the display.
  }
  if (parseFaceSelection('<think></think>curious<|im_end|>').id != 'curious') {
    throw StateError('Could not parse a Nemotron chat response');
  }
  final request = buildFaceSelectionRequest(
    style: FaceStyle.silly,
    faceHint: 'playful',
    buttonPressed: true,
    motionMagnitude: 2.8,
    touched: false,
  );
  if (!request.system.contains('silly:') || !request.user.contains('playful')) {
    throw StateError('Face selection prompt is incomplete');
  }
  stdout.writeln(
      'Validated ${faceOptions.length} preset faces and model ID parsing.');
}
