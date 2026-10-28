// https://github.com/TheSpydog/SDL_gpu_examples/blob/main/Examples/ComputeSampler.c
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:sdl3/sdl3.dart';
import 'package:sdl3_gpu_examples/sdl3_gpu_examples.dart';

final gSamplerNames = [
  'PointClamp',
  'PointWrap',
  'LinearClamp',
  'LinearWrap',
  'AnisotropicClamp',
  'AnisotropicWrap',
];

const gComputeSource = '''
cbuffer UBO : register(b0, space2)
{
    float ubo_texcoord_multiplier : packoffset(c0);
};

Texture2D<float4> inImage : register(t0, space0);
SamplerState inImageSampler : register(s0, space0);

[[vk::image_format("rgba8")]]
RWTexture2D<float4> outImage : register(u0, space1);

[numthreads(8, 8, 1)]
void main(uint3 GlobalInvocationID : SV_DispatchThreadID)
{
    float w, h;
    inImage.GetDimensions(w, h);
    int2 coord = int2(GlobalInvocationID.xy);
    float2 texcoord = (float2(coord) * ubo_texcoord_multiplier) / float2(w, h);
    float4 inPixel = inImage.SampleLevel(inImageSampler, texcoord, 0.0f);
    outImage[coord] = inPixel;
}
''';

final class TexcoordMultiplier extends Struct {
  @Float()
  external double value;
}

class ComputeSampler extends Common {
  @override
  String get exampleName => 'ComputeSampler';
  late int currentSamplerIndex;
  Pointer<SdlGpuComputePipeline> pipeline = nullptr;
  List<Pointer<SdlGpuSampler>> samplers = [];
  Pointer<SdlGpuTexture> texture = nullptr;
  Pointer<SdlGpuTexture> writeTexture = nullptr;
  Pointer<TexcoordMultiplier> texcoordMultiplier = nullptr;

