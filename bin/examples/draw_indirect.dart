// https://github.com/TheSpydog/SDL_gpu_examples/blob/main/Examples/DrawIndirect.c
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

class DrawIndirect extends Common {
  @override
  String get exampleName => 'DrawIndirect';

  Pointer<SdlGpuGraphicsPipeline> pipeline = nullptr;
  Pointer<SdlGpuBuffer> vertexBuffer = nullptr;
  Pointer<SdlGpuBuffer> indexBuffer = nullptr;
  Pointer<SdlGpuBuffer> drawBuffer = nullptr;

  @override
  bool init(Context context) {
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
    final pipelineCreateInfo = SdlxGpuGraphicsPipelineCreateInfo(
      targetInfo: SdlxGpuGraphicsPipelineTargetInfo(
        colorTargetDescriptions: [
          SdlxGpuColorTargetDescription(
            format: sdlGetGpuSwapchainTextureFormat(
              context.device,
              context.window,
            ),
          ),
        ],
      ),
      vertexInputState: SdlxGpuVertexInputState(
        vertexBufferDescriptions: [
          SdlxGpuVertexBufferDescription(
            //slot: 0,
            //inputRate: SdlkGpuVertexinputrate.vertex,
            //instanceStepRate: 0,
            pitch: sizeOf<PositionColorVertex>(),
          ),
        ],
        vertexAttributes: [
          const SdlxGpuVertexAttribute(
            //bufferSlot: 0,
            format: SdlkGpuVertexelementformat.float3,
            //location: 0,
            //offset: 0,
          ),
          SdlxGpuVertexAttribute(
            //bufferSlot: 0,
            format: SdlkGpuVertexelementformat.ubyte4Norm,
            location: 1,
            offset: sizeOf<Float>() * 3,
          ),
        ],
      ),
      //primitiveType: SdlkGpuPrimitivetype.trianglelist,
      vertexShader: vertexShader,
      fragmentShader: fragmentShader,
    );
    pipeline = sdlxCreateGpuGraphicsPipeline(
      context.device,
      pipelineCreateInfo,
    );
    sdlReleaseGpuShader(context.device, vertexShader);
    sdlReleaseGpuShader(context.device, fragmentShader);
    // Create the buffers
    final vertexBufferSize = sizeOf<PositionColorVertex>() * 10;
    vertexBuffer = sdlxCreateGpuBuffer(
      context.device,
      SdlxGpuBufferCreateInfo(
        usage: SdlkGpuBufferusage.vertex,
        size: vertexBufferSize,
      ),
    );
    final indexBufferSize = sizeOf<Uint16>() * 6;
    indexBuffer = sdlxCreateGpuBuffer(
      context.device,
      SdlxGpuBufferCreateInfo(
        usage: SdlkGpuBufferusage.index,
        size: indexBufferSize,
      ),
    );
    final drawBufferSize =
        sizeOf<SdlGpuIndexedIndirectDrawCommand>() * 1 +
        sizeOf<SdlGpuIndirectDrawCommand>() * 2;
    drawBuffer = sdlxCreateGpuBuffer(
      context.device,
      SdlxGpuBufferCreateInfo(
        usage: SdlkGpuBufferusage.indirect,
        size: drawBufferSize,
      ),
    );
    // Set the buffer data
    final transferBuffer = sdlxCreateGpuTransferBuffer(
      context.device,
      SdlxGpuTransferBufferCreateInfo(
        //usage: SdlkGpuTransferbufferusage.upload,
        size: vertexBufferSize + indexBufferSize + drawBufferSize,
      ),
    );
    final transferData = sdlMapGpuTransferBuffer(
      context.device,
      transferBuffer,
      false,
    ).cast<PositionColorVertex>();
    transferData[0].setFromList([-1, -1, 0, 255, 0, 0, 255]);
    transferData[1].setFromList([1, -1, 0, 0, 255, 0, 255]);
    transferData[2].setFromList([1, 1, 0, 0, 0, 255, 255]);
    transferData[3].setFromList([-1, 1, 0, 255, 255, 255, 255]);

    transferData[4].setFromList([1, -1, 0, 0, 255, 0, 255]);
    transferData[5].setFromList([0, -1, 0, 0, 0, 255, 255]);
    transferData[6].setFromList([0.5, 1, 0, 255, 0, 0, 255]);
    transferData[7].setFromList([-1, -1, 0, 0, 255, 0, 255]);
    transferData[8].setFromList([0, -1, 0, 0, 0, 255, 255]);
    transferData[9].setFromList([-0.5, 1, 0, 255, 0, 0, 255]);
    final indexData = (transferData + 10).cast<Uint16>();
    indexData[0] = 0;
    indexData[1] = 1;
    indexData[2] = 2;
    indexData[3] = 0;
    indexData[4] = 2;
    indexData[5] = 3;
    final indexedDrawCommandData = (indexData + 6)
        .cast<SdlGpuIndexedIndirectDrawCommand>();
    indexedDrawCommandData[0]
      ..numIndices = 6
      ..numInstances = 1;
    final drawCommandData = (indexedDrawCommandData + 1)
        .cast<SdlGpuIndirectDrawCommand>();
    drawCommandData[0]
      ..numVertices = 3
      ..numInstances = 1
      ..firstVertex = 4;
    drawCommandData[1]
      ..numVertices = 3
      ..numInstances = 1
      ..firstVertex = 7;
    sdlUnmapGpuTransferBuffer(context.device, transferBuffer);
    // Upload the transfer data to the GPU buffers
    final uploadCommandBuffer = sdlAcquireGpuCommandBuffer(context.device);
    final copyPass = sdlBeginGpuCopyPass(uploadCommandBuffer);
    sdlxUploadToGpuBuffer(
      copyPass,
      SdlxGpuTransferBufferLocation(
        transferBuffer: transferBuffer,
        //offset: 0,
      ),
      SdlxGpuBufferRegion(
        buffer: vertexBuffer,
        //offset: 0,
        size: vertexBufferSize,
      ),
    );
    sdlxUploadToGpuBuffer(
      copyPass,
      SdlxGpuTransferBufferLocation(
        transferBuffer: transferBuffer,
        offset: vertexBufferSize,
      ),
      SdlxGpuBufferRegion(
        buffer: indexBuffer,
        //offset: 0,
        size: indexBufferSize,
      ),
    );
    sdlxUploadToGpuBuffer(
      copyPass,
      SdlxGpuTransferBufferLocation(
        transferBuffer: transferBuffer,
        offset: vertexBufferSize + indexBufferSize,
      ),
      SdlxGpuBufferRegion(
        buffer: drawBuffer,
        //offset: 0,
        size: drawBufferSize,
      ),
    );
    sdlEndGpuCopyPass(copyPass);
    sdlSubmitGpuCommandBuffer(uploadCommandBuffer);
    sdlReleaseGpuTransferBuffer(context.device, transferBuffer);
    return true;
  }

