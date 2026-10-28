// https://github.com/TheSpydog/SDL_gpu_examples/blob/main/Examples/CopyAndReadback.c
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:sdl3/sdl3.dart';
import 'package:sdl3_gpu_examples/sdl3_gpu_examples.dart';

class CopyAndReadback extends Common {
  @override
  String get exampleName => 'CopyAndReadback';
  Pointer<SdlGpuTexture> originalTexture = nullptr;
  Pointer<SdlGpuTexture> textureCopy = nullptr;
  Pointer<SdlGpuTexture> textureSmall = nullptr;
  Pointer<SdlGpuBuffer> originalBuffer = nullptr;
  Pointer<SdlGpuBuffer> bufferCopy = nullptr;
  var textureWidth = 0;
  var textureHeight = 0;

  @override
  bool init(Context context) {
    useRenderPass = false;
    final rawImageData = imgLoad('assets/Images/ravioli.bmp');
    if (rawImageData == nullptr) {
      sdlLog('Could not load image data!');
      return false;
    }
    final imageData = sdlConvertSurface(rawImageData, SdlkPixelformat.abgr8888);
    rawImageData.destroy();
    if (imageData == nullptr) {
      sdlLog('Failed to convert surface!');
      return false;
    }
    textureWidth = imageData.ref.w;
    textureHeight = imageData.ref.h;
    originalTexture = sdlxCreateGpuTexture(
      context.device,
      SdlxGpuTextureCreateInfo(
        //type: SdlkGpuTexturetype.on2D,
        format: SdlkGpuTextureformat.r8G8B8A8Unorm,
        width: imageData.ref.w,
        height: imageData.ref.h,
        layerCountOrDepth: 1,
        numLevels: 1,
        usage: SdlkGpuTextureusage.sampler,
      ),
    );
    textureCopy = sdlxCreateGpuTexture(
      context.device,
      SdlxGpuTextureCreateInfo(
        //type: SdlkGpuTexturetype.on2D,
        format: SdlkGpuTextureformat.r8G8B8A8Unorm,
        width: imageData.ref.w,
        height: imageData.ref.h,
        layerCountOrDepth: 1,
        numLevels: 1,
        usage: SdlkGpuTextureusage.sampler,
      ),
    );
    textureSmall = sdlxCreateGpuTexture(
      context.device,
      SdlxGpuTextureCreateInfo(
        //type: SdlkGpuTexturetype.on2D,
        format: SdlkGpuTextureformat.r8G8B8A8Unorm,
        width: imageData.ref.w ~/ 2,
        height: imageData.ref.h ~/ 2,
        layerCountOrDepth: 1,
        numLevels: 1,
        usage: SdlkGpuTextureusage.sampler | SdlkGpuTextureusage.colorTarget,
      ),
    );
    final bufferDataList = [2, 4, 8, 16, 32, 64, 128];
    final bufferData = calloc<Uint32>(7);
    final bufferSize = sizeOf<Uint32>() * bufferDataList.length;
    for (var i = 0; i < bufferDataList.length; i++) {
      bufferData[i] = bufferDataList[i];
    }

    originalBuffer = sdlxCreateGpuBuffer(
      context.device,
      SdlxGpuBufferCreateInfo(
        usage: SdlkGpuBufferusage.graphicsStorageRead,
        size: bufferSize,
      ),
    );
    bufferCopy = sdlxCreateGpuBuffer(
      context.device,
      SdlxGpuBufferCreateInfo(
        usage: SdlkGpuBufferusage.graphicsStorageRead,
        size: bufferSize,
      ),
    );
    final downloadTransferBuffer = sdlxCreateGpuTransferBuffer(
      context.device,
      SdlxGpuTransferBufferCreateInfo(
        usage: SdlkGpuTransferbufferusage.download,
        size: imageData.ref.w * imageData.ref.h * 4 + bufferSize,
      ),
    );
    final uploadTransferBuffer = sdlxCreateGpuTransferBuffer(
      context.device,
      SdlxGpuTransferBufferCreateInfo(
        //usage: SdlkGpuTransferbufferusage.upload,
        size: imageData.ref.w * imageData.ref.h * 4 + bufferSize,
      ),
    );
    final uploadTranferPointer = sdlMapGpuTransferBuffer(
      context.device,
      uploadTransferBuffer,
      false,
    ).cast<Uint8>();
    sdlMemcpy(
      uploadTranferPointer.cast<Void>(),
      imageData.ref.pixels,
      imageData.ref.w * imageData.ref.h * 4,
    );
    sdlMemcpy(
      (uploadTranferPointer + imageData.ref.w * imageData.ref.h * 4)
          .cast<Void>(),
      bufferData.cast<Void>(),
      bufferSize,
    );
    sdlUnmapGpuTransferBuffer(context.device, uploadTransferBuffer);
    bufferData.callocFree();

    final uploadCommandBuffer = sdlAcquireGpuCommandBuffer(context.device);
    var copyPass = sdlBeginGpuCopyPass(uploadCommandBuffer);
    // Upload original texture
    sdlxUploadToGpuTexture(
      copyPass,
      SdlxGpuTextureTransferInfo(
        transferBuffer: uploadTransferBuffer,
        //offset: 0,
      ),
      SdlxGpuTextureRegion(
        texture: originalTexture,
        w: imageData.ref.w,
        h: imageData.ref.h,
        d: 1,
      ),
    );
    // Copy original to copy
    sdlxCopyGpuTextureToTexture(
      copyPass,
      SdlxGpuTextureLocation(
        texture: originalTexture,
        //x: 0,
        //y: 0,
        //z: 0,
      ),
      SdlxGpuTextureLocation(
        texture: textureCopy,
        //x: 0,
        //y: 0,
        //z: 0,
      ),
      imageData.ref.w,
      imageData.ref.h,
      1,
    );
    // Upload original buffer
    sdlxUploadToGpuBuffer(
      copyPass,
      SdlxGpuTransferBufferLocation(
        transferBuffer: uploadTransferBuffer,
        offset: imageData.ref.w * imageData.ref.h * 4,
      ),
      SdlxGpuBufferRegion(
        buffer: originalBuffer,
        //offset: 0,
        size: bufferSize,
      ),
    );
    // Copy original to copy
    sdlxCopyGpuBufferToBuffer(
      copyPass,
      SdlxGpuBufferLocation(
        buffer: originalBuffer,
        //offset: 0,
      ),
      SdlxGpuBufferLocation(
        buffer: bufferCopy,
        //offset: 0,
      ),
      bufferSize,
    );
    sdlEndGpuCopyPass(copyPass);
    // Render the half-size version
    sdlxBlitGpuTexture(
      uploadCommandBuffer,
      SdlxGpuBlitInfo(
        source: SdlxGpuBlitRegion(
          texture: originalTexture,
          w: imageData.ref.w,
          h: imageData.ref.h,
        ),
        destination: SdlxGpuBlitRegion(
          texture: textureSmall,
          w: imageData.ref.w ~/ 2,
          h: imageData.ref.h ~/ 2,
        ),
        loadOp: SdlkGpuLoadop.dontCare,
        filter: SdlkGpuFilter.linear,
      ),
    );
    // Download the original bytes from the copy
    copyPass = sdlBeginGpuCopyPass(uploadCommandBuffer);
    sdlxDownloadFromGpuTexture(
      copyPass,
      SdlxGpuTextureRegion(
        texture: textureCopy,
        w: imageData.ref.w,
        h: imageData.ref.h,
        d: 1,
      ),
      SdlxGpuTextureTransferInfo(
        transferBuffer: downloadTransferBuffer,
        //offset: 0,
      ),
    );
    sdlxDownloadFromGpuBuffer(
      copyPass,
      SdlxGpuBufferRegion(
        buffer: bufferCopy,
        //offset: 0,
        size: bufferSize,
      ),
      SdlxGpuTransferBufferLocation(
        transferBuffer: downloadTransferBuffer,
        offset: imageData.ref.w * imageData.ref.h * 4,
      ),
    );
    sdlEndGpuCopyPass(copyPass);
    final fence = sdlSubmitGpuCommandBufferAndAcquireFence(uploadCommandBuffer);
    sdlxWaitForGpuFences(context.device, [fence]);
    sdlReleaseGpuFence(context.device, fence);
    final downloadTranferPointer = sdlMapGpuTransferBuffer(
      context.device,
      downloadTransferBuffer,
      false,
    ).cast<Uint8>();
    if (sdlMemcmp(
          downloadTranferPointer.cast<Void>(),
          imageData.ref.pixels,
          imageData.ref.w * imageData.ref.h * 4,
        ) ==
        0) {
      sdlLog('SUCCESS! Original texture bytes and the downloaded bytes match!');
    } else {
      sdlLog('FAILURE! Original texture bytes do not match downloaded bytes!');
    }
    if (sdlMemcmp(
          (downloadTranferPointer + imageData.ref.w * imageData.ref.h * 4)
              .cast<Void>(),
          bufferData.cast<Void>(),
          bufferSize,
        ) ==
        0) {
      sdlLog('SUCCESS! Original buffer bytes and the downloaded bytes match!');
    } else {
      sdlLog('FAILURE! Original buffer bytes do not match downloaded bytes!');
    }
    sdlUnmapGpuTransferBuffer(context.device, downloadTransferBuffer);
    // Cleanup
    sdlReleaseGpuTransferBuffer(context.device, downloadTransferBuffer);
    sdlReleaseGpuTransferBuffer(context.device, uploadTransferBuffer);
    imageData.destroy();
    return true;
  }

