// https://github.com/TheSpydog/SDL_gpu_examples/blob/main/Examples/TriangleMSAA.c
import 'dart:ffi';

import 'package:sdl3/sdl3.dart';
import 'package:sdl3_gpu_examples/sdl3_gpu_examples.dart';

const gVertexSource = '''
struct Input
{
    uint VertexIndex : SV_VertexID;
};

struct Output
{
    float4 Color : TEXCOORD0;
    float4 Position : SV_Position;
};

Output main(Input input)
{
    Output output;
    float2 pos;
    if (input.VertexIndex == 0)
    {
        pos = (-1.0f).xx;
        output.Color = float4(1.0f, 0.0f, 0.0f, 1.0f);
    }
    else
    {
        if (input.VertexIndex == 1)
        {
            pos = float2(1.0f, -1.0f);
            output.Color = float4(0.0f, 1.0f, 0.0f, 1.0f);
        }
        else
        {
            if (input.VertexIndex == 2)
            {
                pos = float2(0.0f, 1.0f);
                output.Color = float4(0.0f, 0.0f, 1.0f, 1.0f);
            }
        }
    }
    output.Position = float4(pos, 0.0f, 1.0f);
    return output;
}
''';

const gFragmentSource = '''
float4 main(float4 Color : TEXCOORD0) : SV_Target0
{
    return Color;
}
''';

class TriangleMSAA extends Common {
  @override
  String get exampleName => 'TriangleMSAA';

  @override
  bool get useRenderPass => false;

  final List<Pointer<SdlGpuGraphicsPipeline>> pipelines = [];
  final List<Pointer<SdlGpuTexture>> msaaRenderTextures = [];
  Pointer<SdlGpuTexture> resolveTexture = nullptr;
  var sampleCounts = 0;
  var currentSampleCount = 0;
  late int rtFormat;

  @override
  bool init(Context context) {
    // 1. Shaders
    final vertexShader = loadShaderFromSource(
      context.device,
      gVertexSource,
      format: format,
      stage: SdlkGpuShaderstage.vertex,
    );
    if (vertexShader == nullptr) {
      sdlLog('Failed to create vertex shader!');
      return false;
    }

    final fragmentShader = loadShaderFromSource(
      context.device,
      gFragmentSource,
      format: format,
      stage: SdlkGpuShaderstage.fragment,
    );
    if (fragmentShader == nullptr) {
      sdlLog('Failed to create fragment shader!');
      return false;
    }

    rtFormat = sdlGetGpuSwapchainTextureFormat(context.device, context.window);

    sampleCounts = 0;
    pipelines.clear();
    msaaRenderTextures.clear();

    for (var i = 0; i < 4; i++) {
      final sampleCount = SdlkGpuSamplecount.on1 + i;

      if (!sdlGpuTextureSupportsSampleCount(
        context.device,
        rtFormat,
        sampleCount,
      )) {
        sdlLog('Sample count index $i not supported');
        continue;
      }

      final pipelineCreateInfo = SdlxGpuGraphicsPipelineCreateInfo(
        targetInfo: SdlxGpuGraphicsPipelineTargetInfo(
          colorTargetDescriptions: [
            SdlxGpuColorTargetDescription(format: rtFormat),
          ],
        ),
        multisampleState: SdlxGpuMultisampleState(sampleCount: sampleCount),
        //primitiveType: SdlkGpuPrimitivetype.trianglelist,
        vertexShader: vertexShader,
        fragmentShader: fragmentShader,
      );

      final pipeline = sdlxCreateGpuGraphicsPipeline(
        context.device,
        pipelineCreateInfo,
      );
      if (pipeline == nullptr) {
        sdlLog('Failed to create pipeline!');
        return false;
      }
      pipelines.add(pipeline);

      final textureCreateInfo = SdlxGpuTextureCreateInfo(
        //type: SdlkGpuTexturetype.on2D,
        width: 640,
        height: 480,
        layerCountOrDepth: 1,
        numLevels: 1,
        format: rtFormat,
        usage:
            SdlkGpuTextureusage.colorTarget |
            (sampleCount == SdlkGpuSamplecount.on1
                ? SdlkGpuTextureusage.sampler
                : 0),
        sampleCount: sampleCount,
      );

      final msaaTexture = sdlxCreateGpuTexture(
        context.device,
        textureCreateInfo,
      );
      if (msaaTexture == nullptr) {
        sdlLog('Failed to create MSAA render target texture!');
        sdlReleaseGpuGraphicsPipeline(context.device, pipeline);
        return false;
      }
      msaaRenderTextures.add(msaaTexture);

      sampleCounts += 1;
    }

    resolveTexture = sdlxCreateGpuTexture(
      context.device,
      SdlxGpuTextureCreateInfo(
        //type: SdlkGpuTexturetype.on2D,
        width: 640,
        height: 480,
        layerCountOrDepth: 1,
        numLevels: 1,
        format: rtFormat,
        usage: SdlkGpuTextureusage.colorTarget | SdlkGpuTextureusage.sampler,
      ),
    );

    sdlReleaseGpuShader(context.device, vertexShader);
    sdlReleaseGpuShader(context.device, fragmentShader);

    sdlLog('Press Left/Right to cycle between sample counts');
    sdlLog('Current sample count: ${1 << currentSampleCount}');

    return true;
  }

