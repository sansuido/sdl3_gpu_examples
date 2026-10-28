// https://github.com/TheSpydog/SDL_gpu_examples/blob/main/Examples/ComputeUniforms.c
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:sdl3/sdl3.dart';
import 'package:sdl3_gpu_examples/sdl3_gpu_examples.dart';

const gComputeSource = '''
[[vk::image_format("rgba8")]]
RWTexture2D<float4> OutImage : register(u0, space1);

cbuffer UBO : register(b0, space2)
{
    float ubo_time : packoffset(c0);
};

[numthreads(8, 8, 1)]
void main(uint3 GlobalInvocationID : SV_DispatchThreadID)
{
    float w, h;
    OutImage.GetDimensions(w, h);
    float2 size = float2(w, h);
    float2 coord = GlobalInvocationID.xy;
    float2 uv = coord / size;

    float3 col = 0.5f.xxx + (cos((ubo_time.xxx + uv.xyx) + float3(0.0f, 2.0f, 4.0f)) * 0.5f);
    OutImage[int2(coord)] = float4(col, 1.0f);
}
''';

final class GradientUniforms extends Struct {
  @Float()
  external double time;
}

class ComputeUniforms extends Common {
  @override
  String get exampleName => 'ComputeUniforms';
  Pointer<GradientUniforms> gradientUniformValues = nullptr;
  Pointer<SdlGpuComputePipeline> computePipeline = nullptr;
  Pointer<SdlGpuTexture> texture = nullptr;
  var textureWidth = 0;
  var textureHeight = 0;

  @override
  bool init(Context context) {
    useRenderPass = false;
    final piplineRec = sdlxShaderCrossComputePipelineFromHlsl(
      context.device,
      format,
      const SdlxShaderCrossHlslInfo(source: gComputeSource, entrypoint: 'main'),
    );
    if (piplineRec == null) {
      sdlLog('Failed to create compute shader!');
      return false;
    }
    computePipeline = piplineRec.pipeline;
    //computePipeline = createComputePipelineFromSource(
    //  context.device,
    //  gComputeSource,
    //  format: format,
    //  numReadwriteStorageTextures: 1,
    //  numUniformBuffers: 1,
    //  threadcountX: 8,
    //  threadcountY: 8,
    //  threadcountZ: 1,
    //);
    final rec = sdlxGetWindowSizeInPixels(context.window);
    if (rec != null) {
      textureWidth = rec.w;
      textureHeight = rec.h;
    }
    texture = sdlxCreateGpuTexture(
      context.device,
      SdlxGpuTextureCreateInfo(
        //type: SdlkGpuTexturetype.on2D,
        format: SdlkGpuTextureformat.r8G8B8A8Unorm,
        width: textureWidth,
        height: textureHeight,
        layerCountOrDepth: 1,
        numLevels: 1,
        usage:
            SdlkGpuTextureusage.computeStorageWrite |
            SdlkGpuTextureusage.sampler,
      ),
    );
    gradientUniformValues = calloc<GradientUniforms>();
    return true;
  }

  @override
  bool update(Context context) {
    gradientUniformValues.ref.time += context.deltaTime;
    return true;
  }

  @override
  bool draw(Context context) {
    final computePass = sdlxBeginGpuComputePass(
      context.commandBuffer,
      textures: [
        SdlxGpuStorageTextureReadWriteBinding(texture: texture, cycle: true),
      ],
    );
    sdlBindGpuComputePipeline(computePass, computePipeline);
    sdlPushGpuComputeUniformData(
      context.commandBuffer,
      0,
      gradientUniformValues.cast<Void>(),
      sizeOf<GradientUniforms>(),
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
        source: SdlxGpuBlitRegion(
          texture: texture,
          w: textureWidth,
          h: textureHeight,
        ),
        destination: SdlxGpuBlitRegion(
          texture: context.swapchainTexture,
          w: context.swapchainWidth,
          h: context.swapchainHeight,
        ),
        loadOp: SdlkGpuLoadop.dontCare,
        filter: SdlkGpuFilter.linear,
      ),
    );
    return true;
  }

  @override
  void quit(Context context) {
    if (gradientUniformValues != nullptr) {
      gradientUniformValues.callocFree();
      gradientUniformValues = nullptr;
    }
    if (computePipeline != nullptr) {
      sdlReleaseGpuComputePipeline(context.device, computePipeline);
      computePipeline = nullptr;
    }
    if (texture != nullptr) {
      sdlReleaseGpuTexture(context.device, texture);
      texture = nullptr;
    }
  }
}

void main() {
  App.run([ComputeUniforms()]);
}
