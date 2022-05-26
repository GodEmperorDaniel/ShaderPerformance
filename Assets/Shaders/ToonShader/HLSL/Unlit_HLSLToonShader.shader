Shader "Unlit/Unlit_HLSLToonShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        [HDR] 
        _FrontColour ("Flat Front Colour", Color) = (0,0,0,0) 
        [HDR]
        _BackColour ("Flat Back Colour", Color) = (0,0,0,0)
        
        [HDR]
        _SpecularColour("Specular Colour", Color) = (0,0,0,0)
        _Glossiness("Glossiness", Float) = 32

        [HDR]
        _RimColour("Rim Colour", Color) = (0,0,0,0)
        _RimAmount("Rim Amount", Range(0, 1)) = 0.716
        _RimThreshold("Rim Threshold", Range(0,1)) = 0.1
    }
    SubShader
    {
        Tags 
        { 
            "RenderType"="Opaque"
            "LightMode" = "UniversalForward" 
            "PassFlags" = "OnlyDirectional"
        }
        LOD 100

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        ENDHLSL

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdbase

            
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldNormal : NORMAL;
                float3 viewDirection : TEXCOORD1;
                float glossXGloss : TEXCOORD2;
                float4 shadowCoords : TEXCOORD3;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _FrontColour;
            float4 _BackColour;
            float4 _SpecularColour;
            float _Glossiness;
            float4 _RimColour;
            float _RimAmount;
            float _RimThreshold;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = mul(UNITY_MATRIX_VP, mul(unity_ObjectToWorld, v.vertex));
                
                //calculate shadow coords to read 
                float4 _posWS = mul(unity_ObjectToWorld, v.vertex);
                o.shadowCoords = TransformWorldToShadowCoord(_posWS);

                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldNormal = normalize(mul(v.normal, (float3x3)unity_WorldToObject));
                o.viewDirection = _WorldSpaceCameraPos - _posWS;
                o.glossXGloss = _Glossiness * _Glossiness;
                return o;
            }

            float4 specularComponent(float3 view, float3 lightDir, float3 normal, float lightIntensity, float gloss)
            {
                float3 halfVec = normalize(view + lightDir); 
                float NdotH = dot(normal, halfVec);
                float spec = pow(NdotH * lightIntensity, gloss);

                float specSmooth = smoothstep(0.005, 0.01, spec);

                float4 specCol = specSmooth * _SpecularColour;

                return specCol;
            }

            float4 rimLighting(float3 view, float3 normal, float attenuation)
            {
                float rim = 1 - dot(view, normal);
                float rimIntensity = rim * pow(attenuation, _RimThreshold);
                rimIntensity = smoothstep(_RimAmount - 0.01, _RimAmount + 0.01, rimIntensity);
                float4 rimCol = rimIntensity * _RimColour;

                return rimCol;
            }

            float4 frag(v2f i) : SV_Target
            {

                float3 normal = normalize(i.worldNormal);
                Light _myLight = GetMainLight(i.shadowCoords);
               
                ShadowSamplingData shadowSamplingData = GetMainLightShadowSamplingData();
                float ShadowAtten = SampleShadowmapFiltered(TEXTURE2D_SHADOW_ARGS(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture),i.shadowCoords, shadowSamplingData);

                float3 lightDir = normalize(_myLight.direction);
                float NdotL = dot(lightDir, normal);

                float lightIntensity = smoothstep(0, 0.01, NdotL * ShadowAtten);

                //for specular
                float3 v = normalize(i.viewDirection);
                float4 spec = specularComponent(v, lightDir, normal, lightIntensity, i.glossXGloss);

                //rimlight
                float4 rim = rimLighting(v, normal, lightIntensity);

                //mixing/blending
                float4 specPlusRim = rim + spec;
                float4 front = lightIntensity * _FrontColour;
                float4 back = (1 - lightIntensity) * _BackColour;

                return back + front + specPlusRim;
            }
        ENDHLSL
        }
        //UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"
        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
    }
}
