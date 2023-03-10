#include "globals.hlsli"

PUSHCONSTANT(push, SkinningPushConstants);

inline void Skinning(inout float3 pos, inout float3 nor, inout float3 tan, in uint4 inBon, in float4 inWei)
{
	if (any(inWei))
	{
		float4 p = 0;
		float3 n = 0;
		float3 t = 0;
		float weisum = 0;

		// force loop to reduce register pressure
		//  also enabled early-exit
		[loop]
		for (uint i = 0; ((i < 4) && (weisum < 1.0f)); ++i)
		{
			float4x4 m = bindless_buffers[push.bonebuffer_index].Load<ShaderTransform>(inBon[i] * sizeof(ShaderTransform)).GetMatrix();

			p += mul(m, float4(pos.xyz, 1)) * inWei[i];
			n += mul((float3x3)m, nor.xyz) * inWei[i];
			t += mul((float3x3)m, tan.xyz) * inWei[i];

			weisum += inWei[i];
		}

		pos.xyz = p.xyz;
		nor.xyz = normalize(n.xyz);
		tan.xyz = normalize(t.xyz);
	}
}


[numthreads(64, 1, 1)]
void main(uint3 DTid : SV_DispatchThreadID, uint3 GTid : SV_GroupThreadID)
{
	[branch]
	if (push.vb_pos_nor_wind < 0)
		return;

	const uint fetchAddress_POS_NOR = DTid.x * sizeof(float4);
	const uint fetchAddress_TAN = DTid.x * sizeof(uint);
	const uint fetchAddress_BON = DTid.x * sizeof(uint4);

	// Manual type-conversion for pos:
	uint4 pos_nor_u = bindless_buffers[push.vb_pos_nor_wind].Load4(fetchAddress_POS_NOR);
	float3 pos = asfloat(pos_nor_u.xyz);

	// Manual type-conversion for normal:
	float4 nor = 0;
	{
		nor.x = (float)((pos_nor_u.w >> 0) & 0x000000FF) / 255.0f * 2.0f - 1.0f;
		nor.y = (float)((pos_nor_u.w >> 8) & 0x000000FF) / 255.0f * 2.0f - 1.0f;
		nor.z = (float)((pos_nor_u.w >> 16) & 0x000000FF) / 255.0f * 2.0f - 1.0f;
		nor.w = (float)((pos_nor_u.w >> 24) & 0x000000FF) / 255.0f; // wind
	}

	// Manual type-conversion for tangent:
	float4 tan = 0;
	[branch]
	if (push.vb_tan >= 0)
	{
		uint vtan = bindless_buffers[push.vb_tan].Load(fetchAddress_TAN);
		tan.x = (float)((vtan >> 0) & 0x000000FF) / 255.0f * 2.0f - 1.0f;
		tan.y = (float)((vtan >> 8) & 0x000000FF) / 255.0f * 2.0f - 1.0f;
		tan.z = (float)((vtan >> 16) & 0x000000FF) / 255.0f * 2.0f - 1.0f;
		tan.w = (float)((vtan >> 24) & 0x000000FF) / 255.0f * 2.0f - 1.0f;
	}

	float4 ind = 0;
	float4 wei = 0;
	[branch]
	if (push.vb_bon >= 0)
	{
		// Manual type-conversion for bone props:
		uint4 ind_wei_u = bindless_buffers[push.vb_bon].Load4(fetchAddress_BON);

		ind.x = (ind_wei_u.x >> 0) & 0x0000FFFF;
		ind.y = (ind_wei_u.x >> 16) & 0x0000FFFF;
		ind.z = (ind_wei_u.y >> 0) & 0x0000FFFF;
		ind.w = (ind_wei_u.y >> 16) & 0x0000FFFF;

		wei.x = (float)((ind_wei_u.z >> 0) & 0x0000FFFF) / 65535.0f;
		wei.y = (float)((ind_wei_u.z >> 16) & 0x0000FFFF) / 65535.0f;
		wei.z = (float)((ind_wei_u.w >> 0) & 0x0000FFFF) / 65535.0f;
		wei.w = (float)((ind_wei_u.w >> 16) & 0x0000FFFF) / 65535.0f;
	}


	// Perform skinning:
	Skinning(pos, nor.xyz, tan.xyz, ind, wei);

	// Store data:
	[branch]
	if (push.so_pos_nor_wind >= 0)
	{
		pos_nor_u.xyz = asuint(pos.xyz);
		pos_nor_u.w = 0;
		pos_nor_u.w |= (uint)((nor.x * 0.5f + 0.5f) * 255.0f) << 0;
		pos_nor_u.w |= (uint)((nor.y * 0.5f + 0.5f) * 255.0f) << 8;
		pos_nor_u.w |= (uint)((nor.z * 0.5f + 0.5f) * 255.0f) << 16;
		pos_nor_u.w |= (uint)(nor.w * 255.0f) << 24; // wind
		bindless_rwbuffers[push.so_pos_nor_wind].Store4(fetchAddress_POS_NOR, pos_nor_u);
	}

	[branch]
	if (push.so_tan >= 0)
	{
		uint vtan = 0;
		vtan |= (uint)((tan.x * 0.5f + 0.5f) * 255.0f) << 0;
		vtan |= (uint)((tan.y * 0.5f + 0.5f) * 255.0f) << 8;
		vtan |= (uint)((tan.z * 0.5f + 0.5f) * 255.0f) << 16;
		vtan |= (uint)((tan.w * 0.5f + 0.5f) * 255.0f) << 24;
		bindless_rwbuffers[push.so_tan].Store(fetchAddress_TAN, vtan);
	}
}
