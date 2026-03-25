// https://github.com/TheSpydog/SDL_gpu_examples/blob/main/Examples/main.c
import 'package:sdl3_gpu_examples/sdl3_gpu_examples.dart';
import 'examples/basic_compute.dart';
import 'examples/basic_stencil.dart';
import 'examples/basic_triangle.dart';
import 'examples/basic_vertex_buffer.dart';
import 'examples/clear_3d_slice.dart';
import 'examples/clear_screen.dart';
import 'examples/cull_mode.dart';
import 'examples/instanced_indexed.dart';
import 'examples/textured_animated_quad.dart';
import 'examples/textured_quad.dart';

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
  //ComputeUniforms(),
  //ToneMapping(),
  //CustomSampling(),
  //DrawIndirect(),
  //ComputeSampler(),
  //CopyAndReadback(),
  //CopyConsistency(),
  //Texture2DArray(),
  //TriangleMSAA(),
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
];

void main() {
  App.run(gExamples, usage: true);
}
