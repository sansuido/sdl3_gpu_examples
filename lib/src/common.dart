// https://github.com/TheSpydog/SDL_gpu_examples/blob/main/Examples/Common.c
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:sdl3/sdl3.dart';
import 'context.dart';

class Common {
  Common() {
    colorTargetInfo = SdlxGpuColorTargetInfo()
      ..loadOp = SdlkGpuLoadop.clear
      ..storeOp = SdlkGpuStoreop.store;
  }
  late SdlxGpuColorTargetInfo colorTargetInfo;
  SdlxGpuDepthStencilTargetInfo? depthStencilTargetInfo;
  int format = SdlkGpuShaderformat.spirv;
  var exampleName = '';
  var useRenderPass = true;

  bool init(Context context) => true;
  bool update(Context context) => true;
  bool draw(Context context) => true;
  void quit(Context context) {
    return;
  }

  Pointer<SdlGpuComputePipeline> createComputePipelineFromSource(
    Pointer<SdlGpuDevice> device,
    String source, {
    required int format,
    String entrypoint = 'main',
    int numSamplers = 0,
    int numReadonlyStorageTextures = 0,
    int numReadonlyStorageBuffers = 0,
    int numReadwriteStorageTextures = 0,
    int numReadwriteStorageBuffers = 0,
    int numUniformBuffers = 0,
    int threadcountX = 0,
    int threadcountY = 0,
    int threadcountZ = 0,
    int props = 0,
  }) {
    Pointer<SdlGpuComputePipeline> computePipeline = nullptr;
    Pointer<Uint8> shaderCode = nullptr;
    final hlslInfo = SdlxShaderCrossHlslInfo()
      ..source = source
      ..entrypoint = entrypoint
      ..shaderStage = SdlkShadercrossShaderstage.compute;
    switch (format) {
      case SdlkGpuShaderformat.dxbc:
        shaderCode = sdlxShaderCrossCompileDxbcFromHlsl(hlslInfo);
      case SdlkGpuShaderformat.dxil:
        shaderCode = sdlxShaderCrossCompileDxilFromHlsl(hlslInfo);
      case SdlkGpuShaderformat.spirv:
        shaderCode = sdlxShaderCrossCompileSpirvFromHlsl(hlslInfo);
    }
    if (shaderCode == nullptr) {
      sdlLog('Failed to compile shader: ${sdlGetError()}');
    } else {
      computePipeline = sdlxCreateGpuComputePipeline(
        device,
        SdlxGpuComputePipelineCreateInfo()
          ..code = shaderCode
          ..codeSize = hlslInfo.size
          ..entrypoint = entrypoint
          ..format = format
          ..numSamplers = numSamplers
          ..numReadonlyStorageTextures = numReadonlyStorageTextures
          ..numReadonlyStorageBuffers = numReadonlyStorageBuffers
          ..numReadwriteStorageTextures = numReadwriteStorageTextures
          ..numReadwriteStorageBuffers = numReadwriteStorageBuffers
          ..numUniformBuffers = numUniformBuffers
          ..threadcountX = threadcountX
          ..threadcountY = threadcountY
          ..threadcountZ = threadcountZ
          ..props = props,
      );
      if (computePipeline == nullptr) {
        sdlLog('Failed to create compute pipeline!: ${sdlGetError()}');
      }
      sdlFree(shaderCode);
    }
    return computePipeline;
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
    Pointer<Uint8> shaderCode = nullptr;
    final hlslInfo = SdlxShaderCrossHlslInfo()
      ..source = source
      ..entrypoint = entrypoint
      ..shaderStage = stage;
    switch (format) {
      case SdlkGpuShaderformat.dxbc:
        shaderCode = sdlxShaderCrossCompileDxbcFromHlsl(hlslInfo);
      case SdlkGpuShaderformat.dxil:
        shaderCode = sdlxShaderCrossCompileDxilFromHlsl(hlslInfo);
      case SdlkGpuShaderformat.spirv:
        shaderCode = sdlxShaderCrossCompileSpirvFromHlsl(hlslInfo);
    }
    if (shaderCode == nullptr) {
      sdlLog('Failed to compile shader: ${sdlGetError()}');
    } else {
      final shaderInfo = SdlxGpuShaderCreateInfo()
        ..code = shaderCode
        ..codeSize = hlslInfo.size
        ..entrypoint = entrypoint
        ..format = format
        ..stage = stage
        ..numSamplers = numSamplers
        ..numUniformBuffers = numUniformBuffers
        ..numStorageBuffers = numStorageBuffers
        ..numStorageTextures = numStorageTextures;
      shader = sdlxCreateGpuShader(device, shaderInfo);
      if (shader == nullptr) {
        sdlLog('Failed to create shader: ${sdlGetError()}');
      }
      sdlFree(shaderCode);
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
    final swapchainTexture = calloc<Pointer<SdlGpuTexture>>();
    final swapchainTextureWidth = calloc<Uint32>();
    final swapchainTextureHeight = calloc<Uint32>();
    final commandBuffer = sdlAcquireGpuCommandBuffer(context.device);
    if (commandBuffer != nullptr) {
      if (sdlWaitAndAcquireGpuSwapchainTexture(
        commandBuffer,
        context.window,
        swapchainTexture,
        swapchainTextureWidth,
        swapchainTextureHeight,
      )) {
        if (swapchainTextureWidth.value > 0 &&
            swapchainTextureHeight.value > 0) {
          Pointer<SdlGpuRenderPass> renderPass = nullptr;
          if (useRenderPass) {
            colorTargetInfo.texture = swapchainTexture.value;
            renderPass = sdlxBeginGpuRenderPass(commandBuffer, [
              colorTargetInfo,
            ], depthStencilTargetInfo: depthStencilTargetInfo);
          }
          context
            ..swapchainTexture = swapchainTexture.value
            ..swapchainTextureWidth = swapchainTextureWidth.value
            ..swapchainTextureHeight = swapchainTextureHeight.value
            ..commandBuffer = commandBuffer
            ..renderPass = renderPass;
          running = draw(context);
          context
            ..swapchainTexture = nullptr
            ..swapchainTextureWidth = 0
            ..swapchainTextureHeight = 0
            ..commandBuffer = nullptr
            ..renderPass = nullptr;
          if (useRenderPass) {
            sdlEndGpuRenderPass(renderPass);
          }
          sdlSubmitGpuCommandBuffer(commandBuffer);
        } else {
          sdlCancelGpuCommandBuffer(commandBuffer);
        }
      } else {
        sdlCancelGpuCommandBuffer(commandBuffer);
      }
    }
    swapchainTexture.callocFree();
    swapchainTextureWidth.callocFree();
    swapchainTextureHeight.callocFree();
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
