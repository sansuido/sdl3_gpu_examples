// https://github.com/TheSpydog/SDL_gpu_examples/blob/main/Examples/BasicCompute.c
import 'dart:ffi';
import 'package:sdl3/sdl3.dart';
import 'package:sdl3_gpu_examples/sdl3_gpu_examples.dart';

const gVertexSource = '''
struct Input
{
    float3 Position : TEXCOORD0;
    float2 TexCoord : TEXCOORD1;
};

struct Output
{
    float2 TexCoord : TEXCOORD0;
    float4 Position : SV_Position;
};

Output main(Input input)
{
    Output output;
    output.TexCoord = input.TexCoord;
    output.Position = float4(input.Position, 1.0f);
    return output;
}
''';

const gFragmentSource = '''
Texture2D<float4> Texture : register(t0, space2);
SamplerState Sampler : register(s0, space2);

float4 main(float2 TexCoord : TEXCOORD0) : SV_Target0
{
    return Texture.Sample(Sampler, TexCoord);
}
''';

const gComputeSource = '''
[[vk::image_format("rgba8")]]
RWTexture2D<float4> outImage : register(u0, space1);

[numthreads(8, 8, 1)]
void main(uint3 GlobalInvocationID : SV_DispatchThreadID)
{
    int2 coord = int2(GlobalInvocationID.xy);
    outImage[coord] = float4(1.0f, 1.0f, 0.0f, 1.0f);
}
''';

final class PositionTextureVertex extends Struct {
  @Float()
  external double x;
  @Float()
  external double y;
  @Float()
  external double z;
  @Float()
  external double u;
  @Float()
  external double v;

  void setFromList(List<double> list) {
    if (list.length >= 5) {
      x = list[0];
      y = list[1];
      z = list[2];
      u = list[3];
      v = list[4];
    }
  }
}

class BasicCompute extends Common {
  @override
  String get exampleName => 'BasicCompute';
  Pointer<SdlGpuGraphicsPipeline> pipeline = nullptr;
  Pointer<SdlGpuBuffer> vertexBuffer = nullptr;
  Pointer<SdlGpuSampler> sampler = nullptr;
  Pointer<SdlGpuTexture> texture = nullptr;

  @override
  bool init(Context context) {
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
      numSamplers: 1,
    );
    if (fragmentShader == nullptr) {
      sdlLog('Failed to create fragment shader!');
      return false;
    }
    final computePipeline = createComputePipelineFromSource(
      context.device,
      gComputeSource,
      format: format,
      numReadwriteStorageTextures: 1,
      threadcountX: 8,
      threadcountY: 8,
      threadcountZ: 1,
    );
    if (computePipeline == nullptr) {
      sdlLog('Failed to create compute shader!');
      return false;
    }
    // Create the pipeline
    final pipelineCreateInfo = SdlxGpuGraphicsPipelineCreateInfo()
      ..targetInfo.colorTargetDescriptions = [
        // color target
        SdlxGpuColorTargetDescription()
          ..format = sdlGetGpuSwapchainTextureFormat(
            context.device,
            context.window,
          )
          ..blendState.enableBlend = 1
          ..blendState.alphaBlendOp = SdlkGpuBlendop.add
          ..blendState.colorBlendOp = SdlkGpuBlendop.add
          ..blendState.srcColorBlendfactor = SdlkGpuBlendfactor.srcAlpha
          ..blendState.srcAlphaBlendfactor = SdlkGpuBlendfactor.srcAlpha
          ..blendState.dstColorBlendfactor = SdlkGpuBlendfactor.oneMinusSrcAlpha
          ..blendState.dstAlphaBlendfactor =
              SdlkGpuBlendfactor.oneMinusSrcAlpha,
      ]
      ..vertexInputState.vertexBufferDescriptions = [
        SdlxGpuVertexBufferDescription()
          ..slot = 0
          ..inputRate = SdlkGpuVertexinputrate.vertex
          ..instanceStepRate = 0
          ..pitch = sizeOf<PositionTextureVertex>(),
      ]
      ..vertexInputState.vertexAttributes = [
        // vertex attribute[0]
        SdlxGpuVertexAttribute()
          ..bufferSlot = 0
          ..format = SdlkGpuVertexelementformat.float3
          ..location = 0
          ..offset = 0,
        // vertex attribute[1]
        SdlxGpuVertexAttribute()
          ..bufferSlot = 0
          ..format = SdlkGpuVertexelementformat.float2
          ..location = 1
          ..offset = sizeOf<Float>() * 3,
      ]
      ..primitiveType = SdlkGpuPrimitivetype.trianglelist
      ..vertexShader = vertexShader
      ..fragmentShader = fragmentShader;
    pipeline = sdlxCreateGpuGraphicsPipeline(
      context.device,
      pipelineCreateInfo,
    );
    if (pipeline == nullptr) {
      sdlLog('Failed to create pipeline!');
      return false;
    }
    sdlReleaseGpuShader(context.device, vertexShader);
    sdlReleaseGpuShader(context.device, fragmentShader);
    final size = SdlxPoint();
    sdlxGetWindowSizeInPixels(context.window, size);
    texture = sdlxCreateGpuTexture(
      context.device,
      SdlxGpuTextureCreateInfo()
        ..type = SdlkGpuTexturetype.on2D
        ..format = SdlkGpuTextureformat.r8G8B8A8Unorm
        ..width = size.x
        ..height = size.y
        ..layerCountOrDepth = 1
        ..numLevels = 1
        ..usage =
            SdlkGpuTextureusage.computeStorageWrite |
            SdlkGpuTextureusage.sampler,
    );
    sampler = sdlxCreateGpuSampler(
      context.device,
      SdlxGpuSamplerCreateInfo()
        ..addressModeU = SdlkGpuSampleraddressmode.repeat
        ..addressModeV = SdlkGpuSampleraddressmode.repeat,
    );
    vertexBuffer = sdlxCreateGpuBuffer(
      context.device,
      SdlxGpuBufferCreateInfo()
        ..usage = SdlkGpuBufferusage.vertex
        ..size = sizeOf<PositionTextureVertex>() * 6,
    );
    final transferBuffer = sdlxCreateGpuTransferBuffer(
      context.device,
      SdlxGpuTransferBufferCreateInfo()
        ..usage = SdlkGpuTransferbufferusage.upload
        ..size = sizeOf<PositionTextureVertex>() * 6,
    );
    final transferData = sdlMapGpuTransferBuffer(
      context.device,
      transferBuffer,
      false,
    ).cast<PositionTextureVertex>();