  @override
  bool draw(Context context) {
    sdlBindGpuGraphicsPipeline(context.renderPass, pipeline);
    sdlxBindGpuVertexBuffers(context.renderPass, [
      SdlxGpuBufferBinding(buffer: vertexBuffer),
    ]);
    sdlxBindGpuIndexBuffer(
      context.renderPass,
      SdlxGpuBufferBinding(buffer: indexBuffer),
      SdlkGpuIndexelementsize.on16Bit,
    );
    sdlDrawGpuIndexedPrimitivesIndirect(context.renderPass, drawBuffer, 0, 1);
    sdlDrawGpuPrimitivesIndirect(
      context.renderPass,
      drawBuffer,
      sizeOf<SdlGpuIndexedIndirectDrawCommand>(),
      2,
    );
    return true;
  }

  @override
  void quit(Context context) {
    if (pipeline != nullptr) {
      sdlReleaseGpuGraphicsPipeline(context.device, pipeline);
      pipeline = nullptr;
    }
    if (vertexBuffer != nullptr) {
      sdlReleaseGpuBuffer(context.device, vertexBuffer);
      vertexBuffer = nullptr;
    }
    if (indexBuffer != nullptr) {
      sdlReleaseGpuBuffer(context.device, indexBuffer);
      indexBuffer = nullptr;
    }
    if (drawBuffer != nullptr) {
      sdlReleaseGpuBuffer(context.device, drawBuffer);
      drawBuffer = nullptr;
    }
  }
}

void main() {
  App.run([DrawIndirect()]);
}
