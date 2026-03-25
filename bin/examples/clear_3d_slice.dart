// https://github.com/TheSpydog/SDL_gpu_examples/blob/main/Examples/Clear3DSlice.c
import 'dart:ffi';
import 'package:sdl3/sdl3.dart';
import 'package:sdl3_gpu_examples/sdl3_gpu_examples.dart';

class Clear3DSlice extends Common {
  @override
  String get exampleName => 'Clear3DSlice';

  Pointer<SdlGpuTexture> texture3d = nullptr;

  @override
  bool init(Context context) {
    useRenderPass = false;
    texture3d = sdlxCreateGpuTexture(
      context.device,
      SdlxGpuTextureCreateInfo()
        ..type = SdlkGpuTexturetype.on3D
        ..format = sdlGetGpuSwapchainTextureFormat(
          context.device,
          context.window,
        )
        ..width = 64
        ..height = 64
        ..layerCountOrDepth = 4
        ..numLevels = 1
        ..usage = SdlkGpuTextureusage.colorTarget | SdlkGpuTextureusage.sampler,
    );
    return true;
  }

  @override
  bool draw(Context context) {
    sdlEndGpuRenderPass(
      sdlxBeginGpuRenderPass(context.commandBuffer, [
        SdlxGpuColorTargetInfo()
          ..texture = texture3d
          ..cycle = 1
          ..loadOp = SdlkGpuLoadop.clear
          ..storeOp = SdlkGpuStoreop.store
          ..clearColor = SdlxFColor(r: 1)
          ..layerOrDepthPlane = 0,
      ]),
    );
    sdlEndGpuRenderPass(
      sdlxBeginGpuRenderPass(context.commandBuffer, [
        SdlxGpuColorTargetInfo()
          ..texture = texture3d
          ..cycle = 0
          ..loadOp = SdlkGpuLoadop.clear
          ..storeOp = SdlkGpuStoreop.store
          ..clearColor = SdlxFColor(g: 1)
          ..layerOrDepthPlane = 1,
      ]),
    );
    sdlEndGpuRenderPass(
      sdlxBeginGpuRenderPass(context.commandBuffer, [
        SdlxGpuColorTargetInfo()
          ..texture = texture3d
          ..cycle = 0
          ..loadOp = SdlkGpuLoadop.clear
          ..storeOp = SdlkGpuStoreop.store
          ..clearColor = SdlxFColor(b: 1)
          ..layerOrDepthPlane = 2,
      ]),
    );
    sdlEndGpuRenderPass(
      sdlxBeginGpuRenderPass(context.commandBuffer, [
        SdlxGpuColorTargetInfo()
          ..texture = texture3d
          ..cycle = 0
          ..loadOp = SdlkGpuLoadop.clear
          ..storeOp = SdlkGpuStoreop.store
          ..clearColor = SdlxFColor(r: 1, b: 1)
          ..layerOrDepthPlane = 3,
      ]),
    );
    for (var i = 0; i < 4; i++) {
      final destX = (i % 2) * (context.swapchainTextureWidth ~/ 2);
      final destY = (i > 1) ? (context.swapchainTextureHeight ~/ 2) : 0;
      sdlxBlitGpuTexture(
        context.commandBuffer,
        SdlxGpuBlitInfo()
          ..source.texture = texture3d
          ..source.layerOrDepthPlane = i
          ..source.w = 64
          ..source.h = 64
          ..destination.texture = context.swapchainTexture
          ..destination.x = destX
          ..destination.y = destY
          ..destination.w = context.swapchainTextureWidth ~/ 2
          ..destination.h = context.swapchainTextureHeight ~/ 2
          ..loadOp = SdlkGpuLoadop.load
          ..filter = SdlkGpuFilter.nearest,
      );
    }
    return true;
  }

  @override
  void quit(Context context) {
    if (texture3d != nullptr) {
      sdlReleaseGpuTexture(context.device, texture3d);
      texture3d = nullptr;
    }
  }
}

void main() {
  App.run([Clear3DSlice()]);
}
