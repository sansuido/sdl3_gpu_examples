// https://github.com/TheSpydog/SDL_gpu_examples/blob/main/Examples/BasicTriangle.c
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

class BasicTriangle extends Common {
  @override
  String get exampleName => 'BasicTriangle';

  Pointer<SdlGpuGraphicsPipeline> fillPipeline = nullptr;
  Pointer<SdlGpuGraphicsPipeline> linePipeline = nullptr;
  late SdlxGpuViewport smallViewport;
  late SdlxRect scissorRect;
  var useWireframeMode = false;
  var useSmallViewport = false;
  var useScissorRect = false;

  @override
  bool init(Context context) {
    useWireframeMode = false;
    useSmallViewport = false;
    useScissorRect = false;
    smallViewport = SdlxGpuViewport()
      ..x = 160
      ..y = 120
      ..w = 320
      ..h = 240
      ..minDepth = 0.1
      ..maxDepth = 1.0;
    scissorRect = SdlxRect()
      ..x = 230
      ..y = 240
      ..w = 320
      ..h = 240;
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

    final pipelineCreateInfo = SdlxGpuGraphicsPipelineCreateInfo()
      ..targetInfo.colorTargetDescriptions = [
        SdlxGpuColorTargetDescription()
          ..format = sdlGetGpuSwapchainTextureFormat(
            context.device,
            context.window,
          ),
      ]
      ..primitiveType = SdlkGpuPrimitivetype.trianglelist
      ..vertexShader = vertexShader
      ..fragmentShader = fragmentShader;
    fillPipeline = sdlxCreateGpuGraphicsPipeline(
      context.device,
      pipelineCreateInfo..rasterizerState.fillMode = SdlkGpuFillmode.fill,
    );
    linePipeline = sdlxCreateGpuGraphicsPipeline(
      context.device,
      pipelineCreateInfo..rasterizerState.fillMode = SdlkGpuFillmode.line,
    );
    // Clean up shader resources
    sdlReleaseGpuShader(context.device, vertexShader);
    sdlReleaseGpuShader(context.device, fragmentShader);
    if (fillPipeline == nullptr) {
      sdlLog('Failed to create fill pipeline!');
      return false;
    }
    if (linePipeline == nullptr) {
      sdlLog('Failed to create line pipeline!');
      return false;
    }
    // Finally, print instructions!
    sdlLog('Press Left to toggle wireframe mode');
    sdlLog('Press Down to toggle small viewport');
    sdlLog('Press Right to toggle scissor rect');
    return true;
  }

  @override
  bool update(Context context) {
    if (context.leftPressed) {
      useWireframeMode = !useWireframeMode;
    }
    if (context.downPressed) {
      useSmallViewport = !useSmallViewport;
    }
    if (context.rightPressed) {
      useScissorRect = !useScissorRect;
    }
    return true;
  }

  @override
  bool draw(Context context) {
    if (useSmallViewport) {
      sdlxSetGpuViewport(context.renderPass, smallViewport);
    }
    if (useScissorRect) {
      sdlxSetGpuScissor(context.renderPass, scissorRect);
    }
    if (useWireframeMode) {
      sdlBindGpuGraphicsPipeline(context.renderPass, linePipeline);
    } else {
      sdlBindGpuGraphicsPipeline(context.renderPass, fillPipeline);
    }
    sdlDrawGpuPrimitives(context.renderPass, 3, 1, 0, 0);
    return true;
  }

  @override
  void quit(Context context) {
    if (fillPipeline != nullptr) {
      sdlReleaseGpuGraphicsPipeline(context.device, fillPipeline);
      fillPipeline = nullptr;
    }
    if (linePipeline != nullptr) {
      sdlReleaseGpuGraphicsPipeline(context.device, linePipeline);
      linePipeline = nullptr;
    }
  }
}

void main() {
  App.run([BasicTriangle()]);
}
