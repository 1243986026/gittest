Shader "Universal Render Pipeline/Custom/Standard Shader/Standard ShaderLibrary Shader"
{
    Properties
    {
        [Header(Base Data)]
        [MainTexture] _BaseMap("Albedo", 2D) = "white" {}
        [MainColor] _BaseColor("Base Color", Color) = (1.0, 1.0, 1.0, 1.0)

        [Header(Normal Data)] 
        [Toggle(_NORMALMAP)] _USENormalMap("USE Normal Map", Int) = 1
        _BumpMap("Normal Map", 2D) = "bump" {}
        _BumpScale("Normal Scale", Range(0.0, 2.0)) = 1

        [Header(Mask Data)]
        _MetallicGlossMap("Mask Map",2D) = "white" {}
        _Smoothness("Smoothness", Range(0.0, 1.0)) = 0.5//调整光滑度
        _Metallic("Metallic", Range(0.0, 1.0)) = 0.0//调整金属度
        _OcclusionStrength("Occlusion Strength",Range(0.0, 1.0))=1.0//调整AO强度

        [Header(Emission)]
        [Toggle(_EMISSION)] _EMISSION("USE Emission Map", Int)=0
        _EmissionMap("Emission Map", 2D)="black"{}
        [HDR]_EmissionColor("Emission Color", Color)=(0.0, 0.0, 0.0, 0.0)

        [Header(Parallax)]
        [Toggle(_PARALLAXMAP)]_PARALLAXMAP("USE Parallax Map", Int) = 0
        _ParallaxMap("Parallax Map", 2D) = "black"{}
        _Parallax("Parallax", Range(0.0, 0.1)) = 0.0

        [Header(Other)]
        [Toggle(_CLIP)] _AlphaClip("Clip", Int) = 0.0
        _Cutoff("Clip Range", Range(0.0, 1.0)) = 0.0
        [Enum(Off,0, Front,1, Back, 2)]_Cull("Cull Mode", Float) = 2.0
    }
    SubShader
    {
        Tags{"RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True"}
        
        HLSLINCLUDE

        #include "../ShaderLibrary/StandardLighting.hlsl" //由于使用自定义ShaderLibrary,需要修改路径
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        CBUFFER_START(UnityPerMaterial);
        half4 _BaseColor;
        half4 _BaseMap_ST;
        half _BumpScale;
        half _Smoothness;
        half _Metallic;
        half _OcclusionStrength;
        half4 _EmissionColor;
        half _Parallax;
        half _Cutoff;
        CBUFFER_END;

        half _Surface;

        TEXTURE2D(_MetallicGlossMap); SAMPLER(sampler_MetallicGlossMap);

        TEXTURE2D(_EmissionMap); SAMPLER(sampler_EmissionMap);

        #if defined(_PARALLAXMAP)
        TEXTURE2D(_ParallaxMap); SAMPLER(sampler_ParallaxMap);
        #endif
    
        #include "../ShaderLibrary/StandardLitInput.hlsl"

        void InitializeStandardLitSurfaceData(float2 uv, out SurfaceData outSurfaceData)//传入所需数据
        {
            half4 Mask = SAMPLE_TEXTURE2D(_MetallicGlossMap, sampler_BaseMap, uv);
            half4 albedoAlpha = SampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
            
            outSurfaceData.albedo = albedoAlpha.rgb * _BaseColor.rgb;
            outSurfaceData.specular = half3(0.0,0.0,0.0);
            outSurfaceData.metallic = Mask.r * _Metallic;
            outSurfaceData.smoothness =  Mask.a * _Smoothness * albedoAlpha.a;
            outSurfaceData.occlusion = Mask.b * _OcclusionStrength;
            outSurfaceData.normalTS = SampleNormal(uv, TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap), _BumpScale);
            outSurfaceData.emission = SampleEmission(uv, _EmissionColor.rgb, TEXTURE2D_ARGS(_EmissionMap, sampler_EmissionMap));
            outSurfaceData.alpha = _BaseColor.a * albedoAlpha.a;
            outSurfaceData.clearCoatSmoothness = 0.0;
            outSurfaceData.clearCoatMask = 0.0;
        }

        ENDHLSL

        Pass
        {
            Tags {"LightMode" = "UniversalForward"}
            HLSLPROGRAM

            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _CLIP
            #pragma shader_feature_local _NORMALMAP //在我们需要使用法线贴图时,才需要采样法线贴图,Lit.Shader使用了这个宏来判断是否需要采样法线贴图
            //#pragma shader_feature_local_fragment _ALPHATEST_ON //开启Alpha Test
            //#pragma shader_feature_local_fragment _ALPHAPREMULTIPLY_ON //开启后，颜色值会乘以透明度，且透明度会与金属度或高光相关联（取决于哪个工作流）
            #pragma shader_feature_local_fragment _EMISSION //是否使用自发光贴图。不需要的话就注释掉
            //#pragma shader_feature_local_fragment _METALLICSPECGLOSSMAP //先根据金属度贴图或者高光贴图得到光滑度
            //#pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A //如果开启这个宏，albedo贴图的A通道会乘以smoothness作为最终输出的光滑度，否则光滑度即等于smoothness（这个算法只适用于Lit.Shader，因为他们没有使用光滑度贴图，或者说他们光滑度贴图在albedo贴图的a通道，所以我们注释掉了）
            #pragma shader_feature_local _PARALLAXMAP //是否使用_ParallaxMap,视察贴图,也俗称高度图HeightMap
            //#pragma shader_feature_local _ _DETAIL_MULX2 _DETAIL_SCALED //Detail贴图的控制，我们不需要
            #pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF //直接光高光的开关
            #pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF //间接光环境反射的开关
            #pragma shader_feature_local _RECEIVE_SHADOWS_OFF

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile_fog

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON

            #include "../ShaderLibrary/StandardLitForwardPass.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            

            HLSLPROGRAM

            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature _ALPHATEST_ON

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma shader_feature _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }
        
        Pass
        {
            Name "Meta"
            Tags{"LightMode" = "Meta"}

            Cull Off
            
            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex UniversalVertexMeta
            #pragma fragment UniversalFragmentMeta

            #pragma shader_feature_local_fragment _SPECULAR_SETUP
            //#pragma shader_feature_local_fragment _EMISSION
            //#pragma shader_feature_local_fragment _METALLICSPECGLOSSMAP
            //#pragma shader_feature_local_fragment _ALPHATEST_ON
            //#pragma shader_feature_local_fragment _ _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            //pragma shader_feature_local _ _DETAIL_MULX2 _DETAIL_SCALED

            #pragma shader_feature_local_fragment _SPECGLOSSMAP

            #include "../ShaderLibrary/CustomLitMetaPass.hlsl"

            ENDHLSL
        }
    }
}