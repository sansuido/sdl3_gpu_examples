// https://github.com/TheSpydog/SDL_gpu_examples/blob/main/Examples/ToneMapping.c
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:image/image.dart' as image;
import 'package:sdl3/sdl3.dart';
import 'package:sdl3_gpu_examples/sdl3_gpu_examples.dart';

const gComputeToneMapOperaatorsSource = [
  '''
Texture2D<float4> inImage : register(t0, space0);
[[vk::image_format("rgba16f")]]
RWTexture2D<float4> outImage : register(u0, space1);

float3 reinhard(float3 v)
{
    return v / (1.0f.xxx + v);
}

[numthreads(8, 8, 1)]
void main(uint3 GlobalInvocationID : SV_DispatchThreadID)
{
    int2 coord = int2(GlobalInvocationID.xy);
    float4 inPixel = inImage[coord];
    float3 outColor = reinhard(inPixel.xyz);
    outImage[coord] = float4(outColor, 1.0f);
}
''',
  '''
Texture2D<float4> inImage : register(t0, space0);
[[vk::image_format("rgba16f")]]
RWTexture2D<float4> outImage : register(u0, space1);

float luminance(float3 v)
{
    return dot(v, float3(0.2126f, 0.7152f, 0.0722f));
}

float3 change_luminance(float3 c_in, float l_out)
{
    float l_in = luminance(c_in);
    return c_in * (l_out / l_in);
}

float3 reinhard_extended_luminance(float3 v, float max_white_l)
{
    float l_old = luminance(v);
    float numerator = l_old * (1.0f + (l_old / (max_white_l * max_white_l)));
    float l_new = numerator / (1.0f + l_old);
    return change_luminance(v, l_new);
}

[numthreads(8, 8, 1)]
void main(uint3 GlobalInvocationID : SV_DispatchThreadID)
{
    int2 coord = int2(GlobalInvocationID.xy);
    float4 inPixel = inImage[coord];
    float3 outColor = reinhard_extended_luminance(inPixel.xyz, 662.0f);
    outImage[coord] = float4(outColor, 1.0f);
}
''',
  '''
Texture2D<float4> inImage : register(t0, space0);
[[vk::image_format("rgba16f")]]
RWTexture2D<float4> outImage : register(u0, space1);

float3 hable_tonemap_partial(float3 x)
{
    float A = 0.15f;
    float B = 0.50f;
    float C = 0.10f;
    float D = 0.20f;
    float E = 0.02f;
    float F = 0.30f;
    return (((x * ((x * A) + (C * B).xxx)) + (D * E).xxx) / ((x * ((x * A) + B.xxx)) + (D * F).xxx)) - (E / F).xxx;
}

float3 hable_filmic(float3 v)
{
    float exposure_bias = 2.0f;
    float3 curr = hable_tonemap_partial(v * exposure_bias);

    float3 W = 11.2f.xxx;
    float3 white_scale = 1.0f.xxx / hable_tonemap_partial(W);
    return curr * white_scale;
}

[numthreads(8, 8, 1)]
void main(uint3 GlobalInvocationID : SV_DispatchThreadID)
{
    int2 coord = int2(GlobalInvocationID.xy);
    float4 inPixel = inImage[coord];
    float3 outColor = hable_filmic(inPixel.xyz);
    outImage[coord] = float4(outColor, 1.0f);
}
''',
  '''
Texture2D<float4> inImage : register(t0, space0);
[[vk::image_format("rgba16f")]]
RWTexture2D<float4> outImage : register(u0, space1);

float3 rtt_and_odt_fit(float3 v)
{
    float3 a = (v * (v + 0.0245786f.xxx)) - 0.000090537f.xxx;
    float3 b = (v * ((v * 0.983729f) + 0.4329510f.xxx)) + 0.238081f.xxx;
    return a / b;
}

float3 aces_fitted(float3 v)
{
    v = mul(float3x3(float3(0.59719f, 0.35458f, 0.04823f), float3(0.07600f, 0.90834f, 0.01566f), float3(0.02840f, 0.13383f, 0.83777f)), v);
    v = rtt_and_odt_fit(v);
    return mul(float3x3(float3(1.60475f, -0.53108f, -0.07367f), float3(-0.10208f, 1.10813f, -0.00605f), float3(-0.00327f, -0.07276f, 1.07602f)), v);
}

[numthreads(8, 8, 1)]
void main(uint3 GlobalInvocationID : SV_DispatchThreadID)
{
    int2 coord = int2(GlobalInvocationID.xy);
    float4 inPixel = inImage[coord];
    float3 outColor = aces_fitted(inPixel.xyz);
    outImage[coord] = float4(outColor, 1.0f);
}
''',
];

