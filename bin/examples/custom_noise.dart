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
    float time : packoffset(c0.y);
};

Texture2D<float4> Texture : register(t0, space2);

float2 curve(float2 uv)
{
    uv = (uv - 0.5f) * 2.0f;
    uv.x *= 1.0f + pow((abs(uv.y) / 4.0f), 2.0f);
    uv.y *= 1.0f + pow((abs(uv.x) / 3.0f), 2.0f);
    uv = (uv / 2.0f) + 0.5f;
    return uv;
}

float rand(float2 co) {
    return frac(sin(dot(co, float2(12.9898f, 78.233f))) * 43758.5453f);
}

float4 main(float2 TexCoord : TEXCOORD0) : SV_Target0
{
    if (mode == 0)
    {
        float w, h;
        Texture.GetDimensions(w, h);
        int2 texelPos = int2(float2(w, h) * TexCoord);
        return Texture[texelPos];
    }
    else
    {
        float2 crtUV = curve(TexCoord);

        if (crtUV.x < 0.0f || crtUV.x > 1.0f || crtUV.y < 0.0f || crtUV.y > 1.0f) {
            return float4(0.0f, 0.0f, 0.0f, 1.0f);
        }

        float jitter = sin(time * 20.0f) * sin(time * 100.0f);
        if (jitter > 0.85f) {
            crtUV.x += rand(float2(time, crtUV.y)) * 0.06f - 0.03f;
        }

        float w, h;
        Texture.GetDimensions(w, h);
        int2 texelPos = int2(float2(w, h) * crtUV);
        float4 baseColor = Texture[texelPos];

        float noise1 = rand(crtUV + time);
        float noise2 = rand(crtUV * 1.5f - time * 2.0f);
        float finalNoise = lerp(noise1, noise2, 0.3f);
        finalNoise = saturate((finalNoise - 0.2f) * 1.4f);

        float4 color = baseColor;
        color.rgb = lerp(color.rgb, float3(finalNoise, finalNoise, finalNoise), 0.4f);
        
        color.rgb += (finalNoise - 0.5f) * 0.2f;

        float wave = sin(crtUV.y * 3.0f - time * 3.0f) * 0.12f;
        color.rgb -= wave;

        float scanline = sin(crtUV.y * 500.0f) * 0.06f;
        color.rgb -= scanline;

        float vignette = crtUV.x * crtUV.y * (1.0f - crtUV.x) * (1.0f - crtUV.y);
        vignette = clamp(pow(16.0f * vignette, 0.3f), 0.0f, 1.0f);
        color.rgb *= vignette;

        return color;
    }
}
''';

final class SamplerMode extends Struct {
  @Int32()
  external int mode;
  @Float()
  external double time;
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

class CustomNoise extends Common {
  @override
  String get exampleName => 'CustomNoise';
  Pointer<SdlGpuGraphicsPipeline> pipeline = nullptr;
  Pointer<SdlGpuBuffer> vertexBuffer = nullptr;
  Pointer<SdlGpuBuffer> indexBuffer = nullptr;
  Pointer<SdlGpuTexture> texture = nullptr;
  Pointer<SamplerMode> samplerMode = nullptr;

  var _elapsedTime = 0.0;

  @override
  bool init(Context context) {
    samplerMode = calloc<SamplerMode>();
    samplerMode.ref.mode = 1;
    samplerMode.ref.time = 0.0;

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

    final textureTransferBuffer = sdlxCreateGpuTransferBuffer(
      context.device,
      SdlxGpuTransferBufferCreateInfo(
        //usage: SdlkGpuTransferbufferusage.upload,
        size: imageData.ref.w * imageData.ref.h * 4,
      ),
    );
    final textureTransferPointer = sdlMapGpuTransferBuffer(
      context.device,
      textureTransferBuffer,
      false,
    );
    sdlMemcpy(
      textureTransferPointer,
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

    sdlLog(
      'Press Left/Right to switch sampler modes (0: Normal, 1: CRT Glitch)',
    );
    sdlLog('Setting sampler mode to: ${samplerMode.ref.mode}');
    return true;
  }

  @override
  bool update(Context context) {
    if (context.leftPressed || context.rightPressed) {
      samplerMode.ref.mode = (samplerMode.ref.mode + 1) % 2;
      sdlLog('Setting sampler mode to: ${samplerMode.ref.mode}');
    }

    _elapsedTime += 0.016666;
    samplerMode.ref.time = _elapsedTime;
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
  App.run([CustomNoise()]);
}
