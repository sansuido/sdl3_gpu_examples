// https://github.com/TheSpydog/SDL_gpu_examples/blob/main/Examples/CustomSampling.c
import 'dart:ffi';

import 'package:ffi/ffi.dart';
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
cbuffer UBO : register(b0, space3)
{
    int mode : packoffset(c0);
};

Texture2D<float4> Texture : register(t0, space2);

float4 main(float2 TexCoord : TEXCOORD0) : SV_Target0
{
    float w, h;
    Texture.GetDimensions(w, h);
    int2 texelPos = int2(float2(w, h) * TexCoord);
    float4 mainTexel = Texture[texelPos];
    if (mode == 0)
    {
        return mainTexel;
    }
    else
    {
        float4 bottomTexel = Texture[texelPos + int2(0, 1)];
        float4 leftTexel = Texture[texelPos + int2(-1, 0)];
        float4 topTexel = Texture[texelPos + int2(0, -1)];
        float4 rightTexel = Texture[texelPos + int2(1, 0)];
        return ((((mainTexel * 0.2f) + (bottomTexel * 0.2f)) + (leftTexel * 0.20000000298023223876953125f)) + (topTexel * 0.20000000298023223876953125f)) + (rightTexel * 0.2f);
    }
}
''';

final class SamplerMode extends Struct {
  @Int32()
  external int mode;
}

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

class CustomSampling extends Common {
  @override
  String get exampleName => 'CustomSampling';
  Pointer<SdlGpuGraphicsPipeline> pipeline = nullptr;
  Pointer<SdlGpuBuffer> vertexBuffer = nullptr;
  Pointer<SdlGpuBuffer> indexBuffer = nullptr;
  Pointer<SdlGpuTexture> texture = nullptr;
  Pointer<SamplerMode> samplerMode = nullptr;

  @override
  bool init(Context context) {
    samplerMode = calloc<SamplerMode>();
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
      numUniformBuffers: 1,
      numStorageTextures: 1,
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
            //bufferSlot:  0,
            format: SdlkGpuVertexelementformat.float3,
            //location:  0,
            //offset:  0,
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
        usage: SdlkGpuTextureusage.graphicsStorageRead,
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
    transferData[0].setFromList([-1, 1, 0, 0, 0]);
    transferData[1].setFromList([1, 1, 0, 1, 0]);
    transferData[2].setFromList([1, -1, 0, 1, 1]);
    transferData[3].setFromList([-1, -1, 0, 0, 1]);
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
    );
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
    sdlLog('Press Left/Right to switch sampler modes');
    sdlLog('Setting sampler mode to: ${samplerMode.ref.mode}');
    return true;
  }

  @override
  bool update(Context context) {
    if (context.leftPressed || context.rightPressed) {
      samplerMode.ref.mode = (samplerMode.ref.mode + 1) % 2;
      sdlLog('Setting sampler mode to: ${samplerMode.ref.mode}');
    }
    return true;
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
    sdlxBindGpuFragmentStorageTextures(context.renderPass, [texture]);
    sdlPushGpuFragmentUniformData(
      context.commandBuffer,
      0,
      samplerMode.cast<Void>(),
      sizeOf<SamplerMode>(),
    );
    sdlDrawGpuIndexedPrimitives(context.renderPass, 6, 1, 0, 0, 0);
    return true;
  }

  @override
  void quit(Context context) {
    if (samplerMode != nullptr) {
      samplerMode.callocFree();
      samplerMode = nullptr;
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
    if (texture != nullptr) {
      sdlReleaseGpuTexture(context.device, texture);
    }
  }
}

void main() {
  App.run([CustomSampling()]);
}