const gComputeLinearSrgoSource = '''
Texture2D<float4> InImage : register(t0, space0);
[[vk::image_format("rgba8")]]
RWTexture2D<float4> OutImage : register(u0, space1);

float3 LinearToSRGB(float3 color)
{
    return pow(abs(color), float(1.0f/2.2f).xxx);
}

[numthreads(8, 8, 1)]
void main(uint3 GlobalInvocationID : SV_DispatchThreadID)
{
    int2 coord = int2(GlobalInvocationID.xy);
    float4 inPixel = InImage[coord];
    float3 param = inPixel.xyz;
    float3 outColor = LinearToSRGB(param);
    OutImage[coord] = float4(outColor, 1.0f);
}
''';

const gComputeLinearSt2084Source = '''
Texture2D<float4> InImage : register(t0, space0);
[[vk::image_format("rgba8")]]
RWTexture2D<float4> OutImage : register(u0, space1);

float3 NormalizeHDRSceneValue(float3 hdrSceneValue, float paperWhiteNits)
{
    return (hdrSceneValue * paperWhiteNits) / 10000.0f.xxx;
}

float3 LinearToST2084(float3 normalizedLinearValue)
{
    return pow((0.8359375f.xxx + (pow(abs(normalizedLinearValue), 0.1593017578125f.xxx) * 18.8515625f)) / (1.0f.xxx + (pow(abs(normalizedLinearValue), 0.1593017578125f.xxx) * 18.6875f)), 78.84375f.xxx);
}

float4 ConvertToHDR10(float4 hdrSceneValue, float paperWhiteNits)
{
    float3 rec2020 = mul(float3x3(float3(0.6274039745330810546875f, 0.329281985759735107421875f, 0.043313600122928619384765625f), float3(0.06909699738025665283203125f, 0.919539988040924072265625f, 0.0113612003624439239501953125f), float3(0.01639159955084323883056640625f, 0.0880132019519805908203125f, 0.895595014095306396484375f)), hdrSceneValue.xyz);
    float3 normalizedLinearValue = NormalizeHDRSceneValue(rec2020, paperWhiteNits);
    float3 HDR10 = LinearToST2084(normalizedLinearValue);
    return float4(HDR10, hdrSceneValue.w);
}

[numthreads(8, 8, 1)]
void main(uint3 GlobalInvocationID : SV_DispatchThreadID)
{
    int2 coord = int2(GlobalInvocationID.xy);
    float4 inPixel = InImage[coord];
    OutImage[coord] = ConvertToHDR10(inPixel, 200.0f);
}
''';

class ToneMapping extends Common {
  @override
  String get exampleName => 'ToneMapping';
  Pointer<SdlGpuTexture> imageTexture = nullptr;
  Pointer<SdlGpuTexture> toneMapTexture = nullptr;
  Pointer<SdlGpuTexture> transferTexture = nullptr;
  List<Pointer<SdlGpuComputePipeline>> tonemapOperators = [];
  Pointer<SdlGpuComputePipeline> linearToSrgbPipeline = nullptr;
  Pointer<SdlGpuComputePipeline> linearToSt2084Pipeline = nullptr;
  var swapchainCompositionSelectionIndex = 0;
  var currentSwapchainComposition = 0;
  var tonemapOperatorSelectionIndex = 0;
  var tifImageWidth = 0;
  var tifImageHeight = 0;

  final List<int> swapchainCompositions = [
    SdlkGpuSwapchaincomposition.sdr,
    SdlkGpuSwapchaincomposition.sdrLinear,
    SdlkGpuSwapchaincomposition.hdrExtendedLinear,
    SdlkGpuSwapchaincomposition.hdr10St2084,
  ];

