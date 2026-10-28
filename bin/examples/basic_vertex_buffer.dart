// https://github.com/TheSpydog/SDL_gpu_examples/blob/main/Examples/BasicVertexBuffer.c
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

class BasicVertexBuffer extends Common {
  @override
  String get exampleName => 'BasicVertexBuffer';

  Pointer<SdlGpuGraphicsPipeline> pipeline = nullptr;
  Pointer<SdlGpuBuffer> vertexBuffer = nullptr;

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
    // Clean up shader resources
    sdlReleaseGpuShader(context.device, vertexShader);
    sdlReleaseGpuShader(context.device, fragmentShader);
    // Create the vertex buffer
    vertexBuffer = sdlxCreateGpuBuffer(
      context.device,
      SdlxGpuBufferCreateInfo(
        usage: SdlkGpuBufferusage.vertex,
        size: sizeOf<PositionColorVertex>() * 3,
      ),
    );
    // To get data into the vertex buffer, we have to use a transfer buffer
    final transferBuffer = sdlxCreateGpuTransferBuffer(
      context.device,
      SdlxGpuTransferBufferCreateInfo(
        //usage: SdlkGpuTransferbufferusage.upload,
        size: sizeOf<PositionColorVertex>() * 3,
      ),
    );
    final transferData = sdlMapGpuTransferBuffer(
      context.device,
      transferBuffer,
      false,
    ).cast<PositionColorVertex>();
    transferData[0].setFromList([-1, -1, 0, 255, 0, 0, 255]);
    transferData[1].setFromList([1, -1, 0, 0, 255, 0, 255]);
    transferData[2].setFromList([0, 1, 0, 0, 0, 255, 255]);
    sdlUnmapGpuTransferBuffer(context.device, transferBuffer);
    // Upload the transfer data to the vertex buffer
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
        size: sizeOf<PositionColorVertex>() * 3,
      ),
    );
    sdlEndGpuCopyPass(copyPass);
    sdlSubmitGpuCommandBuffer(uploadCommandBuffer);
    sdlReleaseGpuTransferBuffer(context.device, transferBuffer);
    return true;
  }

  @override
  void quit(Context context) {
    if (vertexBuffer != nullptr) {
      sdlReleaseGpuBuffer(context.device, vertexBuffer);
      vertexBuffer = nullptr;
    }
    if (pipeline != nullptr) {
      sdlReleaseGpuGraphicsPipeline(context.device, pipeline);
      pipeline = nullptr;
    }
  }

  @override
  bool draw(Context context) {
    sdlBindGpuGraphicsPipeline(context.renderPass, pipeline);
    sdlxBindGpuVertexBuffers(context.renderPass, [
      SdlxGpuBufferBinding(buffer: vertexBuffer),
    ]);
    sdlDrawGpuPrimitives(context.renderPass, 3, 1, 0, 0);
    return true;
  }
}

void main() {
  App.run([BasicVertexBuffer()]);
}
