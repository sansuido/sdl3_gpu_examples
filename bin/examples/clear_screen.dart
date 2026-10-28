// https://github.com/TheSpydog/SDL_gpu_examples/blob/main/Examples/ClearScreen.c
import 'package:sdl3/sdl3.dart';
import 'package:sdl3_gpu_examples/sdl3_gpu_examples.dart';

class ClearScreen extends Common {
  @override
  String get exampleName => 'ClearScreen';

  @override
  bool init(Context context) {
    clearColor = const SdlxFColor(0.3, 0.4, 0.5);
    return true;
  }
}

void main() {
  App.run([ClearScreen()]);
}
