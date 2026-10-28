// https://github.com/TheSpydog/SDL_gpu_examples/blob/main/Examples/Common.c
import 'dart:ffi';
import 'dart:typed_data';

import 'package:sdl3/sdl3.dart';

import 'context.dart';

class Common {
  SdlxGpuDepthStencilTargetInfo? depthStencilTargetInfo;
  int format = SdlkGpuShaderformat.dxbc;
  var exampleName = '';
  var useRenderPass = true;

  SdlxFColor? clearColor;

  bool init(Context context) => true;
  bool update(Context context) => true;
  bool draw(Context context) => true;
  void quit(Context context) {
    return;
  }

  Pointer<SdlGpuShader> loadShaderFromSource(
    Pointer<SdlGpuDevice> device,
    String source, {
    required int stage,
    required int format,
    int numSamplers = 0,
    int numUniformBuffers = 0,
    int numStorageBuffers = 0,
    int numStorageTextures = 0,
    String entrypoint = 'main',
  }) {
    Pointer<SdlGpuShader> shader = nullptr;
    Uint8List? shaderCode;
    //    Pointer<Uint8> shaderCode = nullptr;
    final hlslInfo = SdlxShaderCrossHlslInfo(
      source: source,
      entrypoint: entrypoint,
      shaderStage: stage,
    );
    switch (format) {
      case SdlkGpuShaderformat.dxbc:
        shaderCode = sdlxShaderCrossCompileDxbcFromHlsl(hlslInfo);
      case SdlkGpuShaderformat.dxil:
        shaderCode = sdlxShaderCrossCompileDxilFromHlsl(hlslInfo);
      case SdlkGpuShaderformat.spirv:
        shaderCode = sdlxShaderCrossCompileSpirvFromHlsl(hlslInfo);
    }
    if (shaderCode == null) {
      sdlLog('Failed to compile shader: ${sdlGetError()}');
    } else {
      final shaderInfo = SdlxGpuShaderCreateInfo(
        code: shaderCode,
        entrypoint: entrypoint,
        format: format,
        stage: stage,
        numSamplers: numSamplers,
        numUniformBuffers: numUniformBuffers,
        numStorageBuffers: numStorageBuffers,
        numStorageTextures: numStorageTextures,
      );
      shader = sdlxCreateGpuShader(device, shaderInfo);
      if (shader == nullptr) {
        sdlLog('Failed to create shader: ${sdlGetError()}');
      }
      //      sdlFree(shaderCode.cast<Void>());
    }
    return shader;
  }

  bool appInit(Context context) {
    context.device = sdlCreateGpuDevice(format, true, null);
    if (context.device == nullptr) {
      sdlLog('sdlCreateGpuDevice failed: ${sdlGetError()}');
      return false;
    }
    context.window = sdlCreateWindow(
      exampleName,
      640,
      480,
      SdlkWindow.resizable,
    );
    if (context.window == nullptr) {
      sdlLog('sdlCreateWindow failed: ${sdlGetError()}');
      return false;
    }
    if (!sdlClaimWindowForGpuDevice(context.device, context.window)) {
      sdlLog('sdlClaimWindowForGpuDevice failed: ${sdlGetError()}');
      return false;
    }
    sdlLog('STARTING EXAMPLE: $exampleName');
    return init(context);
  }

  bool appIterate(Context context) {
    var running = update(context);
    if (!running) {
      return running;
    }
    // draw command
    context.commandBuffer = sdlAcquireGpuCommandBuffer(context.device);
    if (context.commandBuffer != nullptr) {
      final rec = sdlxWaitAndAcquireGpuSwapchainTexture(
        context.commandBuffer,
        context.window,
      );
      if (rec != null && rec.width > 0 && rec.height > 0) {
        context
          ..swapchainTexture = rec.texture
          ..swapchainWidth = rec.width
          ..swapchainHeight = rec.height;
        if (useRenderPass) {
          final colorTargetInfo = SdlxGpuColorTargetInfo(
            texture: context.swapchainTexture,
            loadOp: SdlkGpuLoadop.clear,
            clearColor: clearColor ?? const SdlxFColor(0, 0, 0),
            //storeOp: SdlkGpuStoreop.store,
          );
          context.renderPass = sdlxBeginGpuRenderPass(context.commandBuffer, [
            colorTargetInfo,
          ], depthStencilTargetInfo: depthStencilTargetInfo);
        } else {
          context.renderPass = nullptr;
        }
        running = draw(context);
        if (useRenderPass) {
          if (context.renderPass != nullptr) {
            sdlEndGpuRenderPass(context.renderPass);
            context.renderPass = nullptr;
          }
        }
        sdlSubmitGpuCommandBuffer(context.commandBuffer);
      } else {
        sdlCancelGpuCommandBuffer(context.commandBuffer);
      }
    }
    return running;
  }

  void appQuit(Context context) {
    quit(context);
    if (context.device != nullptr && context.window != nullptr) {
      sdlReleaseWindowFromGpuDevice(context.device, context.window);
    }
    if (context.window != nullptr) {
      sdlDestroyWindow(context.window);
      context.window = nullptr;
    }
    if (context.device != nullptr) {
      sdlDestroyGpuDevice(context.device);
      context.device = nullptr;
    }
  }
}