  final swapchainCompositionNames = [
    'SDL_GPU_SWAPCHAINCOMPOSITION_SDR',
    'SDL_GPU_SWAPCHAINCOMPOSITION_SDR_LINEAR',
    'SDL_GPU_SWAPCHAINCOMPOSITION_HDR_EXTENDED_LINEAR',
    'SDL_GPU_SWAPCHAINCOMPOSITION_HDR10_ST2084',
  ];

  final tonemapOperatorNames = [
    'Reinhard',
    'ExtendedReinhardLuminance',
    'Hable',
    'ACES',
  ];

  bool calcSwapchainComposition(Context context, int direction) {
    swapchainCompositionSelectionIndex += direction;
    if (swapchainCompositionSelectionIndex < 0) {
      swapchainCompositionSelectionIndex = swapchainCompositions.length - 1;
    } else if (swapchainCompositionSelectionIndex >=
        swapchainCompositions.length) {
      swapchainCompositionSelectionIndex = 0;
    }
    var result = false;
    if (sdlWindowSupportsGpuSwapchainComposition(
      context.device,
      context.window,
      swapchainCompositions[swapchainCompositionSelectionIndex],
    )) {
      currentSwapchainComposition =
          swapchainCompositions[swapchainCompositionSelectionIndex];
      result = sdlSetGpuSwapchainParameters(
        context.device,
        context.window,
        currentSwapchainComposition,
        SdlkGpuPresentmode.vsync,
      );
      sdlLog(
        'Changing swapchain composition to ${swapchainCompositionNames[swapchainCompositionSelectionIndex]}',
      );
    } else {
      sdlLog(
        'Swapchain composition ${swapchainCompositionNames[swapchainCompositionSelectionIndex]} unsupported',
      );
    }
    return result;
  }

  void calcTonemapOperator(Context context, int direction) {
    tonemapOperatorSelectionIndex += direction;
    if (tonemapOperatorSelectionIndex < 0) {
      tonemapOperatorSelectionIndex = tonemapOperatorNames.length - 1;
    } else if (tonemapOperatorSelectionIndex >= tonemapOperatorNames.length) {
      tonemapOperatorSelectionIndex = 0;
    }
    sdlLog(
      'Changing tonemap operator to ${tonemapOperatorNames[tonemapOperatorSelectionIndex]}',
    );
  }

