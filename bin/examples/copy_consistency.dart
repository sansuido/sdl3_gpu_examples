// https://github.com/TheSpydog/SDL_gpu_examples/blob/main/Examples/CopyConsistency.c
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

//const gComputeSource = '''
//[[vk::image_format("rgba8")]]
//RWTexture2D<float4> outImage : register(u0, space1);
//
//[numthreads(8, 8, 1)]
//void main(uint3 GlobalInvocationID : SV_DispatchThreadID)
//{
//    int2 coord = int2(GlobalInvocationID.xy);
//    outImage[coord] = float4(1.0f, 1.0f, 0.0f, 1.0f);
//}
//''';

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

class CopyConsistency extends Common {
  @override
  String get exampleName => 'CopyConsistency';

  @override
  bool get useRenderPass => false;

  Pointer<SdlGpuGraphicsPipeline> pipeline = nullptr;
  Pointer<SdlGpuBuffer> vertexBuffer = nullptr;
  Pointer<SdlGpuBuffer> leftVertexBuffer = nullptr;
  Pointer<SdlGpuBuffer> rightVertexBuffer = nullptr;
  Pointer<SdlGpuBuffer> indexBuffer = nullptr;
  Pointer<SdlGpuSampler> sampler = nullptr;
  Pointer<SdlGpuTexture> texture = nullptr;
  Pointer<SdlGpuTexture> leftTexture = nullptr;
  Pointer<SdlGpuTexture> rightTexture = nullptr;

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

