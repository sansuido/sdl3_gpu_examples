// https://github.com/TheSpydog/SDL_gpu_examples/blob/main/Examples/main.c
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:sdl3/sdl3.dart';
import 'common.dart';
import 'context.dart';

class App {
  static void run(List<Common> examples, {bool usage = false}) {
    if (!sdlInit(SdlkInit.video)) {
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
    final event = calloc<SdlEvent>();
    while (running) {
      context.reset();
      while (event.poll()) {
        if (event.type == SdlkEvent.quit) {
          running = false;
        }
        if (event.type == SdlkEvent.keyDown) {
          switch (event.key.ref.scancode) {
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
    event.callocFree();
    if (exampleIndex != -1) {
      examples[exampleIndex].appQuit(context);
    }
    sdlQuit();
  }
}
