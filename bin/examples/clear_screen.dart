// https://github.com/TheSpydog/SDL_gpu_examples/blob/main/Examples/ClearScreen.c
import 'package:sdl3_gpu_examples/sdl3_gpu_examples.dart';

class ClearScreen extends Common {
  @override
  String get exampleName => 'ClearScreen';

  @override
  bool init(Context context) {
    colorTargetInfo.clearColor.r = 0.3;
    colorTargetInfo.clearColor.g = 0.4;
    colorTargetInfo.clearColor.b = 0.5;
    return true;
  }
}

void main() {
  App.run([ClearScreen()]);
}
