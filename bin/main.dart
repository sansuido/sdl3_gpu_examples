// https://github.com/TheSpydog/SDL_gpu_examples/blob/main/Examples/main.c
import 'package:sdl3_gpu_examples/sdl3_gpu_examples.dart';

import 'examples/basic_compute.dart';
import 'examples/basic_stencil.dart';
import 'examples/basic_triangle.dart';
import 'examples/basic_vertex_buffer.dart';
import 'examples/clear_3d_slice.dart';
import 'examples/clear_screen.dart';
import 'examples/compute_sampler.dart';
import 'examples/compute_uniforms.dart';
import 'examples/copy_and_readback.dart';
import 'examples/copy_consistency.dart';
import 'examples/cull_mode.dart';
import 'examples/custom_noise.dart';
import 'examples/custom_sampling.dart';
import 'examples/draw_indirect.dart';
import 'examples/instanced_indexed.dart';
import 'examples/texture_2d_array.dart';
import 'examples/textured_animated_quad.dart';
import 'examples/textured_quad.dart';
import 'examples/tone_mapping.dart';
import 'examples/triangle_msaa.dart';

final List<Common> gExamples = [
  ClearScreen(),
  BasicVertexBuffer(),
  BasicTriangle(),
  CullMode(),
  BasicStencil(),
  InstancedIndexed(),
  TexturedQuad(),
  TexturedAnimatedQuad(),
  Clear3DSlice(),
  BasicCompute(),
  ComputeUniforms(),
  ToneMapping(),
  CustomSampling(),
  DrawIndirect(),
  ComputeSampler(),
  CopyAndReadback(),
  CopyConsistency(),
  Texture2DArray(),
  TriangleMSAA(),
  //Cubemap(),
  //WindowResize(),
  //Blit2DArray(),
  //BlitCube(),
  //BlitMirror(),
  //GenerateMipmaps(),
  //Latency(),
  //DepthSampler(),
  //ComputeSpriteBatch(),
  //PullSpriteBatch(),
  //TextureTypeTest(),
  //CompressedTextures(),
  CustomNoise(),
];

void main() {
  App.run(gExamples, usage: true);
}
