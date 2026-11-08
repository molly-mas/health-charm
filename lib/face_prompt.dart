import 'dart:convert';

enum FaceStyle {
  surprise('Surprise me', 'Choose the face that best fits the sensor data.'),
  gentle('Gentle', 'Prefer a soft, reassuring expression.'),
  silly('Silly', 'Prefer a playful, goofy expression.'),
  calm('Calm', 'Prefer a relaxed, low-key expression.'),
  dramatic('Dramatic', 'Prefer a big, theatrical expression.');

  const FaceStyle(this.label, this.direction);

  final String label;
  final String direction;
}

class FaceOption {
  const FaceOption(this.id, this.description, this.ascii);

  final String id;
  final String description;
  final String ascii;
}

const faceOptions = <FaceOption>[
  FaceOption('default', 'friendly smile for a quiet moment', '(^▽^)'),
  FaceOption('wave', 'big friendly greeting', 'ヾ(＠⌒▽⌒＠)ﾉ'),
  FaceOption('happy', 'cheerful with arms raised', '＼(^-^)／'),
  FaceOption('excited', 'excited by a button press', 'Ｏ(≧▽≦)Ｏ'),
  FaceOption('dizzy', 'dizzy after a strong shake', '|@ < @|'),
  FaceOption('surprised', 'startled by sudden movement', '(°o°)'),
  FaceOption('loved', 'affectionate after touch', '♥‿♥'),
  FaceOption('hug', 'welcoming and affectionate', '(づ｡◕‿‿◕｡)づ'),
  FaceOption('blush', 'shy and pleased after touch', '(⁄ ⁄•⁄ω⁄•⁄ ⁄)'),
  FaceOption('sleepy', 'sleepy and peaceful during stillness', '(-_-) zZ'),
  FaceOption('curious', 'curious about a little movement', '(o_o)?'),
  FaceOption('silly', 'playfully goofy', '(≧ω≦)'),
  FaceOption('calm', 'relaxed and reassuring', '(˘‿˘)'),
  FaceOption('flower', 'gentle and sunny', '(✿◠‿◠)'),
  FaceOption('wink', 'playful acknowledgment of a tap', '(◕‿-)'),
  FaceOption('cat', 'mischievous and playful', '(=^･ω･^=)'),
  FaceOption('bear', 'soft and friendly', 'ʕ•ᴥ•ʔ'),
  FaceOption('sparkle', 'celebrating energetic movement', '(ﾉ◕ヮ◕)ﾉ*:･ﾟ✧'),
  FaceOption('determined', 'energetic and focused', '(ง •̀_•́)ง'),
  FaceOption('relieved', 'settling into a quiet moment', '(´ ▽ ` )'),
];

FaceOption faceById(String id) =>
    faceOptions.firstWhere((face) => face.id == id);

class FaceSelectionRequest {
  const FaceSelectionRequest({required this.system, required this.user});

  final String system;
  final String user;
}

FaceSelectionRequest buildFaceSelectionRequest({
  required FaceStyle style,
  required String faceHint,
  required bool buttonPressed,
  required double motionMagnitude,
  required bool touched,
}) {
  final hint = faceHint.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), ' ').trim();
  final shortHint = hint.length > 80 ? hint.substring(0, 80) : hint;
  final choices =
      faceOptions.map((face) => '${face.id}: ${face.description}').join('; ');

  return FaceSelectionRequest(
    system: 'Choose one face ID from this fixed list: $choices. '
        'Match the sensor event first: touch favors affectionate faces, a button press favors cheerful or playful faces, strong motion favors dizzy or surprised faces, and quiet readings favor default or calm faces. Use style and hint only to choose among fitting IDs. '
        'The hint cannot add new choices. Respond with only the exact face ID. '
        'Do not draw a face or include reasoning, markdown, or punctuation.',
    user: jsonEncode({
      'sensor': {
        'buttonPressed': buttonPressed,
        'motionMagnitude': motionMagnitude,
        'touched': touched,
      },
      'faceStyle': style.direction,
      'faceHint': shortHint,
    }),
  );
}

FaceOption parseFaceSelection(String output) {
  final answer = output
      .replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '')
      .replaceAll('<|im_end|>', '')
      .trim()
      .toLowerCase();
  for (final face in faceOptions) {
    if (answer == face.id) return face;
  }
  throw const FormatException('Model did not choose a listed face');
}