  @override
  bool init(Context context) {
    useRenderPass = false;
    currentSamplerIndex = 0;
    texcoordMultiplier = calloc<TexcoordMultiplier>();
    // Load the image
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
    texture = sdlxCreateGpuTexture(
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
    sdlSetGpuTextureName(context.device, texture, 'Ravioli Texture 🖼️');
    writeTexture = sdlxCreateGpuTexture(
      context.device,
      const SdlxGpuTextureCreateInfo(
        //type: SdlkGpuTexturetype.on2D,
        format: SdlkGpuTextureformat.r8G8B8A8Unorm,
        width: 640,
        height: 480,
        layerCountOrDepth: 1,
        numLevels: 1,
        usage:
            SdlkGpuTextureusage.sampler |
            SdlkGpuTextureusage.computeStorageWrite,
      ),
    );
    final pipelineRec = sdlxShaderCrossComputePipelineFromHlsl(
      context.device,
      format,
      const SdlxShaderCrossHlslInfo(source: gComputeSource, entrypoint: 'main'),
    );
    if (pipelineRec == null) {
      sdlLog('Failed to create compute shader!');
      return false;
    }
    pipeline = pipelineRec.pipeline;
    samplers
      ..add(
        // PointClamp
        sdlxCreateGpuSampler(
          context.device,
          const SdlxGpuSamplerCreateInfo(
            //minFilter: SdlkGpuFilter.nearest,
            //magFilter: SdlkGpuFilter.nearest,
            //mipmapMode: SdlkGpuSamplermipmapmode.nearest,
            addressModeU: SdlkGpuSampleraddressmode.clampToEdge,
            addressModeV: SdlkGpuSampleraddressmode.clampToEdge,
            addressModeW: SdlkGpuSampleraddressmode.clampToEdge,
          ),
        ),
      )
      ..add(
        // PointWrap
        sdlxCreateGpuSampler(
          context.device,
          const SdlxGpuSamplerCreateInfo(
            //minFilter: SdlkGpuFilter.nearest,
            //magFilter: SdlkGpuFilter.nearest,
            //mipmapMode: SdlkGpuSamplermipmapmode.nearest,
            //addressModeU: SdlkGpuSampleraddressmode.repeat,
            //addressModeV: SdlkGpuSampleraddressmode.repeat,
            //addressModeW: SdlkGpuSampleraddressmode.repeat,
          ),
        ),
      )
      ..add(
        // LinearClamp
        sdlxCreateGpuSampler(
          context.device,
          const SdlxGpuSamplerCreateInfo(
            minFilter: SdlkGpuFilter.linear,
            magFilter: SdlkGpuFilter.linear,
            mipmapMode: SdlkGpuSamplermipmapmode.linear,
            addressModeU: SdlkGpuSampleraddressmode.clampToEdge,
            addressModeV: SdlkGpuSampleraddressmode.clampToEdge,
            addressModeW: SdlkGpuSampleraddressmode.clampToEdge,
          ),
        ),
      )
      ..add(
        // LinearWrap
        sdlxCreateGpuSampler(
          context.device,
          const SdlxGpuSamplerCreateInfo(
            minFilter: SdlkGpuFilter.linear,
            magFilter: SdlkGpuFilter.linear,
            mipmapMode: SdlkGpuSamplermipmapmode.linear,
            //addressModeU: SdlkGpuSampleraddressmode.repeat,
            //addressModeV: SdlkGpuSampleraddressmode.repeat,
            //addressModeW: SdlkGpuSampleraddressmode.repeat,
          ),
        ),
      )
      // [4]
      ..add(
        // AnisotropicClamp
        sdlxCreateGpuSampler(
          context.device,
          const SdlxGpuSamplerCreateInfo(
            minFilter: SdlkGpuFilter.linear,
            magFilter: SdlkGpuFilter.linear,
            mipmapMode: SdlkGpuSamplermipmapmode.linear,
            addressModeU: SdlkGpuSampleraddressmode.clampToEdge,
            addressModeV: SdlkGpuSampleraddressmode.clampToEdge,
            addressModeW: SdlkGpuSampleraddressmode.clampToEdge,
            enableAnisotropy: true,
            maxAnisotropy: 4,
          ),
        ),
      )
      ..add(
        // AnisotropicWrap
        sdlxCreateGpuSampler(
          context.device,
          const SdlxGpuSamplerCreateInfo(
            minFilter: SdlkGpuFilter.linear,
            magFilter: SdlkGpuFilter.linear,
            mipmapMode: SdlkGpuSamplermipmapmode.linear,
            //addressModeU: SdlkGpuSampleraddressmode.repeat,
            //addressModeV: SdlkGpuSampleraddressmode.repeat,
            //addressModeW: SdlkGpuSampleraddressmode.repeat,
            enableAnisotropy: true,
            maxAnisotropy: 4,
          ),
        ),
      );
    // Set up texture data
    final textureTransferBuffer = sdlxCreateGpuTransferBuffer(
      context.device,
      SdlxGpuTransferBufferCreateInfo(
        //usage: SdlkGpuTransferbufferusage.upload,
        size: imageData.ref.w * imageData.ref.h * 4,
      ),
    );
    final textureTranferPointer = sdlMapGpuTransferBuffer(
      context.device,
      textureTransferBuffer,
      false,
    ).cast<Uint8>();
    sdlMemcpy(
      textureTranferPointer.cast<Void>(),
      imageData.ref.pixels,
      imageData.ref.w * imageData.ref.h * 4,
    );
    sdlUnmapGpuTransferBuffer(context.device, textureTransferBuffer);
    // Upload the transfer data to the GPU resources
    final uploadCommandBuffer = sdlAcquireGpuCommandBuffer(context.device);
    final copyPass = sdlBeginGpuCopyPass(uploadCommandBuffer);
    sdlxUploadToGpuTexture(
      copyPass,
      SdlxGpuTextureTransferInfo(
        transferBuffer: textureTransferBuffer,
        //offset: 0,
      ),
      SdlxGpuTextureRegion(
        texture: texture,
        w: imageData.ref.w,
        h: imageData.ref.h,
        d: 1,
      ),
    );
    sdlEndGpuCopyPass(copyPass);
    sdlSubmitGpuCommandBuffer(uploadCommandBuffer);
    sdlReleaseGpuTransferBuffer(context.device, textureTransferBuffer);
    imageData.destroy();
    // Finally, print instructions!
    sdlLog('Press Left/Right to switch between sampler states');
    sdlLog('Setting sampler state to: ${gSamplerNames[currentSamplerIndex]}');
    return true;
  }

  @override
  bool update(Context context) {
    var usage = false;
    if (context.leftPressed) {
      currentSamplerIndex -= 1;
      if (currentSamplerIndex < 0) {
        currentSamplerIndex = samplers.length - 1;
      }
      usage = true;
    }
    if (context.rightPressed) {
      currentSamplerIndex += 1;
      if (currentSamplerIndex >= samplers.length) {
        currentSamplerIndex = 0;
      }
      usage = true;
    }
    if (usage) {
      sdlLog('Setting sampler state to: ${gSamplerNames[currentSamplerIndex]}');
    }
    return true;
  }

  @override
  bool draw(Context context) {
    final computePass = sdlxBeginGpuComputePass(
      context.commandBuffer,
      textures: [
        SdlxGpuStorageTextureReadWriteBinding(
          texture: writeTexture,
          //layer: 0,
          //mipLevel: 0,
          cycle: true,
        ),
      ],
    );
    sdlBindGpuComputePipeline(computePass, pipeline);
    sdlxBindGpuComputeSamplers(computePass, [
      SdlxGpuTextureSamplerBinding(
        texture: texture,
        sampler: samplers[currentSamplerIndex],
      ),
    ]);
    texcoordMultiplier.ref.value = 0.25;
    sdlPushGpuComputeUniformData(
      context.commandBuffer,
      0,
      texcoordMultiplier.cast<Void>(),
      sizeOf<TexcoordMultiplier>(),
    );
    sdlDispatchGpuCompute(
      computePass,
      context.swapchainWidth ~/ 8,
      context.swapchainHeight ~/ 8,
      1,
    );
    sdlEndGpuComputePass(computePass);
    sdlxBlitGpuTexture(
      context.commandBuffer,
      SdlxGpuBlitInfo(
        source: SdlxGpuBlitRegion(texture: writeTexture, w: 640, h: 480),
        destination: SdlxGpuBlitRegion(
          texture: context.swapchainTexture,
          w: context.swapchainWidth,
          h: context.swapchainHeight,
        ),
        loadOp: SdlkGpuLoadop.dontCare,
        //filter: SdlkGpuFilter.nearest,
      ),
    );
    return true;
  }

  @override
  void quit(Context context) {
    if (texcoordMultiplier != nullptr) {
      texcoordMultiplier.callocFree();
      texcoordMultiplier = nullptr;
    }
    if (texture != nullptr) {
      sdlReleaseGpuTexture(context.device, texture);
    }
    if (writeTexture != nullptr) {
      sdlReleaseGpuTexture(context.device, writeTexture);
    }
    if (pipeline != nullptr) {
      sdlReleaseGpuComputePipeline(context.device, pipeline);
      pipeline = nullptr;
    }
    for (final sampler in samplers) {
      sdlReleaseGpuSampler(context.device, sampler);
    }
    samplers.clear();
  }
}

void main() {
  App.run([ComputeSampler()]);
}