    // Create the pipeline
    final pipelineCreateInfo = SdlxGpuGraphicsPipelineCreateInfo(
      targetInfo: SdlxGpuGraphicsPipelineTargetInfo(
        colorTargetDescriptions: [
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
          SdlxGpuVertexBufferDescription(
            //slot: 0,
            //inputRate: SdlkGpuVertexinputrate.vertex,
            //instanceStepRate: 0,
            pitch: sizeOf<PositionTextureVertex>(),
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

    // Create the textures
    const textureCreateInfo = SdlxGpuTextureCreateInfo(
      format: SdlkGpuTextureformat.r8G8B8A8Unorm,
      width: 16,
      height: 16,
      layerCountOrDepth: 1,
      numLevels: 1,
      usage: SdlkGpuTextureusage.sampler,
    );
    leftTexture = sdlxCreateGpuTexture(context.device, textureCreateInfo);
    rightTexture = sdlxCreateGpuTexture(context.device, textureCreateInfo);
    texture = sdlxCreateGpuTexture(context.device, textureCreateInfo);

    // Load the texture data
    final rawLeftImageData = imgLoad('assets/Images/ravioli.bmp');
    if (rawLeftImageData == nullptr) {
      sdlLog('Could not load image data!');
      return false;
    }
    final leftImageData = sdlConvertSurface(
      rawLeftImageData,
      SdlkPixelformat.abgr8888,
    );
    rawLeftImageData.destroy();
    if (leftImageData == nullptr) {
      sdlLog('Failed to convert surface!');
      return false;
    }

    final rawRightImageData = imgLoad('assets/Images/ravioli_inverted.bmp');
    if (rawRightImageData == nullptr) {
      sdlLog('Could not load image data!');
      return false;
    }
    final rightImageData = sdlConvertSurface(
      rawRightImageData,
      SdlkPixelformat.abgr8888,
    );
    rawRightImageData.destroy();
    if (rightImageData == nullptr) {
      sdlLog('Failed to convert surface!');
      return false;
    }

    // Create the sampler
    sampler = sdlxCreateGpuSampler(
      context.device,
      const SdlxGpuSamplerCreateInfo(
        addressModeU: SdlkGpuSampleraddressmode.clampToEdge,
        addressModeV: SdlkGpuSampleraddressmode.clampToEdge,
        addressModeW: SdlkGpuSampleraddressmode.clampToEdge,
      ),
    );

    // Create the buffers
    vertexBuffer = sdlxCreateGpuBuffer(
      context.device,
      SdlxGpuBufferCreateInfo(
        usage: SdlkGpuBufferusage.vertex,
        size: sizeOf<PositionTextureVertex>() * 4,
      ),
    );
    leftVertexBuffer = sdlxCreateGpuBuffer(
      context.device,
      SdlxGpuBufferCreateInfo(
        usage: SdlkGpuBufferusage.vertex,
        size: sizeOf<PositionTextureVertex>() * 4,
      ),
    );
    rightVertexBuffer = sdlxCreateGpuBuffer(
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

    final transferBuffer = sdlxCreateGpuTransferBuffer(
      context.device,
      SdlxGpuTransferBufferCreateInfo(
        //usage: SdlkGpuTransferbufferusage.upload,
        size: (sizeOf<PositionTextureVertex>() * 8) + (sizeOf<Uint16>() * 6),
      ),
    );
    final transferData = sdlMapGpuTransferBuffer(
      context.device,
      transferBuffer,
      false,
    ).cast<PositionTextureVertex>();

    // Left vertex data
    transferData[0].setFromList([-1, 1, 0, 0, 0]);
    transferData[1].setFromList([0, 1, 0, 1, 0]);
    transferData[2].setFromList([0, -1, 0, 1, 1]);
    transferData[3].setFromList([-1, -1, 0, 0, 1]);

    // Right vertex data (修正済み)
    transferData[4].setFromList([0, 1, 0, 0, 0]);
    transferData[5].setFromList([1, 1, 0, 1, 0]);
    transferData[6].setFromList([1, -1, 0, 1, 1]);
    transferData[7].setFromList([0, -1, 0, 0, 1]);

    // Index data
    final indexData = (transferData + 8).cast<Uint16>();
    indexData[0] = 0;
    indexData[1] = 1;
    indexData[2] = 2;
    indexData[3] = 0;
    indexData[4] = 2;
    indexData[5] = 3;

    sdlUnmapGpuTransferBuffer(context.device, transferBuffer);

    // Set up texture data
    final textureTransferBuffer = sdlxCreateGpuTransferBuffer(
      context.device,
      SdlxGpuTransferBufferCreateInfo(
        size: leftImageData.ref.w * leftImageData.ref.h * 8,
      ),
    );
    final textureTranferPointer = sdlMapGpuTransferBuffer(
      context.device,
      textureTransferBuffer,
      false,
    ).cast<Uint8>();

    final leftImageSize = leftImageData.ref.w * leftImageData.ref.h * 4;
    sdlMemcpy(
      textureTranferPointer.cast<Void>(),
      leftImageData.ref.pixels,
      leftImageSize,
    );
    sdlMemcpy(
      (textureTranferPointer.cast<Uint8>() + leftImageSize).cast<Void>(),
      rightImageData.ref.pixels,
      rightImageData.ref.w * rightImageData.ref.h * 4,
    );
    sdlUnmapGpuTransferBuffer(context.device, textureTransferBuffer);

    // Upload the transfer data to the GPU resources
    final uploadCommandBuffer = sdlAcquireGpuCommandBuffer(context.device);
    final copyPass = sdlBeginGpuCopyPass(uploadCommandBuffer);

    sdlxUploadToGpuBuffer(
      copyPass,
      SdlxGpuTransferBufferLocation(
        transferBuffer: transferBuffer,
        //offset: 0,
      ),
      SdlxGpuBufferRegion(
        buffer: leftVertexBuffer,
        //offset: 0,
        size: sizeOf<PositionTextureVertex>() * 4,
      ),
    );
    sdlxUploadToGpuBuffer(
      copyPass,
      SdlxGpuTransferBufferLocation(
        transferBuffer: transferBuffer,
        offset: sizeOf<PositionTextureVertex>() * 4,
      ),
      SdlxGpuBufferRegion(
        buffer: rightVertexBuffer,
        //offset: 0,
        size: sizeOf<PositionTextureVertex>() * 4,
      ),
    );
    sdlxUploadToGpuBuffer(
      copyPass,
      SdlxGpuTransferBufferLocation(
        transferBuffer: transferBuffer,
        offset: sizeOf<PositionTextureVertex>() * 8,
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
        texture: leftTexture,
        w: leftImageData.ref.w,
        h: leftImageData.ref.h,
        d: 1,
      ),
    );
    sdlxUploadToGpuTexture(
      copyPass,
      SdlxGpuTextureTransferInfo(
        transferBuffer: textureTransferBuffer,
        offset: leftImageData.ref.w * leftImageData.ref.h * 4,
      ),
      SdlxGpuTextureRegion(
        texture: rightTexture,
        w: rightImageData.ref.w,
        h: rightImageData.ref.h,
        d: 1,
      ),
    );

    sdlDestroySurface(leftImageData);
    sdlDestroySurface(rightImageData);
    sdlEndGpuCopyPass(copyPass);
    sdlSubmitGpuCommandBuffer(uploadCommandBuffer);
    sdlReleaseGpuTransferBuffer(context.device, transferBuffer);
    sdlReleaseGpuTransferBuffer(context.device, textureTransferBuffer);
    return true;
  }

  @override
  bool draw(Context context) {
    final cmdbuf = context.commandBuffer;
    final swapchainTexture = context.swapchainTexture;
    if (swapchainTexture == nullptr) {
      return false;
    }

    final copyPass1 = sdlBeginGpuCopyPass(cmdbuf);
    sdlxCopyGpuBufferToBuffer(
      copyPass1,
      SdlxGpuBufferLocation(buffer: leftVertexBuffer),
      SdlxGpuBufferLocation(buffer: vertexBuffer),
      sizeOf<PositionTextureVertex>() * 4,
    );
    sdlxCopyGpuTextureToTexture(
      copyPass1,
      SdlxGpuTextureLocation(texture: leftTexture),
      SdlxGpuTextureLocation(texture: texture),
      16,
      16,
      1,
    );
    sdlEndGpuCopyPass(copyPass1);

    final renderPass1 = sdlxBeginGpuRenderPass(cmdbuf, [
      SdlxGpuColorTargetInfo(
        texture: swapchainTexture,
        loadOp: SdlkGpuLoadop.clear,
        //storeOp: SdlkGpuStoreop.store,
        //clearColor: const SdlxFColor(0, 0, 0, 1),
      ),
    ]);
    sdlBindGpuGraphicsPipeline(renderPass1, pipeline);
    sdlxBindGpuVertexBuffers(renderPass1, [
      SdlxGpuBufferBinding(buffer: vertexBuffer),
    ]);
    sdlxBindGpuIndexBuffer(
      renderPass1,
      SdlxGpuBufferBinding(buffer: indexBuffer),
      SdlkGpuIndexelementsize.on16Bit,
    );
    sdlxBindGpuFragmentSamplers(renderPass1, [
      SdlxGpuTextureSamplerBinding(texture: texture, sampler: sampler),
    ]);
    sdlDrawGpuIndexedPrimitives(renderPass1, 6, 1, 0, 0, 0);
    sdlEndGpuRenderPass(renderPass1);

    final copyPass2 = sdlBeginGpuCopyPass(cmdbuf);
    sdlxCopyGpuBufferToBuffer(
      copyPass2,
      SdlxGpuBufferLocation(buffer: rightVertexBuffer),
      SdlxGpuBufferLocation(buffer: vertexBuffer),
      sizeOf<PositionTextureVertex>() * 4,
    );
    sdlxCopyGpuTextureToTexture(
      copyPass2,
      SdlxGpuTextureLocation(texture: rightTexture),
      SdlxGpuTextureLocation(texture: texture),
      16,
      16,
      1,
    );
    sdlEndGpuCopyPass(copyPass2);

    final renderPass2 = sdlxBeginGpuRenderPass(cmdbuf, [
      SdlxGpuColorTargetInfo(
        texture: swapchainTexture,
        //loadOp: SdlkGpuLoadop.load,
        //storeOp: SdlkGpuStoreop.store,
      ),
    ]);
    sdlBindGpuGraphicsPipeline(renderPass2, pipeline);
    sdlxBindGpuVertexBuffers(renderPass2, [
      SdlxGpuBufferBinding(buffer: vertexBuffer),
    ]);
    sdlxBindGpuIndexBuffer(
      renderPass2,
      SdlxGpuBufferBinding(buffer: indexBuffer),
      SdlkGpuIndexelementsize.on16Bit,
    );
    sdlxBindGpuFragmentSamplers(renderPass2, [
      SdlxGpuTextureSamplerBinding(texture: texture, sampler: sampler),
    ]);
    sdlDrawGpuIndexedPrimitives(renderPass2, 6, 1, 0, 0, 0);
    sdlEndGpuRenderPass(renderPass2);

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
    if (leftVertexBuffer != nullptr) {
      sdlReleaseGpuBuffer(context.device, leftVertexBuffer);
      leftVertexBuffer = nullptr;
    }
    if (rightVertexBuffer != nullptr) {
      sdlReleaseGpuBuffer(context.device, rightVertexBuffer);
      rightVertexBuffer = nullptr;
    }
    if (indexBuffer != nullptr) {
      sdlReleaseGpuBuffer(context.device, indexBuffer);
      indexBuffer = nullptr;
    }
    if (texture != nullptr) {
      sdlReleaseGpuTexture(context.device, texture);
      texture = nullptr;
    }
    if (leftTexture != nullptr) {
      sdlReleaseGpuTexture(context.device, leftTexture);
      leftTexture = nullptr;
    }
    if (rightTexture != nullptr) {
      sdlReleaseGpuTexture(context.device, rightTexture);
      rightTexture = nullptr;
    }
    if (sampler != nullptr) {
      sdlReleaseGpuSampler(context.device, sampler);
      sampler = nullptr;
    }
  }
}

void main() {
  App.run([CopyConsistency()]);
}
