// https://github.com/TheSpydog/SDL_gpu_examples/blob/main/Examples/TexturedAnimatedQuad.c
import 'dart:ffi';
import 'dart:math' as math;

import 'package:ffi/ffi.dart';
import 'package:sdl3/sdl3.dart';
import 'package:sdl3_gpu_examples/sdl3_gpu_examples.dart';
import 'package:vector_math/vector_math.dart';

const gVertexSource = '''
cbuffer UniformBlock : register(b0, space1)
{
    float4x4 MatrixTransform : packoffset(c0);
};

struct Input
{
    float4 Position : TEXCOORD0;
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
    output.Position = mul(MatrixTransform, input.Position);
    return output;
}
''';

const gFragmentSource = '''
cbuffer UniformBlock : register(b0, space3)
{
    float4 MultiplyColor : packoffset(c0);
};

Texture2D<float4> Texture : register(t0, space2);
SamplerState Sampler : register(s0, space2);

float4 main(float2 TexCoord : TEXCOORD0) : SV_Target0
{
    return MultiplyColor * Texture.Sample(Sampler, TexCoord);
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

class TexturedAnimatedQuad extends Common {
  @override
  String get exampleName => 'TexturedAnimatedQuad';
  Pointer<SdlGpuGraphicsPipeline> pipeline = nullptr;
  Pointer<SdlGpuBuffer> vertexBuffer = nullptr;
  Pointer<SdlGpuBuffer> indexBuffer = nullptr;
  //List<Pointer<SdlGpuSampler>> samplers = [];
  Pointer<SdlGpuSampler> sampler = nullptr;
  Pointer<SdlGpuTexture> texture = nullptr;
  late double t;

  @override
  bool init(Context context) {
    t = 0;
    final vertexShader = loadShaderFromSource(
      context.device,
      gVertexSource,
      format: format,
      stage: SdlkGpuShaderstage.vertex,
      numUniformBuffers: 1,
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
      numUniformBuffers: 1,
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
    final pipelineCreateInfo = SdlxGpuGraphicsPipelineCreateInfo(
      targetInfo: SdlxGpuGraphicsPipelineTargetInfo(
        colorTargetDescriptions: [
          // color target
          SdlxGpuColorTargetDescription(
            format: sdlGetGpuSwapchainTextureFormat(
              context.device,
              context.window,
            ),
            blendState: const SdlxGpuColorTargetBlendState(
              enableBlend: true,
              alphaBlendOp: SdlkGpuBlendop.add,
              colorBlendOp: SdlkGpuBlendop.add,
              srcColorBlendfactor: SdlkGpuBlendfactor.srcAlpha,
              srcAlphaBlendfactor: SdlkGpuBlendfactor.srcAlpha,
              dstColorBlendfactor: SdlkGpuBlendfactor.oneMinusSrcAlpha,
              dstAlphaBlendfactor: SdlkGpuBlendfactor.oneMinusSrcAlpha,
            ),
          ),
        ],
      ),
      vertexInputState: SdlxGpuVertexInputState(
        vertexBufferDescriptions: [
          // vertex buffer
          SdlxGpuVertexBufferDescription(
            //slot: 0,
            //inputRate: SdlkGpuVertexinputrate.vertex,
            //instanceStepRate: 0,
            pitch: sizeOf<PositionTextureVertex>(),
          ),
        ],
        vertexAttributes: [
          // vertex attribute[0]
          const SdlxGpuVertexAttribute(
            //bufferSlot: 0,
            format: SdlkGpuVertexelementformat.float3,
            //location: 0,
            //offset: 0,
          ),
          // vertex attribute[1]
          SdlxGpuVertexAttribute(
            //bufferSlot: 0,
            format: SdlkGpuVertexelementformat.float2,
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
    if (pipeline == nullptr) {
      sdlLog('Failed to create pipeline!');
      return false;
    }
    sdlReleaseGpuShader(context.device, vertexShader);
    sdlReleaseGpuShader(context.device, fragmentShader);
    // Create the GPU resources
    vertexBuffer = sdlxCreateGpuBuffer(
      context.device,
      SdlxGpuBufferCreateInfo(
        usage: SdlkGpuBufferusage.vertex,
        size: sizeOf<PositionTextureVertex>() * 4,
      ),
    );
    indexBuffer = sdlxCreateGpuBuffer(
      context.device,
      SdlxGpuBufferCreateInfo(
        usage: SdlkGpuBufferusage.index,
        size: sizeOf<Uint16>() * 6,
      ),
    );
    texture = sdlxCreateGpuTexture(
      context.device,
      SdlxGpuTextureCreateInfo(
        //type: SdlkGpuTexturetype.on2D,
        format: SdlkGpuTextureformat.r8G8B8A8Unorm,
        width: imageData.ref.w,
        height: imageData.ref.h,
        layerCountOrDepth: 1,
        numLevels: 1,
        usage: SdlkGpuTextureusage.sampler,
      ),
    );
    sampler = sdlxCreateGpuSampler(
      context.device,
      const SdlxGpuSamplerCreateInfo(
        //minFilter: SdlkGpuFilter.nearest,
        //magFilter: SdlkGpuFilter.nearest,
        //mipmapMode: SdlkGpuSamplermipmapmode.nearest,
        addressModeU: SdlkGpuSampleraddressmode.clampToEdge,
        addressModeV: SdlkGpuSampleraddressmode.clampToEdge,
        addressModeW: SdlkGpuSampleraddressmode.clampToEdge,
      ),
    );
    // Set up buffer data
    final bufferTransferBuffer = sdlxCreateGpuTransferBuffer(
      context.device,
      SdlxGpuTransferBufferCreateInfo(
        //usage: SdlkGpuTransferbufferusage.upload,
        size: sizeOf<PositionTextureVertex>() * 4 + sizeOf<Uint16>() * 6,
      ),
    );
    final transferData = sdlMapGpuTransferBuffer(
      context.device,
      bufferTransferBuffer,
      false,
    ).cast<PositionTextureVertex>();
    transferData[0].setFromList([-0.5, -0.5, 0, 0, 0]);
    transferData[1].setFromList([0.5, -0.5, 0, 1, 0]);
    transferData[2].setFromList([0.5, 0.5, 0, 1, 1]);
    transferData[3].setFromList([-0.5, 0.5, 0, 0, 1]);
    final indexData = (transferData + 4).cast<Uint16>();
    indexData[0] = 0;
    indexData[1] = 1;
    indexData[2] = 2;
    indexData[3] = 0;
    indexData[4] = 2;
    indexData[5] = 3;
    sdlUnmapGpuTransferBuffer(context.device, bufferTransferBuffer);
    // Set up texture data
    final textureTransferBuffer = sdlxCreateGpuTransferBuffer(
      context.device,
      SdlxGpuTransferBufferCreateInfo(
        //usage: SdlkGpuTransferbufferusage.upload,
        size: imageData.ref.w * imageData.ref.h * 4,
      ),
    );
    final textureTranferPointer = sdlMapGpuTransferBuffer(
      context.device,
      textureTransferBuffer,
      false,
    ).cast<Uint8>();
    sdlMemcpy(
      textureTranferPointer.cast<Void>(),
      imageData.ref.pixels,
      imageData.ref.w * imageData.ref.h * 4,
    );
    sdlUnmapGpuTransferBuffer(context.device, textureTransferBuffer);
    // Upload the transfer data to the GPU resources
    final uploadCommandBuffer = sdlAcquireGpuCommandBuffer(context.device);
    final copyPass = sdlBeginGpuCopyPass(uploadCommandBuffer);
    sdlxUploadToGpuBuffer(
      copyPass,
      SdlxGpuTransferBufferLocation(
        transferBuffer: bufferTransferBuffer,
        //offset: 0,
      ),
      SdlxGpuBufferRegion(
        buffer: vertexBuffer,
        //offset: 0,
        size: sizeOf<PositionTextureVertex>() * 4,
      ),
    );
    sdlxUploadToGpuBuffer(
      copyPass,
      SdlxGpuTransferBufferLocation(
        transferBuffer: bufferTransferBuffer,
        offset: sizeOf<PositionTextureVertex>() * 4,
      ),
      SdlxGpuBufferRegion(
        buffer: indexBuffer,
        //offset: 0,
        size: sizeOf<Uint16>() * 6,
      ),
    );
    sdlxUploadToGpuTexture(
      copyPass,
      SdlxGpuTextureTransferInfo(
        transferBuffer: textureTransferBuffer,
        //offset: 0,
      ),
      SdlxGpuTextureRegion(
        texture: texture,
        w: imageData.ref.w,
        h: imageData.ref.h,
        d: 1,
      ),
    );
    imageData.destroy();
    sdlEndGpuCopyPass(copyPass);
    sdlSubmitGpuCommandBuffer(uploadCommandBuffer);
    sdlReleaseGpuTransferBuffer(context.device, bufferTransferBuffer);
    sdlReleaseGpuTransferBuffer(context.device, textureTransferBuffer);
    return true;
  }

  @override
  bool update(Context context) {
    t += context.deltaTime;
    return true;
  }

  void _drawInstance(
    Context context, {
    required Vector3 translation,
    required double rotationZ,
    required SdlxFColor color,
  }) {
    {
      final Matrix4 matrix =
          Matrix4.translation(translation) * Matrix4.rotationZ(rotationZ);
      final matrixPointer = calloc<Float>(16);
      matrixPointer.asTypedList(16).setAll(0, matrix.storage);
      sdlPushGpuVertexUniformData(
        context.commandBuffer,
        0,
        matrixPointer.cast<Void>(),
        sizeOf<Float>() * 16,
      );
      matrixPointer.callocFree();
    }
    {
      final colorPointer = color.toNative();
      sdlPushGpuFragmentUniformData(
        context.commandBuffer,
        0,
        colorPointer.cast<Void>(),
        sizeOf<SdlFColor>(),
      );
      colorPointer.callocFree();
    }
    sdlDrawGpuIndexedPrimitives(context.renderPass, 6, 1, 0, 0, 0);
  }

  @override
  bool draw(Context context) {
    sdlBindGpuGraphicsPipeline(context.renderPass, pipeline);
    sdlxBindGpuVertexBuffers(context.renderPass, [
      SdlxGpuBufferBinding(
        buffer: vertexBuffer,
        //offset: 0,
      ),
    ]);
    sdlxBindGpuIndexBuffer(
      context.renderPass,
      SdlxGpuBufferBinding(
        buffer: indexBuffer,
        //offset: 0,
      ),
      SdlkGpuIndexelementsize.on16Bit,
    );
    sdlxBindGpuFragmentSamplers(context.renderPass, [
      SdlxGpuTextureSamplerBinding(texture: texture, sampler: sampler),
    ]);
    // Top-left
    _drawInstance(
      context,
      translation: Vector3(-0.5, -0.5, 0),
      rotationZ: t,
      color: SdlxFColor(1, 0.5 + math.sin(t) * 0.5, 1),
    );
    // Top-right
    _drawInstance(
      context,
      translation: Vector3(0.5, -0.5, 0),
      rotationZ: (2.0 * math.pi) - t,
      color: SdlxFColor(1, 0.5 + math.cos(t) * 0.5, 1),
    );

    // Bottom-left
    _drawInstance(
      context,
      translation: Vector3(-0.5, 0.5, 0),
      rotationZ: t,
      color: SdlxFColor(1, 0.5 + math.sin(t) * 0.2, 1),
    );

    // Bottom-right
    _drawInstance(
      context,
      translation: Vector3(0.5, 0.5, 0),
      rotationZ: t,
      color: SdlxFColor(1, 0.5 + math.cos(t) * 1.0, 1),
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
    if (texture != nullptr) {
      sdlReleaseGpuTexture(context.device, texture);
    }
    if (sampler != nullptr) {
      sdlReleaseGpuSampler(context.device, sampler);
      sampler = nullptr;
    }
  }
}

void main() {
  App.run([TexturedAnimatedQuad()]);
}
