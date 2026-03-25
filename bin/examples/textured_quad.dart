// https://github.com/TheSpydog/SDL_gpu_examples/blob/main/Examples/TexturedQuad.c
import 'dart:ffi';
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

class TexturedQuad extends Common {
  @override
  String get exampleName => 'TexturedQuad';
  late int currentSamplerIndex;
  Pointer<SdlGpuGraphicsPipeline> pipeline = nullptr;
  Pointer<SdlGpuBuffer> vertexBuffer = nullptr;
  Pointer<SdlGpuBuffer> indexBuffer = nullptr;
  List<Pointer<SdlGpuSampler>> samplers = [];
  Pointer<SdlGpuTexture> texture = nullptr;

  @override
  bool init(Context context) {
    currentSamplerIndex = 0;
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
    // Clean up shader resources
    sdlReleaseGpuShader(context.device, vertexShader);
    sdlReleaseGpuShader(context.device, fragmentShader);
    // samplers
    // [0]
    samplers
      ..add(
        sdlxCreateGpuSampler(
          context.device,
          SdlxGpuSamplerCreateInfo()
            ..minFilter = SdlkGpuFilter.nearest
            ..magFilter = SdlkGpuFilter.nearest
            ..mipmapMode = SdlkGpuSamplermipmapmode.nearest
            ..addressModeU = SdlkGpuSampleraddressmode.clampToEdge
            ..addressModeV = SdlkGpuSampleraddressmode.clampToEdge
            ..addressModeW = SdlkGpuSampleraddressmode.clampToEdge,
        ),
      )
      // [1]
      ..add(
        sdlxCreateGpuSampler(
          context.device,
          SdlxGpuSamplerCreateInfo()
            ..minFilter = SdlkGpuFilter.nearest
            ..magFilter = SdlkGpuFilter.nearest
            ..mipmapMode = SdlkGpuSamplermipmapmode.nearest
            ..addressModeU = SdlkGpuSampleraddressmode.repeat
            ..addressModeV = SdlkGpuSampleraddressmode.repeat
            ..addressModeW = SdlkGpuSampleraddressmode.repeat,
        ),
      )
      // [2]
      ..add(
        sdlxCreateGpuSampler(
          context.device,
          SdlxGpuSamplerCreateInfo()
            ..minFilter = SdlkGpuFilter.linear
            ..magFilter = SdlkGpuFilter.linear
            ..mipmapMode = SdlkGpuSamplermipmapmode.linear
            ..addressModeU = SdlkGpuSampleraddressmode.clampToEdge
            ..addressModeV = SdlkGpuSampleraddressmode.clampToEdge
            ..addressModeW = SdlkGpuSampleraddressmode.clampToEdge,
        ),
      )
      // [3]
      ..add(
        sdlxCreateGpuSampler(
          context.device,
          SdlxGpuSamplerCreateInfo()
            ..minFilter = SdlkGpuFilter.linear
            ..magFilter = SdlkGpuFilter.linear
            ..mipmapMode = SdlkGpuSamplermipmapmode.linear
            ..addressModeU = SdlkGpuSampleraddressmode.repeat
            ..addressModeV = SdlkGpuSampleraddressmode.repeat
            ..addressModeW = SdlkGpuSampleraddressmode.repeat,
        ),
      )
      // [4]
      ..add(
        sdlxCreateGpuSampler(
          context.device,
          SdlxGpuSamplerCreateInfo()
            ..minFilter = SdlkGpuFilter.linear
            ..magFilter = SdlkGpuFilter.linear
            ..mipmapMode = SdlkGpuSamplermipmapmode.linear
            ..addressModeU = SdlkGpuSampleraddressmode.clampToEdge
            ..addressModeV = SdlkGpuSampleraddressmode.clampToEdge
            ..addressModeW = SdlkGpuSampleraddressmode.clampToEdge
            ..enableAnisotropy = 1
            ..maxAnisotropy = 4,
        ),
      )
      // [5]
      ..add(
        sdlxCreateGpuSampler(
          context.device,
          SdlxGpuSamplerCreateInfo()
            ..minFilter = SdlkGpuFilter.linear
            ..magFilter = SdlkGpuFilter.linear
            ..mipmapMode = SdlkGpuSamplermipmapmode.linear
            ..addressModeU = SdlkGpuSampleraddressmode.repeat
            ..addressModeV = SdlkGpuSampleraddressmode.repeat
            ..addressModeW = SdlkGpuSampleraddressmode.repeat
            ..enableAnisotropy = 1
            ..maxAnisotropy = 4,
        ),
      );
    // Create the GPU resources
    vertexBuffer = sdlxCreateGpuBuffer(
      context.device,
      SdlxGpuBufferCreateInfo()
        ..usage = SdlkGpuBufferusage.vertex
        ..size = sizeOf<PositionTextureVertex>() * 4,
    );
    sdlSetGpuBufferName(
      context.device,
      vertexBuffer,
      'Ravioli Vertex Buffer 🥣',
    );
    indexBuffer = sdlxCreateGpuBuffer(
      context.device,
      SdlxGpuBufferCreateInfo()
        ..usage = SdlkGpuBufferusage.index
        ..size = sizeOf<Uint16>() * 6,
    );

    texture = sdlxCreateGpuTexture(
      context.device,
      SdlxGpuTextureCreateInfo()
        ..type = SdlkGpuTexturetype.on2D
        ..format = SdlkGpuTextureformat.r8G8B8A8Unorm
        ..width = imageData.ref.w
        ..height = imageData.ref.h
        ..layerCountOrDepth = 1
        ..numLevels = 1
        ..usage = SdlkGpuTextureusage.sampler,
    );
    sdlSetGpuTextureName(context.device, texture, 'Ravioli Texture 🖼️');

    // To get data into the vertex buffer, we have to use a transfer buffer
    final bufferTransferBuffer = sdlxCreateGpuTransferBuffer(
      context.device,
      SdlxGpuTransferBufferCreateInfo()
        ..usage = SdlkGpuTransferbufferusage.upload
        ..size = sizeOf<PositionTextureVertex>() * 4 + sizeOf<Uint16>() * 6,
    );
    final transferData = sdlMapGpuTransferBuffer(
      context.device,
      bufferTransferBuffer,
      false,
    ).cast<PositionTextureVertex>();
    transferData[0].setFromList([-1, 1, 0, 0, 0]);
    transferData[1].setFromList([1, 1, 0, 4, 0]);
    transferData[2].setFromList([1, -1, 0, 4, 4]);
    transferData[3].setFromList([-1, -1, 0, 0, 4]);
    final indexData = (transferData + 4).cast<Uint16>();
    indexData[0] = 0;
    indexData[1] = 1;
    indexData[2] = 2;
    indexData[3] = 0;
    indexData[4] = 2;
    indexData[5] = 3;
    sdlUnmapGpuTransferBuffer(context.device, bufferTransferBuffer);
    final textureTransferBuffer = sdlxCreateGpuTransferBuffer(
      context.device,
      SdlxGpuTransferBufferCreateInfo()
        ..usage = SdlkGpuTransferbufferusage.upload
        ..size = imageData.ref.w * imageData.ref.h * 4,
    );
    final textureTranferPointer = sdlMapGpuTransferBuffer(
      context.device,
      textureTransferBuffer,
      false,
    ).cast<Uint8>();
    sdlMemcpy(
      textureTranferPointer,
      imageData.ref.pixels,
      imageData.ref.w * imageData.ref.h * 4,
    );
    sdlUnmapGpuTransferBuffer(context.device, textureTransferBuffer);
    // Upload the transfer data to the GPU resources
    final uploadCommandBuffer = sdlAcquireGpuCommandBuffer(context.device);
    final copyPass = sdlBeginGpuCopyPass(uploadCommandBuffer);
    sdlxUploadToGpuBuffer(
      copyPass,
      SdlxGpuTransferBufferLocation()
        ..transferBuffer = bufferTransferBuffer
        ..offset = 0,
      SdlxGpuBufferRegion()
        ..buffer = vertexBuffer
        ..offset = 0
        ..size = sizeOf<PositionTextureVertex>() * 4,
      false,
    );
    sdlxUploadToGpuBuffer(
      copyPass,
      SdlxGpuTransferBufferLocation()
        ..transferBuffer = bufferTransferBuffer
        ..offset = sizeOf<PositionTextureVertex>() * 4,
      SdlxGpuBufferRegion()
        ..buffer = indexBuffer
        ..offset = 0
        ..size = sizeOf<Uint16>() * 6,
      false,
    );
    sdlxUploadToGpuTexture(
      copyPass,
      SdlxGpuTextureTransferInfo()
        ..transferBuffer = textureTransferBuffer
        ..offset = 0,
      SdlxGpuTextureRegion()
        ..texture = texture
        ..w = imageData.ref.w
        ..h = imageData.ref.h
        ..d = 1,
      false,
    );
    sdlEndGpuCopyPass(copyPass);
    sdlSubmitGpuCommandBuffer(uploadCommandBuffer);
    sdlReleaseGpuTransferBuffer(context.device, bufferTransferBuffer);
    sdlReleaseGpuTransferBuffer(context.device, textureTransferBuffer);
    imageData.destroy();

    // Finally, print instructions!
    sdlLog('Press Left/Right to switch between sampler states');
    sdlLog('Setting sampler state to: ${gSamplerNames[currentSamplerIndex]}');
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
    sdlxBindGpuIndexBuffer(
      context.renderPass,
      SdlxGpuBufferBinding()
        ..buffer = indexBuffer
        ..offset = 0,
      SdlkGpuIndexelementsize.on16Bit,
    );
    sdlxBindGpuFragmentSamplers(
      context.renderPass,
      bindings: [
        SdlxGpuTextureSamplerBinding()
          ..texture = texture
          ..sampler = samplers[currentSamplerIndex],
      ],
    );
    sdlDrawGpuIndexedPrimitives(context.renderPass, 6, 1, 0, 0, 0);
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
  void quit(Context context) {
    if (texture != nullptr) {
      sdlReleaseGpuTexture(context.device, texture);
    }
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
    for (final sampler in samplers) {
      sdlReleaseGpuSampler(context.device, sampler);
    }
    samplers.clear();
  }
}

void main() {
  App.run([TexturedQuad()]);
}