  @override
  bool init(Context context) {
    useRenderPass = false;
    swapchainCompositionSelectionIndex = 0;
    tonemapOperatorSelectionIndex = 0;
    final tifImage = image.decodeImage(
      File('assets/Images/memorial.tif').readAsBytesSync(),
    );
    if (tifImage == null) {
      sdlLog('Could not load TIFF image data!');
      return false;
    }
    tifImageWidth = tifImage.width;
    tifImageHeight = tifImage.height;
    final tifImagePixels = calloc<Float>(tifImageWidth * tifImageHeight * 4);
    for (var y = 0; y < tifImageHeight; y++) {
      for (var x = 0; x < tifImageWidth; x++) {
        final pixel = tifImage.getPixel(x, y);
        tifImagePixels[(y * tifImageWidth + x) * 4 + 0] = pixel.r.toDouble();
        tifImagePixels[(y * tifImageWidth + x) * 4 + 1] = pixel.g.toDouble();
        tifImagePixels[(y * tifImageWidth + x) * 4 + 2] = pixel.b.toDouble();
        tifImagePixels[(y * tifImageWidth + x) * 4 + 3] = pixel.a.toDouble();
      }
    }
    sdlSetWindowSize(context.window, tifImageWidth, tifImageHeight);
    imageTexture = sdlxCreateGpuTexture(
      context.device,
      SdlxGpuTextureCreateInfo(
        //type: SdlkGpuTexturetype.on2D,
        format: SdlkGpuTextureformat.r32G32B32A32Float,
        width: tifImageWidth,
        height: tifImageHeight,
        layerCountOrDepth: 1,
        numLevels: 1,
        usage:
            SdlkGpuTextureusage.sampler |
            SdlkGpuTextureusage.computeStorageRead,
      ),
    );
    toneMapTexture = sdlxCreateGpuTexture(
      context.device,
      SdlxGpuTextureCreateInfo(
        //type: SdlkGpuTexturetype.on2D,
        format: SdlkGpuTextureformat.r16G16B16A16Float,
        width: tifImageWidth,
        height: tifImageHeight,
        layerCountOrDepth: 1,
        numLevels: 1,
        usage:
            SdlkGpuTextureusage.sampler |
            SdlkGpuTextureusage.computeStorageRead |
            SdlkGpuTextureusage.computeStorageWrite,
      ),
    );
    transferTexture = sdlxCreateGpuTexture(
      context.device,
      SdlxGpuTextureCreateInfo(
        //type: SdlkGpuTexturetype.on2D,
        format: SdlkGpuTextureformat.r8G8B8A8Unorm,
        width: tifImageWidth,
        height: tifImageHeight,
        layerCountOrDepth: 1,
        numLevels: 1,
        usage:
            SdlkGpuTextureusage.sampler |
            SdlkGpuTextureusage.computeStorageWrite,
      ),
    );
    final textureTransferBuffer = sdlxCreateGpuTransferBuffer(
      context.device,
      SdlxGpuTransferBufferCreateInfo(
        //usage: SdlkGpuTransferbufferusage.upload,
        size: tifImageWidth * tifImageHeight * 4 * sizeOf<Float>(),
      ),
    );
    final textureTranferPointer = sdlMapGpuTransferBuffer(
      context.device,
      textureTransferBuffer,
      false,
    );
    sdlMemcpy(
      textureTranferPointer,
      tifImagePixels.cast<Void>(),
      tifImageWidth * tifImageHeight * 4 * sizeOf<Float>(),
    );
    sdlUnmapGpuTransferBuffer(context.device, textureTransferBuffer);
    // Upload the transfer data to the GPU resources
    final uploadCommandBuffer = sdlAcquireGpuCommandBuffer(context.device);
    final copyPass = sdlBeginGpuCopyPass(uploadCommandBuffer);
    sdlxUploadToGpuTexture(
      copyPass,
      SdlxGpuTextureTransferInfo(
        transferBuffer: textureTransferBuffer,
        //offset: 0,
      ),
      SdlxGpuTextureRegion(
        texture: imageTexture,
        w: tifImageWidth,
        h: tifImageHeight,
        d: 1,
      ),
    );
    sdlEndGpuCopyPass(copyPass);
    sdlSubmitGpuCommandBuffer(uploadCommandBuffer);
    sdlReleaseGpuTransferBuffer(context.device, textureTransferBuffer);
    tifImagePixels.callocFree();
    tonemapOperators = [];
    for (final source in gComputeToneMapOperaatorsSource) {
      final pipelineRec = sdlxShaderCrossComputePipelineFromHlsl(
        context.device,
        format,
        SdlxShaderCrossHlslInfo(source: source, entrypoint: 'main'),
      );
      if (pipelineRec == null) {
        sdlLog('Failed to create compute pipeline!');
        return false;
      }
      tonemapOperators.add(pipelineRec.pipeline);
    }
    final linearToSrgbPipelineRec = sdlxShaderCrossComputePipelineFromHlsl(
      context.device,
      format,
      const SdlxShaderCrossHlslInfo(
        source: gComputeLinearSrgoSource,
        entrypoint: 'main',
      ),
    );
    if (linearToSrgbPipelineRec == null) {
      sdlLog('Failed to create compute pipeline!');
      return false;
    }
    linearToSrgbPipeline = linearToSrgbPipelineRec.pipeline;
    //linearToSrgbPipeline = _createComputePipelineFromSource(
    //  context,
    //  gComputeLinearSrgoSource,
    //);
    final linearToSt2084PipelineRec = sdlxShaderCrossComputePipelineFromHlsl(
      context.device,
      format,
      const SdlxShaderCrossHlslInfo(
        source: gComputeLinearSt2084Source,
        entrypoint: 'main',
      ),
    );
    if (linearToSt2084PipelineRec == null) {
      sdlLog('Failed to create compute pipeline!');
      return false;
    }
    linearToSt2084Pipeline = linearToSt2084PipelineRec.pipeline;
    //linearToSt2084Pipeline = _createComputePipelineFromSource(
    //  context,
    //  gComputeLinearSt2084Source,
    //);
    sdlLog('Press Left/Right to cycle swapchain composition');
    sdlLog('Press Up/Down to cycle tonemap operators');
    calcSwapchainComposition(context, 0);
    calcTonemapOperator(context, 0);
    return true;
  }

