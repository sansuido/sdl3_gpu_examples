// https://github.com/TheSpydog/SDL_gpu_examples/blob/main/Examples/BasicStencil.c
import 'dart:ffi';
import 'package:sdl3/sdl3.dart';
import 'package:sdl3_gpu_examples/sdl3_gpu_examples.dart';

const gVertexSource = '''
struct Input
{
    float3 Position : TEXCOORD0;
    float4 Color : TEXCOORD1;
};

struct Output
{
    float4 Color : TEXCOORD0;
    float4 Position : SV_Position;
};

Output main(Input input)
{
    Output output;
    output.Color = input.Color;
    output.Position = float4(input.Position, 1.0f);
    return output;
}
''';

const gFragmentSource = '''
float4 main(float4 Color : TEXCOORD0) : SV_Target0
{
    return Color;
}
''';

final class PositionColorVertex extends Struct {
  @Float()
  external double x;
  @Float()
  external double y;
  @Float()
  external double z;
  @Uint8()
  external int r;
  @Uint8()
  external int g;
  @Uint8()
  external int b;
  @Uint8()
  external int a;

  void setFromList(List<double> list) {
    if (list.length >= 7) {
      x = list[0];
      y = list[1];
      z = list[2];
      r = list[3].toInt();
      g = list[4].toInt();
      b = list[5].toInt();
      a = list[6].toInt();
    }
  }
}

class BasicStencil extends Common {
  @override
  String get exampleName => 'BasicStencil';

  Pointer<SdlGpuGraphicsPipeline> maskerPipeline = nullptr;
  Pointer<SdlGpuGraphicsPipeline> maskeePipeline = nullptr;
  Pointer<SdlGpuBuffer> vertexBuffer = nullptr;
  Pointer<SdlGpuTexture> depthStencilTexture = nullptr;