  @override
  bool draw(Context context) {
    sdlxBlitGpuTexture(
      context.commandBuffer,
      SdlxGpuBlitInfo(
        source: SdlxGpuBlitRegion(
          texture: originalTexture,
          w: textureWidth,
          h: textureHeight,
        ),
        destination: SdlxGpuBlitRegion(
          texture: context.swapchainTexture,
          w: context.swapchainWidth ~/ 2,
          h: context.swapchainHeight ~/ 2,
        ),
        //loadOp: SdlkGpuLoadop.load,
        //filter: SdlkGpuFilter.nearest,
      ),
    );
    sdlxBlitGpuTexture(
      context.commandBuffer,
      SdlxGpuBlitInfo(
        source: SdlxGpuBlitRegion(
          texture: textureCopy,
          w: textureWidth,
          h: textureHeight,
        ),
        destination: SdlxGpuBlitRegion(
          texture: context.swapchainTexture,
          x: context.swapchainWidth ~/ 2,
          w: context.swapchainWidth ~/ 2,
          h: context.swapchainHeight ~/ 2,
        ),
        //loadOp: SdlkGpuLoadop.load,
        //filter: SdlkGpuFilter.nearest,
      ),
    );
    sdlxBlitGpuTexture(
      context.commandBuffer,
      SdlxGpuBlitInfo(
        source: SdlxGpuBlitRegion(
          texture: textureSmall,
          //x: 0,
          //y: 0,
          w: textureWidth ~/ 2,
          h: textureHeight ~/ 2,
        ),
        destination: SdlxGpuBlitRegion(
          texture: context.swapchainTexture,
          x: context.swapchainWidth ~/ 4,
          y: context.swapchainHeight ~/ 2,
          w: context.swapchainWidth ~/ 2,
          h: context.swapchainHeight ~/ 2,
        ),
        //loadOp: SdlkGpuLoadop.load,
        //filter: SdlkGpuFilter.nearest,
      ),
    );
    return true;
  }

  @override
  void quit(Context context) {
    if (originalTexture != nullptr) {
      sdlReleaseGpuTexture(context.device, originalTexture);
      originalTexture = nullptr;
    }
    if (textureCopy != nullptr) {
      sdlReleaseGpuTexture(context.device, textureCopy);
      textureCopy = nullptr;
    }
    if (textureSmall != nullptr) {
      sdlReleaseGpuTexture(context.device, textureSmall);
      textureSmall = nullptr;
    }
    if (originalBuffer != nullptr) {
      sdlReleaseGpuBuffer(context.device, originalBuffer);
      originalBuffer = nullptr;
    }
    if (bufferCopy != nullptr) {
      sdlReleaseGpuBuffer(context.device, bufferCopy);
      bufferCopy = nullptr;
    }
  }
}

void main() {
  App.run([CopyAndReadback()]);
}
