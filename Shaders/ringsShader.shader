// Ring shader for Kopernicus
// by Ghassen Lahmar (blackrack)

Shader "Kopernicus/Rings"
{
  SubShader
  {
    Tags
    {
      "Queue"           = "Transparent"
      "IgnoreProjector" = "True"
      "RenderType"      = "Transparent"
    }

    Pass
    {
      ZWrite On
      Cull Off
      // Alpha blend
      Blend SrcAlpha OneMinusSrcAlpha

      CGPROGRAM
      #pragma vertex vert
      #pragma fragment frag
      #pragma glsl
      #pragma target 3.0

      #include "UnityCG.cginc"

      // These properties are the global inputs shared by all pixels

      uniform sampler2D _MainTex;

      uniform float innerRadius;
      uniform float outerRadius;

      uniform float planetRadius;
      uniform float sunRadius;

      uniform float3 sunPosRelativeToPlanet;

      uniform float penumbraMultiplier;

      // Unity will set this to the material color automatically
      uniform float4 _Color;

      #define M_PI 3.1415926535897932384626

      // This structure defines the inputs for each pixel
      struct v2f
      {
        float4 pos:          SV_POSITION;
        float3 worldPos:     TEXCOORD0;
        // Moved from fragment shader
        float3 planetOrigin: TEXCOORD1;
        float2 texCoord:     TEXCOORD2;
      };

      // Set up the inputs for the fragment shader
      v2f vert(appdata_base v)
      {
        v2f o;
        o.pos          = mul(UNITY_MATRIX_MVP,    v.vertex);
        o.worldPos     = mul(unity_ObjectToWorld, v.vertex);
        o.planetOrigin = mul(unity_ObjectToWorld, float4(0, 0, 0, 1)).xyz;
        o.texCoord     = v.texcoord;
        return o;
      }

      // Mie scattering
      // Copied from Scatterer/Proland
      float PhaseFunctionM(float mu, float mieG)
      {
        // Mie phase function
        return 1.5 * 1.0 / (4.0 * M_PI) * (1.0 - mieG * mieG) * pow(1.0 + (mieG * mieG) - 2.0 * mieG * mu, -3.0 / 2.0) * (1.0 + mu * mu) / (2.0 + mieG * mieG);
      }

      // Eclipse function from Scatterer
      // Used here to cast the planet shadow on the ring
      // Will simplify it later and keep only the necessary bits for the ring
      // Original Source:   wikibooks.org/wiki/GLSL_Programming/Unity/Soft_Shadows_of_Spheres
      float getEclipseShadow(float3 worldPos, float3 worldLightPos, float3 occluderSpherePosition, float3 occluderSphereRadius, float3 lightSourceRadius)
      {
        float3 lightDirection = float3(worldLightPos - worldPos);
        float3 lightDistance  = length(lightDirection);
        lightDirection = lightDirection / lightDistance;

        // Computation of level of shadowing w
        // Occluder planet
        float3 sphereDirection = float3(occluderSpherePosition - worldPos);
        float  sphereDistance  = length(sphereDirection);
        sphereDirection = sphereDirection / sphereDistance;

        float dd = lightDistance * (asin(min(1.0, length(cross(lightDirection, sphereDirection)))) - asin(min(1.0, occluderSphereRadius / sphereDistance)));

        float w = smoothstep(-1.0, 1.0, -dd / lightSourceRadius)
            * smoothstep(0.0, 0.2, dot(lightDirection, sphereDirection));

        return (1 - w);
      }

      // Choose a color to use for the pixel represented by 'i'
      float4 frag(v2f i): COLOR
      {
        // Lighting
        // Fix this for additional lights later, will be useful when I do the Planetshine update for Scatterer
        // Assuming directional light only for now
        float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);

        // Instead use the viewing direction (inspired from observing space engine rings)
        // Looks more interesting than I expected
        float3 viewdir  = normalize(i.worldPos - _WorldSpaceCameraPos);
        float  mu       = dot(lightDir, -viewdir);
        float  dotLight = 0.5 * (mu + 1);

        // Mie scattering through rings when observed from the back
        // Needs to be negative?
        float mieG = -0.95;
        // Result too bright for some reason, the 0.03 fixes it
        float mieScattering = 0.03 * PhaseFunctionM(mu, mieG);

        // Planet shadow on ring
        // Do everything relative to planet position
        // *6000 to convert to local space, might be simpler in scaled?
        float3 worldPosRelPlanet = i.worldPos - i.planetOrigin;
        float shadow = getEclipseShadow(worldPosRelPlanet * 6000, sunPosRelativeToPlanet, 0, planetRadius, sunRadius * penumbraMultiplier);

        //TODO: Fade in some noise here when getting close to the rings
        //      Make it procedural noise?

        // Look up the texture color
        float4 color = tex2D(_MainTex, i.texCoord);
        // Combine material color with texture color and shadow
        color.xyz = _Color * shadow * (color.xyz * dotLight + color.xyz * mieScattering);

        // I'm kinda proud of this shader so far, it's short and clean
        return color;
      }
      ENDCG
    }
  }
}