  @override
  bool init(Context context) {
    var depthStencilFormat = 0;
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
    if (sdlGpuTextureSupportsFormat(
      context.device,
      SdlkGpuTextureformat.d24UnormS8Uint,
      SdlkGpuTexturetype.on2D,
      SdlkGpuTextureusage.depthStencilTarget,
    )) {
      depthStencilFormat = SdlkGpuTextureformat.d24UnormS8Uint;
    } else if (sdlGpuTextureSupportsFormat(
      context.device,
      SdlkGpuTextureformat.d32FloatS8Uint,
      SdlkGpuTexturetype.on2D,
      SdlkGpuTextureusage.depthStencilTarget,
    )) {
      depthStencilFormat = SdlkGpuTextureformat.d32FloatS8Uint;
    } else {
      sdlLog('Stencil formats not supported!');
      return false;
    }

    final pipelineCreateInfo = SdlxGpuGraphicsPipelineCreateInfo()
      ..targetInfo.colorTargetDescriptions = [
        SdlxGpuColorTargetDescription()
          ..format = sdlGetGpuSwapchainTextureFormat(
            context.device,
            context.window,
          ),
      ]
      ..targetInfo.hasDepthStencilTarget = 1
      ..targetInfo.depthStencilFormat = depthStencilFormat
      ..depthStencilState.enableStencilTest = 1
      ..depthStencilState.frontStencilState.compareOp = SdlkGpuCompareop.never
      ..depthStencilState.frontStencilState.failOp = SdlkGpuStencilop.replace
      ..depthStencilState.frontStencilState.passOp = SdlkGpuStencilop.keep
      ..depthStencilState.frontStencilState.depthFailOp = SdlkGpuStencilop.keep
      ..depthStencilState.backStencilState.compareOp = SdlkGpuCompareop.never
      ..depthStencilState.backStencilState.failOp = SdlkGpuStencilop.replace
      ..depthStencilState.backStencilState.passOp = SdlkGpuStencilop.keep
      ..depthStencilState.backStencilState.depthFailOp = SdlkGpuStencilop.keep
      ..depthStencilState.writeMask = 0xf0f
      ..rasterizerState.cullMode = SdlkGpuCullmode.none
      ..rasterizerState.fillMode = SdlkGpuFillmode.fill
      ..rasterizerState.frontFace = SdlkGpuFrontface.counterClockwise
      ..vertexInputState.vertexBufferDescriptions = [
        SdlxGpuVertexBufferDescription()
          ..slot = 0
          ..inputRate = SdlkGpuVertexinputrate.vertex
          ..instanceStepRate = 0
          ..pitch = sizeOf<PositionColorVertex>(),
      ]
      ..vertexInputState.vertexAttributes = [
        SdlxGpuVertexAttribute()
          ..bufferSlot = 0
          ..format = SdlkGpuVertexelementformat.float3
          ..location = 0
          ..offset = 0,
        SdlxGpuVertexAttribute()
          ..bufferSlot = 0
          ..format = SdlkGpuVertexelementformat.ubyte4Norm
          ..location = 1
          ..offset = sizeOf<Float>() * 3,
      ]
      ..primitiveType = SdlkGpuPrimitivetype.trianglelist
      ..vertexShader = vertexShader
      ..fragmentShader = fragmentShader;
    maskerPipeline = sdlxCreateGpuGraphicsPipeline(
      context.device,
      pipelineCreateInfo,
    );
    if (maskerPipeline == nullptr) {
      sdlLog('Failed to create masker pipeline!');
      return false;
    }
    pipelineCreateInfo
      ..depthStencilState.enableStencilTest = 1
      ..depthStencilState.frontStencilState.compareOp = SdlkGpuCompareop.equal
      ..depthStencilState.frontStencilState.failOp = SdlkGpuStencilop.keep
      ..depthStencilState.frontStencilState.passOp = SdlkGpuStencilop.keep
      ..depthStencilState.frontStencilState.depthFailOp = SdlkGpuStencilop.keep
      ..depthStencilState.backStencilState.compareOp = SdlkGpuCompareop.never
      ..depthStencilState.backStencilState.failOp = SdlkGpuStencilop.keep
      ..depthStencilState.backStencilState.passOp = SdlkGpuStencilop.keep
      ..depthStencilState.backStencilState.depthFailOp = SdlkGpuStencilop.keep
      ..depthStencilState.compareMask = 0xff
      ..depthStencilState.writeMask = 0;
    maskeePipeline = sdlxCreateGpuGraphicsPipeline(
      context.device,
      pipelineCreateInfo,
    );
    if (maskeePipeline == nullptr) {
      sdlLog('Failed to create maskee pipeline!');
      return false;
    }
    sdlReleaseGpuShader(context.device, vertexShader);
    sdlReleaseGpuShader(context.device, fragmentShader);
    // Create the vertex buffer
    {
      final bufferCreateInfo = SdlxGpuBufferCreateInfo()
        ..usage = SdlkGpuBufferusage.vertex
        ..size = sizeOf<PositionColorVertex>() * 6;
      vertexBuffer = sdlxCreateGpuBuffer(context.device, bufferCreateInfo);
    }
    final size = SdlxPoint();
    sdlxGetWindowSizeInPixels(context.window, size);
    depthStencilTexture = sdlxCreateGpuTexture(
      context.device,
      SdlxGpuTextureCreateInfo()
        ..type = SdlkGpuTexturetype.on2D
        ..width = size.x
        ..height = size.y
        ..layerCountOrDepth = 1
        ..numLevels = 1
        ..sampleCount = SdlkGpuSamplecount.on1
        ..format = depthStencilFormat
        ..usage = SdlkGpuTextureusage.depthStencilTarget,
    );
    // To get data into the vertex buffer, we have to use a transfer buffer
    final transferBuffer = sdlxCreateGpuTransferBuffer(
      context.device,
      SdlxGpuTransferBufferCreateInfo()
        ..usage = SdlkGpuTransferbufferusage.upload
        ..size = sizeOf<PositionColorVertex>() * 6,
    );
    final transferData = sdlMapGpuTransferBuffer(
      context.device,
      transferBuffer,
      false,
    ).cast<PositionColorVertex>();
    transferData[0].setFromList([-0.5, -0.5, 0, 255, 255, 0, 255]);
    transferData[1].setFromList([0.5, -0.5, 0, 255, 255, 0, 255]);
    transferData[2].setFromList([0, 0.5, 0, 255, 255, 0, 255]);
    transferData[3].setFromList([-1, -1, 0, 255, 0, 0, 255]);
    transferData[4].setFromList([1, -1, 0, 0, 255, 0, 255]);
    transferData[5].setFromList([0, 1, 0, 0, 0, 255, 255]);
    sdlUnmapGpuTransferBuffer(context.device, transferBuffer);
    // Upload the transfer data to the vertex buffer
    final uploadCommandBuffer = sdlAcquireGpuCommandBuffer(context.device);
    final copyPass = sdlBeginGpuCopyPass(uploadCommandBuffer);
    final transferBufferLocation = SdlxGpuTransferBufferLocation()
      ..transferBuffer = transferBuffer
      ..offset = 0;
    final bufferRegion = SdlxGpuBufferRegion()
      ..buffer = vertexBuffer
      ..offset = 0
      ..size = sizeOf<PositionColorVertex>() * 6;
    sdlxUploadToGpuBuffer(
      copyPass,
      transferBufferLocation,
      bufferRegion,
      false,
    );
    sdlEndGpuCopyPass(copyPass);
    sdlSubmitGpuCommandBuffer(uploadCommandBuffer);
    sdlReleaseGpuTransferBuffer(context.device, transferBuffer);

    depthStencilTargetInfo = SdlxGpuDepthStencilTargetInfo()
      ..texture = depthStencilTexture
      ..cycle = 1
      ..clearDepth = 0
      ..clearStencil = 0
      ..loadOp = SdlkGpuLoadop.clear
      ..storeOp = SdlkGpuStoreop.dontCare
      ..stencilLoadOp = SdlkGpuLoadop.clear
      ..stencilStoreOp = SdlkGpuStoreop.dontCare;
    return true;
  }

  @override
  bool draw(Context context) {
    sdlxBindGpuVertexBuffers(
      context.renderPass,
      bindings: [
        SdlxGpuBufferBinding()
          ..buffer = vertexBuffer
          ..offset = 0,
      ],
    );
    sdlSetGpuStencilReference(context.renderPass, 1);
    sdlBindGpuGraphicsPipeline(context.renderPass, maskerPipeline);
    sdlDrawGpuPrimitives(context.renderPass, 3, 1, 0, 0);
    sdlSetGpuStencilReference(context.renderPass, 0);
    sdlBindGpuGraphicsPipeline(context.renderPass, maskeePipeline);
    sdlDrawGpuPrimitives(context.renderPass, 3, 1, 3, 0);
    return true;
  }

  @override
  void quit(Context context) {
    if (maskerPipeline != nullptr) {
      sdlReleaseGpuGraphicsPipeline(context.device, maskerPipeline);
      maskerPipeline = nullptr;
    }
    if (maskeePipeline != nullptr) {
      sdlReleaseGpuGraphicsPipeline(context.device, maskeePipeline);
      maskeePipeline = nullptr;
    }
    if (depthStencilTexture != nullptr) {
      sdlReleaseGpuTexture(context.device, depthStencilTexture);
    }
    if (vertexBuffer != nullptr) {
      sdlReleaseGpuBuffer(context.device, vertexBuffer);
      vertexBuffer = nullptr;
    }
  }
}

void main() {
  App.run([BasicStencil()]);
}