    transferData[0].setFromList([-1, -1, 0, 0, 0]);
    transferData[1].setFromList([1, -1, 0, 1, 0]);
    transferData[2].setFromList([1, 1, 0, 1, 1]);
    transferData[3].setFromList([-1, -1, 0, 0, 0]);
    transferData[4].setFromList([1, 1, 0, 1, 1]);
    transferData[5].setFromList([-1, 1, 0, 0, 1]);
    sdlUnmapGpuTransferBuffer(context.device, transferBuffer);
    final uploadCommandBuffer = sdlAcquireGpuCommandBuffer(context.device);
    final copyPass = sdlBeginGpuCopyPass(uploadCommandBuffer);
    sdlxUploadToGpuBuffer(
      copyPass,
      SdlxGpuTransferBufferLocation()
        ..transferBuffer = transferBuffer
        ..offset = 0,
      SdlxGpuBufferRegion()
        ..buffer = vertexBuffer
        ..offset = 0
        ..size = sizeOf<PositionTextureVertex>() * 6,
      false,
    );
    sdlEndGpuCopyPass(copyPass);

    final computePass = sdlxBeginGpuComputePass(
      uploadCommandBuffer,
      textures: [SdlxGpuStorageTextureReadWriteBinding()..texture = texture],
    );
    sdlBindGpuComputePipeline(computePass, computePipeline);
    sdlDispatchGpuCompute(computePass, size.x ~/ 8, size.y ~/ 8, 1);
    sdlEndGpuComputePass(computePass);

    sdlSubmitGpuCommandBuffer(uploadCommandBuffer);

    sdlReleaseGpuComputePipeline(context.device, computePipeline);
    sdlReleaseGpuTransferBuffer(context.device, transferBuffer);
    return true;
  }

  @override
  bool draw(Context context) {
    sdlBindGpuGraphicsPipeline(context.renderPass, pipeline);
    sdlxBindGpuVertexBuffers(
      context.renderPass,
      bindings: [
        SdlxGpuBufferBinding()
          ..buffer = vertexBuffer
          ..offset = 0,
      ],
    );
    sdlxBindGpuFragmentSamplers(
      context.renderPass,
      bindings: [
        SdlxGpuTextureSamplerBinding()
          ..texture = texture
          ..sampler = sampler,
      ],
    );
    sdlDrawGpuPrimitives(context.renderPass, 6, 1, 0, 0);
    return true;
  }

  @override
  void quit(Context context) {
    if (pipeline != nullptr) {
      sdlReleaseGpuGraphicsPipeline(context.device, pipeline);
      pipeline = nullptr;
    }
    if (texture != nullptr) {
      sdlReleaseGpuTexture(context.device, texture);
    }
    if (sampler != nullptr) {
      sdlReleaseGpuSampler(context.device, sampler);
      sampler = nullptr;
    }
    if (vertexBuffer != nullptr) {
      sdlReleaseGpuBuffer(context.device, vertexBuffer);
      vertexBuffer = nullptr;
    }
  }
}

void main() {
  App.run([BasicCompute()]);
}
