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
            "LightMode" = "UniversalForward" //not sure this exsists in URP; answer, it does not
            "PassFlags" = "OnlyDirectional"
        }

        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdbase

            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
            #include "UnityShadowLibrary.cginc"

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
                
                o.vertex = UnityObjectToClipPos(v.vertex);
                
                //calculate shadow coords to read 
                float4 posWS = mul(unity_ObjectToWorld, v.vertex);
                o.shadowCoords = mul(unity_WorldToShadow[1], posWS);

                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.viewDirection = WorldSpaceViewDir(v.vertex);
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

            fixed4 frag(v2f i) : SV_Target
            {

                float3 normal = normalize(i.worldNormal);
                float3 lightDir = normalize(_WorldSpaceLightPos0);
                float NdotL = dot(lightDir, normal);
                
                //shadows
                half4 shadowCoord = TransformWorldToShadowCoord(WorldPos);
                Light mainLight = GetMainLight(shadowCoord);
                Direction = mainLight.direction;
                Colour = mainLight.color;
                DistanceAtten = mainLight.distanceAttenuation;
                ShadowAtten = mainLight.shadowAttenuation;

                /*UNITY_DECLARE_SHADOWMAP(_ShadowMapTexture);
                fixed shadow = UNITY_SAMPLE_SHADOW(_ShadowMapTexture, i.shadowCoords.xyz);*/
                //float shadow = UnitySampleShadowmap_PCF3x3(i.shadowCoords, 1.0);

                float lightIntensity = smoothstep(0, 0.01, NdotL); //this is only a step
                return ShadowAtten;
                float4 light = lightIntensity * _LightColor0;

                //for specular
                float3 v = normalize(i.viewDirection);
                float4 spec = specularComponent(v, lightDir, normal, light, i.glossXGloss);

                float4 rim = rimLighting(v, normal, NdotL);

                return _FrontColour * (light + _BackColour + spec + rim);
            }
            ENDCG
        }

        UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"
    }
}