  @override
  bool update(Context context) {
    if (context.leftPressed) {
      calcSwapchainComposition(context, -1);
    }
    if (context.rightPressed) {
      calcSwapchainComposition(context, 1);
    }
    if (context.upPressed) {
      calcTonemapOperator(context, -1);
    }
    if (context.downPressed) {
      calcTonemapOperator(context, 1);
    }
    return true;
  }

  @override
  bool draw(Context context) {
    final computePass = sdlxBeginGpuComputePass(
      context.commandBuffer,
      textures: [
        SdlxGpuStorageTextureReadWriteBinding(
          texture: toneMapTexture,
          cycle: true,
        ),
      ],
    );
    sdlBindGpuComputePipeline(
      computePass,
      tonemapOperators[tonemapOperatorSelectionIndex],
    );
    sdlxBindGpuComputeStorageTextures(computePass, [imageTexture]);
    sdlDispatchGpuCompute(
      computePass,
      tifImageWidth ~/ 8,
      tifImageHeight ~/ 8,
      1,
    );
    sdlEndGpuComputePass(computePass);
    var blitSourceTexture = toneMapTexture;
    if (currentSwapchainComposition == SdlkGpuSwapchaincomposition.sdr ||
        currentSwapchainComposition ==
            SdlkGpuSwapchaincomposition.hdr10St2084) {
      final transferPass = sdlxBeginGpuComputePass(
        context.commandBuffer,
        textures: [
          SdlxGpuStorageTextureReadWriteBinding(
            texture: transferTexture,
            cycle: true,
          ),
        ],
      );

      if (currentSwapchainComposition == SdlkGpuSwapchaincomposition.sdr) {
        sdlBindGpuComputePipeline(transferPass, linearToSrgbPipeline);
      } else {
        sdlBindGpuComputePipeline(transferPass, linearToSt2084Pipeline);
      }
      sdlxBindGpuComputeStorageTextures(transferPass, [toneMapTexture]);
      sdlDispatchGpuCompute(
        transferPass,
        tifImageWidth ~/ 8,
        tifImageHeight ~/ 8,
        1,
      );
      sdlEndGpuComputePass(transferPass);
      blitSourceTexture = transferTexture;
    }
    sdlxBlitGpuTexture(
      context.commandBuffer,
      SdlxGpuBlitInfo(
        source: SdlxGpuBlitRegion(
          texture: blitSourceTexture,
          w: tifImageWidth,
          h: tifImageHeight,
        ),
        destination: SdlxGpuBlitRegion(
          texture: context.swapchainTexture,
          w: context.swapchainWidth,
          h: context.swapchainHeight,
        ),
        loadOp: SdlkGpuLoadop.dontCare,
        //filter: SdlkGpuFilter.nearest,
      ),
    );
    return true;
  }

  @override
  void quit(Context context) {
    if (tonemapOperators.isNotEmpty) {
      for (final pipeline in tonemapOperators) {
        sdlReleaseGpuComputePipeline(context.device, pipeline);
      }
      tonemapOperators.clear();
    }
    if (linearToSrgbPipeline != nullptr) {
      sdlReleaseGpuComputePipeline(context.device, linearToSrgbPipeline);
      linearToSrgbPipeline = nullptr;
    }
    if (linearToSt2084Pipeline != nullptr) {
      sdlReleaseGpuComputePipeline(context.device, linearToSt2084Pipeline);
      linearToSt2084Pipeline = nullptr;
    }
    if (imageTexture != nullptr) {
      sdlReleaseGpuTexture(context.device, imageTexture);
      imageTexture = nullptr;
    }
    if (toneMapTexture != nullptr) {
      sdlReleaseGpuTexture(context.device, toneMapTexture);
      toneMapTexture = nullptr;
    }
    if (transferTexture != nullptr) {
      sdlReleaseGpuTexture(context.device, transferTexture);
      transferTexture = nullptr;
    }
  }
}

void main() {
  App.run([ToneMapping()]);
}
