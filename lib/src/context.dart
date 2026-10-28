// https://github.com/TheSpydog/SDL_gpu_examples/blob/main/Examples/Common.h
import 'dart:ffi';

import 'package:sdl3/sdl3.dart';

class Context {
  var basePath = '';
  Pointer<SdlWindow> window = nullptr;
  Pointer<SdlGpuDevice> device = nullptr;
  Pointer<SdlGpuCommandBuffer> commandBuffer = nullptr;
  Pointer<SdlGpuRenderPass> renderPass = nullptr;
  Pointer<SdlGpuTexture> swapchainTexture = nullptr;
  var swapchainWidth = 0;
  var swapchainHeight = 0;
  var leftPressed = false;
  var rightPressed = false;
  var downPressed = false;
  var upPressed = false;
  var deltaTime = 0.0;

  void reset() {
    leftPressed = false;
    rightPressed = false;
    downPressed = false;
    upPressed = false;
  }
}