  @override
  bool update(Context context) {
    var changed = 0;

    if (context.leftPressed) {
      currentSampleCount -= 1;
      if (currentSampleCount < 0) {
        currentSampleCount = sampleCounts - 1;
      }
      changed = 1;
    }

    if (context.rightPressed) {
      currentSampleCount = (currentSampleCount + 1) % sampleCounts;
      changed = 1;
    }

    if (changed != 0) {
      sdlLog('Current sample count: ${1 << currentSampleCount}');
    }

    return true;
  }

  @override
  bool draw(Context context) {
    final cmdbuf = context.commandBuffer;
    final swapchainTexture = context.swapchainTexture;
    final w = context.swapchainWidth;
    final h = context.swapchainHeight;

    if (swapchainTexture == nullptr || sampleCounts == 0) {
      return false;
    }

    final targetTexture = msaaRenderTextures[currentSampleCount];
    final isSample1 = (currentSampleCount == 0);

    final colorTargetInfo = SdlxGpuColorTargetInfo(
      texture: targetTexture,
      clearColor: const SdlxFColor(1, 1, 1),
      loadOp: SdlkGpuLoadop.clear,
      storeOp: isSample1 ? SdlkGpuStoreop.store : SdlkGpuStoreop.resolve,
      resolveTexture: isSample1 ? nullptr : resolveTexture,
    );

    final renderPass = sdlxBeginGpuRenderPass(cmdbuf, [colorTargetInfo]);
    sdlBindGpuGraphicsPipeline(renderPass, pipelines[currentSampleCount]);
    sdlDrawGpuPrimitives(renderPass, 3, 1, 0, 0);
    sdlEndGpuRenderPass(renderPass);

    final blitSourceTexture = isSample1 ? targetTexture : resolveTexture;

    sdlxBlitGpuTexture(
      cmdbuf,
      SdlxGpuBlitInfo(
        source: SdlxGpuBlitRegion(
          texture: blitSourceTexture,
          x: 160,
          //y: 0,
          w: 320,
          h: 240,
        ),
        destination: SdlxGpuBlitRegion(texture: swapchainTexture, w: w, h: h),
        loadOp: SdlkGpuLoadop.dontCare,
        filter: SdlkGpuFilter.linear,
      ),
    );

    return true;
  }

  @override
  void quit(Context context) {
    for (var i = 0; i < sampleCounts; i++) {
      if (pipelines[i] != nullptr) {
        sdlReleaseGpuGraphicsPipeline(context.device, pipelines[i]);
      }
      if (msaaRenderTextures[i] != nullptr) {
        sdlReleaseGpuTexture(context.device, msaaRenderTextures[i]);
      }
    }
    pipelines.clear();
    msaaRenderTextures.clear();

    if (resolveTexture != nullptr) {
      sdlReleaseGpuTexture(context.device, resolveTexture);
      resolveTexture = nullptr;
    }

    currentSampleCount = 0;
  }
}

void main() {
  App.run([TriangleMSAA()]);
}
