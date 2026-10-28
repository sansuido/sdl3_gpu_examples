// https://github.com/TheSpydog/SDL_gpu_examples/blob/main/Examples/main.c
import 'package:sdl3/sdl3.dart';

import 'common.dart';
import 'context.dart';

class App {
  static void run(List<Common> examples, {bool usage = false}) {
    if (!sdlInit(SdlkInit.video)) {
      return;
    }
    if (!sdlShaderCrossInit()) {
      sdlQuit();
      return;
    }
    final context = Context();
    var exampleIndex = -1;
    var gotoExampleIndex = 0;
    var running = true;
    var lastTime = 0.0;
    if (usage) {
      sdlLog('Welcome to the SDL_GPU example suite!');
      sdlLog('Press A/D (or LB/RB) to move between examples!');
    }
    while (running) {
      context.reset();
      SdlxEvent? event;
      while ((event = sdlxPollEvent()) != null) {
        if (event is SdlxQuitEvent) {
          running = false;
        }
        if (event is SdlxKeyboardEvent && event.type == SDL_EVENT_KEY_DOWN) {
          switch (event.scancode) {
            case SdlkScancode.escape:
              running = false;
            case SdlkScancode.a:
              gotoExampleIndex = exampleIndex - 1;
              if (gotoExampleIndex < 0) {
                gotoExampleIndex = examples.length - 1;
              }
            case SdlkScancode.d:
              gotoExampleIndex = exampleIndex + 1;
              if (gotoExampleIndex >= examples.length) {
                gotoExampleIndex = 0;
              }
            case SdlkScancode.left:
              context.leftPressed = true;
            case SdlkScancode.right:
              context.rightPressed = true;
            case SdlkScancode.down:
              context.downPressed = true;
            case SdlkScancode.up:
              context.upPressed = true;
          }
        }
      }
      if (!running) {
        break;
      }
      if (gotoExampleIndex != -1) {
        if (gotoExampleIndex != exampleIndex) {
          if (exampleIndex != -1) {
            examples[exampleIndex].appQuit(context);
          }
          exampleIndex = gotoExampleIndex;
          running = examples[exampleIndex].appInit(context);
          if (!running) {
            break;
          }
        }
        gotoExampleIndex = -1;
      }
      final newTime = sdlGetTicks() / 1000.0;
      context.deltaTime = newTime - lastTime;
      lastTime = newTime;
      running = examples[exampleIndex].appIterate(context);
    }
    if (exampleIndex != -1) {
      examples[exampleIndex].appQuit(context);
    }
    sdlShaderCrossQuit();
    sdlQuit();
  }
}
