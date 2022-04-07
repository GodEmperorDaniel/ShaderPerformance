Shader "Unlit/Custom HLSL Water Shader"
{
    Properties
    {
        //[PowerSlider(2.0)]
        _WaterDepth("Water Depth", float) = 10
        [HDR]
        _ShallowWaterColour("Shallow Water Colour", Color) = (0, 0.8113, 0.6353, 1)
        [HDR]
        _DeepWaterColour("Deep Water Colour", Color) = (0, 0.15, 0.76, 1)
        _RefractionSpeed("Refraction Speed", float) = 0.1
        _RefractionScale("Refraction Scale", float) = 1
        _RefractionStrength("Refraction Strength", float) = 1
        _FoamAmount("Foam Amount", float) = 0
        _FoamCutOff("Foam Cut-off", float) = 1
        _FoamSpeed("Foam Speed", float) = 1
        _FoamScale("Foam Scale", float) = 100
        [HDR]
        _FoamColour("Foam Colour", Color) = (1,1,1,1)
        [HideInInspector]
        _EyeVector("Eye Vector", float) = 0
    }
    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" }
        LOD 100

        //Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off   
        

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION; //Object-space
                float2 uv : TEXCOORD0; //uv-space
                float3 normal : NORMAL; //normal in object-space
                float4 tangent : TANGENT; //xyz = tangent dir, w = tangent sign. This is used if uvs are flipped!
            };

            struct v2f //vertex to fragment
            {
                float4 projPos : TEXCOORD0;
                float4 vertex : SV_POSITION; //clip-space position / screen pos
                float3 wsPos : TEXCOORD1;
                float3x3 tangentSP : TEXCOORD2;
                float2 uv : TEXCORD3;
            };
            
            float _WaterDepth;
            float4 _ShallowWaterColour;
            float4 _DeepWaterColour;
            float _RefractionSpeed;
            float _RefractionScale;
            float _RefractionStrength;
            float _FoamAmount;
            float _FoamCutOff;
            float _FoamSpeed;
            float _FoamScale;
            float4 _FoamColour;
            float4 _EyeDist;
            UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);
            sampler2D _CameraOpaqueTexture;

            //from unity doc https://docs.unity3d.com/Packages/com.unity.shadergraph@10.4/manual/Gradient-Noise-Node.html
            float2 unity_gradientNoise_dir(float2 p)
            {
                p = p % 289; //kolla hur denna körs
                float x = (34 * p.x + 1) * p.x % 289 + p.y;
                x = (34 * x + 1) * x % 289;
                x = frac(x / 41) * 2 - 1;
                return normalize(float2(x - floor(x + 0.5), abs(x) - 0.5));
            }

            float unity_gradientNoise(float2 p)
            {
                float2 ip = floor(p);
                float2 fp = frac(p);
                float d00 = dot(unity_gradientNoise_dir(ip), fp);
                float d01 = dot(unity_gradientNoise_dir(ip + float2(0, 1)), fp - float2(0, 1));
                float d10 = dot(unity_gradientNoise_dir(ip + float2(1, 0)), fp - float2(1, 0));
                float d11 = dot(unity_gradientNoise_dir(ip + float2(1, 1)), fp - float2(1, 1));
                fp = fp * fp * fp * (fp * (fp * 6 - 15) + 10);
                return lerp(lerp(d00, d01, fp.y), lerp(d10, d11, fp.y), fp.x);
            }

            //reference code from https://docs.unity3d.com/Packages/com.unity.shadergraph@10.4/manual/Normal-From-Height-Node.html
           float3 Unity_NormalFromHeight_Tangent_float(float In, float Strength, float3 Position, float3x3 TangentMatrix) //why does this use out instead of return type??
            {
                float3 worldDerivativeX = ddx(Position);
                float3 worldDerivativeY = ddy(Position);

                float3 crossX = cross(TangentMatrix[2].xyz, worldDerivativeX);
                float3 crossY = cross(TangentMatrix[2].xyz, worldDerivativeY);
                float d = dot(worldDerivativeX, crossY);
                float sgn = d < 0.0 ? (-1.f) : 1.f;
                float surface = sgn / max(0.00000000000001192093f, abs(d));

                float dHdx = ddx(In);
                float dHdy = ddy(In);
                float3 surfGrad = surface * (dHdx * crossY + dHdy * crossX);
                float3 Out = normalize(TangentMatrix[2].xyz - (Strength * surfGrad));
                Out = mul(Out, TangentMatrix); 

                return Out;
           }

            //eyevector code from https://forum.unity.com/threads/what-is-eye-space-in-unity-shaders-nb-its-not-view-space.797775/
            v2f vert (appdata v)
            {
                v2f o;

                o.vertex = UnityObjectToClipPos(v.vertex);
                o.projPos = ComputeScreenPos(o.vertex);
                float3 normal = UnityObjectToWorldNormal(v.normal);
                float3 tangent = UnityObjectToWorldDir(v.tangent.xyz);
                float3 bitangent = cross(normal, tangent); 
                bitangent *= (v.tangent.w * unity_WorldTransformParams.w); //not sure if i need to flipp uvs! i dont map

                o.tangentSP = float3x3(tangent.xyz, bitangent, v.normal);

                o.uv = v.uv;

                o.wsPos = mul(v.vertex, unity_WorldToObject);

                COMPUTE_EYEDEPTH(o.projPos.z);

                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                // raw depth from the depth texture
                float depthZ = SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(i.projPos)); //pretty sure this can be written more pretty?
                // linear eye depth recovered from the depth texture
                float sceneZ = LinearEyeDepth(depthZ);
                // difference between sceneZ and fragZ
                float fragZ = i.projPos.z;

                //tiling and offset uvs with time
                float2 waves = (i.uv * _RefractionScale) + (_RefractionSpeed * _Time.y); //this is where time later can be multiplied
                float gradientNoice = unity_gradientNoise(waves * 50); //50 is just a magic number right now!
                //i get a different random than shadergraph?? //moved up shadergraphs result to better contrast

                //Creating a heightmap from the tangent.
                float3 heightMap = Unity_NormalFromHeight_Tangent_float(gradientNoice, 0.0006, i.wsPos.xyz, i.tangentSP); //the strenght is a magnitude of 10 less than it's shadergraph equivalent //scrap that more now...
                heightMap.z = UnpackNormalmapRGorAG(float4(heightMap,0) * 0.5 + 0.5).z; //wow this is scuffed
                
                heightMap = heightMap * _RefractionStrength; //multiplying a strength variable to this 

                float3 heightConvertedToScreen = heightMap + (float3(i.projPos.xy, 0) / i.vertex.w); //fix this!!

                float3 opaqueTexture = tex2D(_CameraOpaqueTexture, heightConvertedToScreen.xy);
                
                float depthDif = saturate((sceneZ - fragZ) / _WaterDepth);
                float4 waterColour = lerp(_ShallowWaterColour, _DeepWaterColour, depthDif);
                //return float4(waterColour.xyz,1);
                
                //foam stuff
                float depthDifFoam = saturate((sceneZ - fragZ) / (_FoamAmount));
                float foamFader = depthDifFoam * _FoamCutOff;

                //TILING for foam
                float2 foam = (i.uv * _FoamScale) + (_FoamSpeed * _Time.y);
                float gradientNoiceFoam = unity_gradientNoise(foam * 2.5) + 0.5;

                float stepCalc = step(foamFader, gradientNoiceFoam);

                float lerper = _FoamColour.w * stepCalc;
                
                //return float4(stepCalc, 0, 0, 1);

                float4 foamWaterColour = lerp(waterColour,_FoamColour, stepCalc);
                float4 outColour = lerp(float4(opaqueTexture, 1), foamWaterColour, foamWaterColour.w);
                
                return outColour;
            }
            ENDCG
        }
    }
}
