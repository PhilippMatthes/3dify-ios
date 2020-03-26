/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Metal compute shader that translates depth values to color map RGB values.
*/

#include <metal_stdlib>
using namespace metal;

kernel void depthToColorMap(texture2d<float, access::read>  inputTexture      [[ texture(0) ]],
                            texture2d<float, access::write> outputTexture     [[ texture(1) ]],
                            uint2 gid [[ thread_position_in_grid ]])
{
	// Ensure we don't read or write outside of the texture
	if ((gid.x >= inputTexture.get_width()) || (gid.y >= inputTexture.get_height())) {
		return;
	}
	
	float depth = 1.0 - (inputTexture.read(gid).x * 5);
    
    outputTexture.write(float4(depth, depth, depth, 1.0), gid);
}
