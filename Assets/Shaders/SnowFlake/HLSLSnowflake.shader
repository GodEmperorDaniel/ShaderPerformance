Shader "Unlit/HLSLSnowflake"
{
    Properties
    {
        _Sides("Sides", float) = 6
        _Branches("Branches", float) = 5
        _BranchScale("Branch Scale", float) = 0.1

    }
    SubShader
    {
        Tags { "Queue" = "Transparent" "RenderType" = "Transparent" }
        ZWrite Off
        Blend SrcAlpha OneMinusSrcAlpha
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float4 outCol : TEXCOORD1;
                float nrSides : TEXCOORDS2;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _Branches;
            float _Sides;
            float _BranchScale;

            float2 PolarCoordinates(float2 UV, float2 Center, float RadialScale, float LengthScale)
            {
                float2 delta = UV - Center;
                float radius = length(delta) * 2 * RadialScale;
                float angle = atan2(-delta.x, -delta.y) / 6.28 * LengthScale;
                return float2(radius, angle);
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;

                o.nrSides = _Sides * 3.14;

                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                //polar 
                float2 center = float2(0.5, 0.5);
                float2 polar = PolarCoordinates(i.uv, center, 1, 1);

                float sides = polar.y * i.nrSides;

                //rays
                float rays = cos(sides);
                rays = cos(rays);

                //circlemask
                float circleMask = polar.x * 3;
                float reverseCircle = circleMask * 0.5;

                circleMask = cos(circleMask);
                circleMask = 1 - circleMask;

                reverseCircle = cos(reverseCircle);
                reverseCircle = step(reverseCircle, 0);

                //star
                float star = rays * circleMask;
                star += reverseCircle;
                star = 1 - star;
                star = step(star, 0);

                //branches
                float branchPatern = 1 - rays;
                branchPatern *= circleMask * _Branches;
                branchPatern = frac(branchPatern);
                branchPatern = step(branchPatern, 0.5);
                branchPatern += step(rays, 0.6);
                branchPatern = saturate(branchPatern);

                //final calculations
                star = branchPatern - star;
                star = star - step(1 - rays, _BranchScale);

                star = saturate(star); //interesting interaction when the alpha is less than 0, thats why we clamp by saturating
                return float4(star, star, star, star);
            }
            ENDCG
        }
    }
}
