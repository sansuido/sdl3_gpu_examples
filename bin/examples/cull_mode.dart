// https://github.com/TheSpydog/SDL_gpu_examples/blob/main/Examples/CullMode.c
import 'dart:ffi';

import 'package:sdl3/sdl3.dart';
import 'package:sdl3_gpu_examples/sdl3_gpu_examples.dart';

const gModeNames = [
  'CCW_CullNone',
  'CCW_CullFront',
  'CCW_CullBack',
  'CW_CullNone',
  'CW_CullFront',
  'CW_CullBack',
];

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

class CullMode extends Common {
  @override
  String get exampleName => 'CullMode';

  var currentMode = 0;

  List<Pointer<SdlGpuGraphicsPipeline>> pipelines = [];
  Pointer<SdlGpuBuffer> vertexBufferCw = nullptr;
  Pointer<SdlGpuBuffer> vertexBufferCcw = nullptr;
  late SdlxGpuViewport leftViewport;
  late SdlxGpuViewport rightViewport;

  @override
  bool init(Context context) {
    leftViewport = const SdlxGpuViewport(w: 320, h: 480);
    rightViewport = const SdlxGpuViewport(x: 320, w: 320, h: 480);
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
    final targetInfo = SdlxGpuGraphicsPipelineTargetInfo(
      colorTargetDescriptions: [
        SdlxGpuColorTargetDescription(
          format: sdlGetGpuSwapchainTextureFormat(
            context.device,
            context.window,
          ),
        ),
      ],
    );
    final vertexInputState = SdlxGpuVertexInputState(
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
    );
    for (var i = 0; i < gModeNames.length; i++) {
      final pipeline = sdlxCreateGpuGraphicsPipeline(
        context.device,
        SdlxGpuGraphicsPipelineCreateInfo(
          targetInfo: targetInfo,
          vertexInputState: vertexInputState,
          //primitiveType: SdlkGpuPrimitivetype.trianglelist,
          vertexShader: vertexShader,
          fragmentShader: fragmentShader,
          rasterizerState: SdlxGpuRasterizerState(
            //fillMode: SdlkGpuFillmode.fill,
            cullMode: i % 3,
            frontFace: i > 2
                ? SdlkGpuFrontface.clockwise
                : SdlkGpuFrontface.counterClockwise,
          ),
        ),
      );
      if (pipeline == nullptr) {
        sdlLog('Failed to create pipeline!');
        return false;
      }
      pipelines.add(pipeline);
    }
    // Clean up shader resources
    sdlReleaseGpuShader(context.device, vertexShader);
    sdlReleaseGpuShader(context.device, fragmentShader);
    // Create the vertex buffer
    {
      final bufferCreateInfo = SdlxGpuBufferCreateInfo(
        usage: SdlkGpuBufferusage.vertex,
        size: sizeOf<PositionColorVertex>() * 3,
      );
      vertexBufferCw = sdlxCreateGpuBuffer(context.device, bufferCreateInfo);
      vertexBufferCcw = sdlxCreateGpuBuffer(context.device, bufferCreateInfo);
    }
    // To get data into the vertex buffer, we have to use a transfer buffer
    Pointer<SdlGpuTransferBuffer> transferBuffer = nullptr;
    {
      final transferBufferCreateInfo = SdlxGpuTransferBufferCreateInfo(
        //usage: SdlkGpuTransferbufferusage.upload,
        size: sizeOf<PositionColorVertex>() * 6,
      );
      transferBuffer = sdlxCreateGpuTransferBuffer(
        context.device,
        transferBufferCreateInfo,
      );
    }
    final transferData = sdlMapGpuTransferBuffer(
      context.device,
      transferBuffer,
      false,
    ).cast<PositionColorVertex>();
    transferData[0].setFromList([-1, -1, 0, 255, 0, 0, 255]);
    transferData[1].setFromList([1, -1, 0, 0, 255, 0, 255]);
    transferData[2].setFromList([0, 1, 0, 0, 0, 255, 255]);
    transferData[3].setFromList([0, 1, 0, 255, 0, 0, 255]);
    transferData[4].setFromList([1, -1, 0, 0, 255, 0, 255]);
    transferData[5].setFromList([-1, -1, 0, 0, 0, 255, 255]);
    sdlUnmapGpuTransferBuffer(context.device, transferBuffer);
    // Upload the transfer data to the vertex buffer
    final uploadCommandBuffer = sdlAcquireGpuCommandBuffer(context.device);
    final copyPass = sdlBeginGpuCopyPass(uploadCommandBuffer);
    //final transferBufferLocation = SdlxGpuTransferBufferLocation();
    //final bufferRegion = SdlxGpuBufferRegion();
    // cw
    {
      final transferBufferLocation = SdlxGpuTransferBufferLocation(
        transferBuffer: transferBuffer,
        //offset: 0,
      );
      final bufferRegion = SdlxGpuBufferRegion(
        buffer: vertexBufferCw,
        //offset: 0,
        size: sizeOf<PositionColorVertex>() * 3,
      );
      sdlxUploadToGpuBuffer(copyPass, transferBufferLocation, bufferRegion);
    }
    // ccw
    {
      final transferBufferLocation = SdlxGpuTransferBufferLocation(
        transferBuffer: transferBuffer,
        offset: sizeOf<PositionColorVertex>() * 3,
      );
      final bufferRegion = SdlxGpuBufferRegion(
        buffer: vertexBufferCcw,
        //offset: 0,
        size: sizeOf<PositionColorVertex>() * 3,
      );
      sdlxUploadToGpuBuffer(copyPass, transferBufferLocation, bufferRegion);
    }
    sdlEndGpuCopyPass(copyPass);
    sdlSubmitGpuCommandBuffer(uploadCommandBuffer);
    sdlReleaseGpuTransferBuffer(context.device, transferBuffer);
    // Finally, print instructions!
    sdlLog('Press Left/Right to switch between modes');
    sdlLog('Current Mode: ${gModeNames[0]}');
    return true;
  }

