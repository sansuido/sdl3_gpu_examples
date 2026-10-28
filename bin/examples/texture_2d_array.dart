// https://github.com/TheSpydog/SDL_gpu_examples/blob/main/Examples/Texture2DArray.c
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
Texture2DArray<float4> Texture : register(t0, space2);
SamplerState Sampler : register(s0, space2);

float4 main(float2 TexCoord : TEXCOORD0) : SV_Target0
{
    float layer = TexCoord.y < 0.5f ? 0.0f : 1.0f;
    return Texture.Sample(Sampler, float3(TexCoord, layer));
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

class Texture2DArray extends Common {
  @override
  String get exampleName => 'Texture2DArray';

  @override
  bool get useRenderPass => false;

  Pointer<SdlGpuGraphicsPipeline> pipeline = nullptr;
  Pointer<SdlGpuBuffer> vertexBuffer = nullptr;
  Pointer<SdlGpuBuffer> indexBuffer = nullptr;
  Pointer<SdlGpuTexture> texture = nullptr;
  Pointer<SdlGpuSampler> sampler = nullptr;

  @override
  bool init(Context context) {
    // 1. Shaders
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

    // 2. Pipeline
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

    // 3. Images (Surfaces)
    final rawImageData1 = imgLoad('assets/Images/ravioli.bmp');
    if (rawImageData1 == nullptr) {
      sdlLog('Could not load first image data!');
      return false;
    }
    final imageData1 = sdlConvertSurface(
      rawImageData1,
      SdlkPixelformat.abgr8888,
    );
    rawImageData1.destroy();
    if (imageData1 == nullptr) {
      sdlLog('Failed to convert first surface!');
      return false;
    }

    final rawImageData2 = imgLoad('assets/Images/ravioli_inverted.bmp');
    if (rawImageData2 == nullptr) {
      sdlLog('Could not load second image data!');
      return false;
    }
    final imageData2 = sdlConvertSurface(
      rawImageData2,
      SdlkPixelformat.abgr8888,
    );
    rawImageData2.destroy();
    if (imageData2 == nullptr) {
      sdlLog('Failed to convert second surface!');
      return false;
    }

    if (imageData1.ref.w != imageData2.ref.w ||
        imageData1.ref.h != imageData2.ref.h) {
      sdlLog('Image dimensions do not match!');
      return false;
    }

    // 4. GPU Resources (Texture 2D Array)
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
        type: SdlkGpuTexturetype.on2DArray,
        format: SdlkGpuTextureformat.r8G8B8A8Unorm,
        width: imageData1.ref.w,
        height: imageData1.ref.h,
        layerCountOrDepth: 2,
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

    // 5. Transfer Buffers & Data Setup
    final bufferTransferBuffer = sdlxCreateGpuTransferBuffer(
      context.device,
      SdlxGpuTransferBufferCreateInfo(
        //usage: SdlkGpuTransferbufferusage.upload,
        size: (sizeOf<PositionTextureVertex>() * 4) + (sizeOf<Uint16>() * 6),
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

    final imageSizeInBytes = imageData1.ref.w * imageData1.ref.h * 4;
    final textureTransferBuffer = sdlxCreateGpuTransferBuffer(
      context.device,
      SdlxGpuTransferBufferCreateInfo(
        //usage: SdlkGpuTransferbufferusage.upload,
        size: imageSizeInBytes * 2,
      ),
    );
    final textureTransferPtr = sdlMapGpuTransferBuffer(
      context.device,
      textureTransferBuffer,
      false,
    ).cast<Uint8>();

    sdlMemcpy(
      textureTransferPtr.cast<Void>(),
      imageData1.ref.pixels,
      imageSizeInBytes,
    );
    sdlMemcpy(
      (textureTransferPtr + imageSizeInBytes).cast<Void>(),
      imageData2.ref.pixels,
      imageSizeInBytes,
    );
    sdlUnmapGpuTransferBuffer(context.device, textureTransferBuffer);

    // 6. Upload Data via Copy Pass
    final uploadCmdBuf = sdlAcquireGpuCommandBuffer(context.device);
    final copyPass = sdlBeginGpuCopyPass(uploadCmdBuf);

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
        w: imageData1.ref.w,
        h: imageData1.ref.h,
        d: 1,
      ),
    );

    sdlxUploadToGpuTexture(
      copyPass,
      SdlxGpuTextureTransferInfo(
        transferBuffer: textureTransferBuffer,
        offset: imageSizeInBytes,
      ),
      SdlxGpuTextureRegion(
        texture: texture,
        layer: 1,
        w: imageData1.ref.w,
        h: imageData1.ref.h,
        d: 1,
      ),
    );

    sdlDestroySurface(imageData1);
    sdlDestroySurface(imageData2);
    sdlEndGpuCopyPass(copyPass);
    sdlSubmitGpuCommandBuffer(uploadCmdBuf);

    sdlReleaseGpuTransferBuffer(context.device, bufferTransferBuffer);
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

    final renderPass = sdlxBeginGpuRenderPass(cmdbuf, [
      SdlxGpuColorTargetInfo(
        texture: swapchainTexture,
        loadOp: SdlkGpuLoadop.clear,
        //storeOp: SdlkGpuStoreop.store,
        //clearColor: const SdlxFColor(0, 0, 0, 1),
      ),
    ]);

    sdlBindGpuGraphicsPipeline(renderPass, pipeline);
    sdlxBindGpuVertexBuffers(renderPass, [
      SdlxGpuBufferBinding(
        buffer: vertexBuffer,
        //offset: 0
      ),
    ]);
    sdlxBindGpuIndexBuffer(
      renderPass,
      SdlxGpuBufferBinding(
        buffer: indexBuffer,
        //offset: 0
      ),
      SdlkGpuIndexelementsize.on16Bit,
    );
    sdlxBindGpuFragmentSamplers(renderPass, [
      SdlxGpuTextureSamplerBinding(texture: texture, sampler: sampler),
    ]);
    sdlDrawGpuIndexedPrimitives(renderPass, 6, 1, 0, 0, 0);

    sdlEndGpuRenderPass(renderPass);
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
      sdlReleaseGpuBuffer(context.device, vertexBuffer);
      indexBuffer = nullptr;
    }
    if (indexBuffer != nullptr) {
      sdlReleaseGpuBuffer(context.device, indexBuffer);
      indexBuffer = nullptr;
    }
    if (texture != nullptr) {
      sdlReleaseGpuTexture(context.device, texture);
      texture = nullptr;
    }
    if (sampler != nullptr) {
      sdlReleaseGpuSampler(context.device, sampler);
      sampler = nullptr;
    }
  }
}

void main() {
  App.run([Texture2DArray()]);
}
