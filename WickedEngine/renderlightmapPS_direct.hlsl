#include "globals.hlsli"
#include "ShaderInterop_TracedRendering.h"
#include "tracedRenderingHF.hlsli"
#include "raySceneIntersectHF.hlsli"

struct Input
{
	float4 pos : SV_POSITION;
	float2 uv : TEXCOORD;
	float3 pos3D : WORLDPOSITION;
	float3 normal : NORMAL;
};

float4 main(Input input) : SV_TARGET
{
	float3 N = normalize(input.normal);
	float2 uv = input.uv;
	float seed = xTraceRandomSeed;
	float3 P = input.pos3D;
	float3 finalResult = 0;

	[loop]
	for (uint iterator = 0; iterator < g_xFrame_LightArrayCount; iterator++)
	{
		ShaderEntityType light = EntityArray[g_xFrame_LightArrayOffset + iterator];
		Lighting lighting = CreateLighting(0, 0, 0, 0);

		if (!(light.GetFlags() & ENTITY_FLAG_LIGHT_STATIC))
		{
			continue; // dynamic lights will not be baked into lightmap
		}

		float3 L = 0;
		float dist = 0;

		switch (light.GetType())
		{
		case ENTITY_TYPE_DIRECTIONALLIGHT:
		{
			dist = INFINITE_RAYHIT;

			float3 lightColor = light.GetColor().rgb*light.energy;

			L = light.directionWS.xyz;

			lighting.direct.diffuse = lightColor;
		}
		break;
		case ENTITY_TYPE_POINTLIGHT:
		{
			L = light.positionWS - P;
			const float dist2 = dot(L, L);
			dist = sqrt(dist2);

			[branch]
			if (dist < light.range)
			{
				L /= dist;

				const float3 lightColor = light.GetColor().rgb*light.energy;

				lighting.direct.diffuse = lightColor;

				const float range2 = light.range * light.range;
				const float att = saturate(1.0 - (dist2 / range2));
				const float attenuation = att * att;

				lighting.direct.diffuse *= attenuation;
			}
		}
		break;
		case ENTITY_TYPE_SPOTLIGHT:
		{
			L = light.positionWS - P;
			const float dist2 = dot(L, L);
			dist = sqrt(dist2);

			[branch]
			if (dist < light.range)
			{
				L /= dist;

				const float3 lightColor = light.GetColor().rgb*light.energy;

				const float SpotFactor = dot(L, light.directionWS);
				const float spotCutOff = light.coneAngleCos;

				[branch]
				if (SpotFactor > spotCutOff)
				{
					lighting.direct.diffuse = lightColor;

					const float range2 = light.range * light.range;
					const float att = saturate(1.0 - (dist2 / range2));
					float attenuation = att * att;
					attenuation *= saturate((1.0 - (1.0 - SpotFactor) * 1.0 / (1.0 - spotCutOff)));

					lighting.direct.diffuse *= attenuation;
				}
			}
		}
		break;
		case ENTITY_TYPE_SPHERELIGHT:
		{
		}
		break;
		case ENTITY_TYPE_DISCLIGHT:
		{
		}
		break;
		case ENTITY_TYPE_RECTANGLELIGHT:
		{
		}
		break;
		case ENTITY_TYPE_TUBELIGHT:
		{
		}
		break;
		}

		float NdotL = saturate(dot(L, N));

		if (NdotL > 0 && dist > 0)
		{
			lighting.direct.diffuse = max(0.0f, lighting.direct.diffuse);

			float3 sampling_offset = float3(rand(seed, uv), rand(seed, uv), rand(seed, uv)) * 2 - 1;

			Ray newRay;
			newRay.origin = trace_bias_position(P, N);
			newRay.direction = L + sampling_offset * 0.025f;
			newRay.direction_inverse = rcp(newRay.direction);
			newRay.energy = 0;
			bool hit = TraceSceneANY(newRay, dist);
			finalResult += (hit ? 0 : NdotL) * (lighting.direct.diffuse);
		}
	}

	return max(0, float4(finalResult, xTraceUserData));
}