  @override
  void quit(Context context) {
    if (vertexBufferCw != nullptr) {
      sdlReleaseGpuBuffer(context.device, vertexBufferCw);
      vertexBufferCw = nullptr;
    }
    if (vertexBufferCcw != nullptr) {
      sdlReleaseGpuBuffer(context.device, vertexBufferCcw);
      vertexBufferCcw = nullptr;
    }
    for (final pipeline in pipelines) {
      sdlReleaseGpuGraphicsPipeline(context.device, pipeline);
    }
    pipelines.clear();
  }

  @override
  bool update(Context context) {
    var usage = false;
    if (context.leftPressed) {
      currentMode -= 1;
      if (currentMode < 0) {
        currentMode = pipelines.length - 1;
      }
      usage = true;
    }
    if (context.rightPressed) {
      currentMode += 1;
      if (currentMode >= pipelines.length) {
        currentMode = 0;
      }
      usage = true;
    }
    if (usage) {
      sdlLog('Current Mode: ${gModeNames[currentMode]}');
    }
    return true;
  }

  @override
  bool draw(Context context) {
    sdlBindGpuGraphicsPipeline(context.renderPass, pipelines[currentMode]);
    {
      sdlxSetGpuViewport(context.renderPass, leftViewport);
      sdlxBindGpuVertexBuffers(context.renderPass, [
        SdlxGpuBufferBinding(buffer: vertexBufferCw),
      ]);
      sdlDrawGpuPrimitives(context.renderPass, 3, 1, 0, 0);
    }
    {
      sdlxSetGpuViewport(context.renderPass, rightViewport);
      sdlxBindGpuVertexBuffers(context.renderPass, [
        SdlxGpuBufferBinding(buffer: vertexBufferCcw),
      ]);
      sdlDrawGpuPrimitives(context.renderPass, 3, 1, 0, 0);
    }
    return true;
  }
}

void main() {
  App.run([CullMode()]);
}
