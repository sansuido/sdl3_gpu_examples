// https://github.com/TheSpydog/SDL_gpu_examples/blob/main/Examples/InstancedIndexed.c
import 'dart:ffi';
import 'package:sdl3/sdl3.dart';
import 'package:sdl3_gpu_examples/sdl3_gpu_examples.dart';

const gVertexSource = '''
struct Input
{
    float3 Position : TEXCOORD0;
    float4 Color : TEXCOORD1;
    uint InstanceIndex : SV_InstanceID;
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
    float3 pos = (input.Position * 0.25f) - float3(0.75f, 0.75f, 0.0f);
    pos.x += (float(input.InstanceIndex % 4) * 0.5f);
    pos.y += (floor(float(input.InstanceIndex / 4)) * 0.5f);
    output.Position = float4(pos, 1.0f);
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

class InstancedIndexed extends Common {
  @override
  String get exampleName => 'InstancedIndexed';

  Pointer<SdlGpuGraphicsPipeline> pipeline = nullptr;
  Pointer<SdlGpuBuffer> vertexBuffer = nullptr;
  Pointer<SdlGpuBuffer> indexBuffer = nullptr;
  var useVertexOffset = false;
  var useIndexOffset = false;
  var useIndexBuffer = true;

  @override
  bool init(Context context) {
    useVertexOffset = false;
    useIndexOffset = false;
    useIndexBuffer = true;
    // Create the shaders
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
    // Create the pipeline
    final pipelineCreateInfo = SdlxGpuGraphicsPipelineCreateInfo()
      ..targetInfo.colorTargetDescriptions = [
        // color target
        SdlxGpuColorTargetDescription()
          ..format = sdlGetGpuSwapchainTextureFormat(
            context.device,
            context.window,
          ),
      ]
      ..vertexInputState.vertexBufferDescriptions = [
        // vertex buffer
        SdlxGpuVertexBufferDescription()
          ..slot = 0
          ..inputRate = SdlkGpuVertexinputrate.vertex
          ..instanceStepRate = 0
          ..pitch = sizeOf<PositionColorVertex>(),
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
          ..format = SdlkGpuVertexelementformat.ubyte4Norm
          ..location = 1
          ..offset = sizeOf<Float>() * 3,
      ]
      ..primitiveType = SdlkGpuPrimitivetype.trianglelist
      ..vertexShader = vertexShader
      ..fragmentShader = fragmentShader;
    //      ..rasterizerState.fillMode = SdlkGpuFillmode.fill;
    pipeline = sdlxCreateGpuGraphicsPipeline(
      context.device,
      pipelineCreateInfo,
    );
    if (pipeline == nullptr) {
      sdlLog('Failed to create pipeline!');
      return false;
    }
    // Clean up shader resources
    sdlReleaseGpuShader(context.device, vertexShader);
    sdlReleaseGpuShader(context.device, fragmentShader);
    // Create the vertex and index buffers
    vertexBuffer = sdlxCreateGpuBuffer(
      context.device,
      SdlxGpuBufferCreateInfo()
        ..usage = SdlkGpuBufferusage.vertex
        ..size = sizeOf<PositionColorVertex>() * 9,
    );
    indexBuffer = sdlxCreateGpuBuffer(
      context.device,
      SdlxGpuBufferCreateInfo()
        ..usage = SdlkGpuBufferusage.index
        ..size = sizeOf<Uint16>() * 6,
    );
    // Set the buffer data
    final transferBuffer = sdlxCreateGpuTransferBuffer(
      context.device,
      SdlxGpuTransferBufferCreateInfo()
        ..usage = SdlkGpuTransferbufferusage.upload
        ..size = sizeOf<PositionColorVertex>() * 9 + sizeOf<Uint16>() * 6,
    );
    final transferData = sdlMapGpuTransferBuffer(
      context.device,
      transferBuffer,
      false,
    ).cast<PositionColorVertex>();
    transferData[0].setFromList([-1, -1, 0, 255, 0, 0, 255]);
    transferData[1].setFromList([1, -1, 0, 0, 255, 0, 255]);
    transferData[2].setFromList([0, 1, 0, 0, 0, 255, 255]);
    transferData[3].setFromList([-1, -1, 0, 255, 165, 0, 255]);
    transferData[4].setFromList([1, -1, 0, 0, 128, 0, 255]);
    transferData[5].setFromList([0, 1, 0, 0, 255, 255, 255]);
    transferData[6].setFromList([-1, -1, 0, 255, 255, 255, 255]);
    transferData[7].setFromList([1, -1, 0, 255, 255, 255, 255]);
    transferData[8].setFromList([0, 1, 0, 255, 255, 255, 255]);
    final indexData = (transferData + 9).cast<Uint16>();
    for (var i = 0; i < 6; i++) {
      indexData[i] = i;
    }
    sdlUnmapGpuTransferBuffer(context.device, transferBuffer);
    // Upload the transfer data to the vertex and index buffer
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
        ..size = sizeOf<PositionColorVertex>() * 9,
      false,
    );
    sdlxUploadToGpuBuffer(
      copyPass,
      SdlxGpuTransferBufferLocation()
        ..transferBuffer = transferBuffer
        ..offset = sizeOf<PositionColorVertex>() * 9,
      SdlxGpuBufferRegion()
        ..buffer = indexBuffer
        ..offset = 0
        ..size = sizeOf<Uint16>() * 6,
      false,
    );
    sdlEndGpuCopyPass(copyPass);
    sdlSubmitGpuCommandBuffer(uploadCommandBuffer);
    sdlReleaseGpuTransferBuffer(context.device, transferBuffer);
    return true;
  }

  @override
  bool update(Context context) {
    if (context.leftPressed) {
      useVertexOffset = !useVertexOffset;
      sdlLog('Using vertex offset: ${useVertexOffset ? 'true' : 'false'}');
    }
    if (context.rightPressed) {
      useIndexOffset = !useIndexOffset;
      sdlLog('Using index offset: ${useIndexOffset ? 'true' : 'false'}');
    }
    if (context.upPressed) {
      useIndexBuffer = !useIndexBuffer;
      sdlLog('Using index buffer: ${useIndexBuffer ? 'true' : 'false'}');
    }
    return true;
  }

  @override
  bool draw(Context context) {
    final vertexOffset = useVertexOffset ? 3 : 0;
    final indexOffset = useIndexOffset ? 3 : 0;
    sdlBindGpuGraphicsPipeline(context.renderPass, pipeline);
    sdlxBindGpuVertexBuffers(
      context.renderPass,
      bindings: [
        SdlxGpuBufferBinding()
          ..buffer = vertexBuffer
          ..offset = 0,
      ],
    );
    if (useIndexBuffer) {
      sdlxBindGpuIndexBuffer(
        context.renderPass,
        SdlxGpuBufferBinding()
          ..buffer = indexBuffer
          ..offset = 0,
        SdlkGpuIndexelementsize.on16Bit,
      );
      sdlDrawGpuIndexedPrimitives(
        context.renderPass,
        3,
        16,
        indexOffset,
        vertexOffset,
        0,
      );
    } else {
      sdlDrawGpuPrimitives(context.renderPass, 3, 16, vertexOffset, 0);
    }
    return true;
  }

  @override
  void quit(Context context) {
    if (vertexBuffer != nullptr) {
      sdlReleaseGpuBuffer(context.device, vertexBuffer);
      vertexBuffer = nullptr;
    }
    if (indexBuffer != nullptr) {
      sdlReleaseGpuBuffer(context.device, indexBuffer);
      indexBuffer = nullptr;
    }
    if (pipeline != nullptr) {
      sdlReleaseGpuGraphicsPipeline(context.device, pipeline);
      pipeline = nullptr;
    }
  }
}

void main() {
  App.run([InstancedIndexed()]);
}
