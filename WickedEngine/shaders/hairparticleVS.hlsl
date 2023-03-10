#include "globals.hlsli"
#include "hairparticleHF.hlsli"
#include "ShaderInterop_HairParticle.h"

Buffer<uint> primitiveBuffer : register(t0);

VertexToPixel main(uint vid : SV_VERTEXID)
{
	ShaderGeometry geometry = HairGetGeometry();

	VertexToPixel Out;
	Out.primitiveID = vid / 3;

	uint vertexID = primitiveBuffer[vid];
	uint4 data = bindless_buffers[geometry.vb_pos_nor_wind].Load4(vertexID * 16);
	float3 position = asfloat(data.xyz);
	float3 normal = normalize(unpack_unitvector(data.w));
	float4 uvsets = unpack_half4(bindless_buffers[geometry.vb_uvs].Load2(vertexID * 8));

	Out.fade = saturate(distance(position.xyz, GetCamera().position.xyz) / xHairViewDistance);
	Out.fade = saturate(Out.fade - 0.8f) * 5.0f; // fade will be on edge and inwards 20%

	Out.pos = float4(position, 1);
	Out.pos3D = Out.pos.xyz;
	Out.pos = mul(GetCamera().view_projection, Out.pos);

	Out.nor = normalize(normal);
	Out.tex = uvsets.xy;

	return Out;
}
