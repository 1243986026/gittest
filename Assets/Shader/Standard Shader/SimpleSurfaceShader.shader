Shader "Universal Render Pipeline/Custom/Standard Shader/Simple Surface Shader"
{
    Properties
    {
        [Header(Base Data)]
        [MainColor] _BaseColor("Base Color", Color) = (1.0,1.0,1.0,1.0)
        [MainTexture] _BaseMap("Albedo", 2D) = "white" {}
        _BaseColorInt("BaseColor Intensity", Float) = 1.0

        [Header(Normal Data)]
        [Toggle(_NORMALMAP)] _USENormalMap("USE Normal Map", Int)=1
        _BumpMap("Normal Map",2D)="bump"{}
        _BumpScale("Normal Scale",Range(0.0,2.0))=1

        [Header(Mask Data)] 
        [Toggle(_SURFACE)] SURFACE("USE PBR Map", Int) = 1.0
        _MetallicGlossMap("Mask Map",2D)="white"{}
        _Smoothness("Smoothness", Range(0.0, 1.0)) = 0.5//调整光滑度 
        _Metallic("Metallic Strength", Range(0.0, 1.0)) = 0.0//调整金属度
        _OcclusionStrength("Occlusion Strength",Range(0.0,1.0))=1.0//调整AO强度
 
        [Header(Emission)] 
        [Toggle(_EMISSION)] _EMISSION("USE Emission Map", Int)=0.0 
        _EmissionMap("Emission Map", 2D) = "white"{}
        [HDR]_EmissionColor("Emission Color",Color)=(0.0, 0.0, 0.0, 0.0) 

        [Header(Height)]    
        [Toggle(_PARALLAXMAP)] _PARALLAXMAP("USE Height Map", Int)=0.0 
        _Parallax("Scale", Range(0.005, 0.08)) = 0.005
        _ParallaxMap("Height Map", 2D) = "black" {}

        [Header(Other)]
        [Toggle(_CLIP)] _AlphaClip("Clip", Int) = 0.0
        _Cutoff("Clip Range", Range(0.0, 1.0)) = 0.0
        [Enum(Off,0, Front,1, Back, 2)]_Cull("Cull Mode", Float) = 2.0
    }
    SubShader
    {
        //简化方案：
        //丢弃掉litforwardpass里的一些没必要计算(还是正常计算Alpha，不过最终输出Alpha完全去角力SurfaceData里的Alpha)
        //使用宏来优化采样贴图
        Tags{"RenderType" = "Transparent" "RenderPipeline" = "UniversalPipeline" "IgnoreProjector" = "True"}

        HLSLINCLUDE

        #include "../ShaderLibrary/SimpleLighting.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

 
        CBUFFER_START(UnityPerMaterial);
        half4 _BaseColor;
        half4 _BaseMap_ST;
        half _BaseColorInt;
        half _BumpScale;
        half _Smoothness;
        half _Metallic;
        half _OcclusionStrength;
        half4 _EmissionColor;
        half _Cutoff;
        half _Parallax;
        half _Cull;
        CBUFFER_END;
        
        //Global
        uniform half _GITest = 0.0;
        uniform half _NightIntensity = 0.2;
        uniform half _DayIntensity = 1.0;
        uniform half _ReflectionIntensity = 0.5;
        uniform half4 _GIColor = half4(0.85, 0.95, 1.0, 1.0);

        #ifdef _PARALLAXMAP
        TEXTURE2D(_ParallaxMap); SAMPLER(sampler_ParallaxMap);
        #endif

        #ifdef _SURFACE
        TEXTURE2D(_MetallicGlossMap); SAMPLER(sampler_MetallicGlossMap);
        #endif

        #ifdef _EMISSION
        TEXTURE2D(_EmissionMap); SAMPLER(sampler_EmissionMap);
        #endif
        
        #include "../ShaderLibrary/SimpleLitInput.hlsl"

        void InitializeStandardLitSurfaceData(float2 uv, out SurfaceData outSurfaceData)//传入所需数据
        {
            #ifdef _SURFACE
                half4 Mask = SAMPLE_TEXTURE2D(_MetallicGlossMap, sampler_MetallicGlossMap, uv);
            #endif 
 
            half4 albedoAlpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv); 
 
            outSurfaceData.albedo = albedoAlpha.rgb * _BaseColor.rgb * _BaseColorInt;

            outSurfaceData.specular = half3(0.0, 0.0, 0.0);
 
            #ifdef _SURFACE
                outSurfaceData.metallic = Mask.r ;
                outSurfaceData.smoothness = Mask.a * _Smoothness  * albedoAlpha.a;
                outSurfaceData.occlusion = _OcclusionStrength;
            #else
                outSurfaceData.metallic = _Metallic;
                outSurfaceData.smoothness = _Smoothness;
                outSurfaceData.occlusion = _OcclusionStrength;
            #endif

            #ifdef _NORMALMAP
                outSurfaceData.normalTS = SampleNormal(uv, TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap), _BumpScale);
            #endif

            #ifdef _EMISSION
                outSurfaceData.emission = SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, uv) * _EmissionColor;   
            #else  
                outSurfaceData.emission = half3(_EmissionColor.rgb);
            #endif
            outSurfaceData.alpha = _BaseColor.a * albedoAlpha.a;
            outSurfaceData.clearCoatSmoothness = 0.0;
            outSurfaceData.clearCoatMask = 0.0;
            outSurfaceData.nightLightData = half4(_GITest, _NightIntensity, _DayIntensity, _ReflectionIntensity);
            outSurfaceData.GIColor = _GIColor;
        }

        ENDHLSL

        Pass
        {
            Tags {"LightMode" = "LightweightForward"}
            Cull[_Cull]
            HLSLPROGRAM
            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local _NORMALMAP //法线
            #pragma shader_feature_local _SURFACE //Surface贴图
            #pragma shader_feature_local_fragment _EMISSION //自发光
            #pragma shader_feature_local _CLIP
            //#pragma shader_feature_local_fragment _ALPHATEST_ON
            //#pragma shader_feature_local_fragment _ALPHAPREMULTIPLY_ON
            //#pragma shader_feature_local_fragment _METALLICSPECGLOSSMAP
            //#pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature_local _PARALLAXMAP //高度图
            //#pragma shader_feature_local _ _DETAIL_MULX2 _DETAIL_SCALED
            #pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF
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
            #include "../ShaderLibrary/SimpleLitForwardPass.hlsl" 
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull[_Cull]

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma multi_compile _ DOTS_INSTANCING_ON

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }



        // This pass it not used during regular rendering, only for lightmap baking.
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
            //#pragma shader_feature_local _ _DETAIL_MULX2 _DETAIL_SCALED

            #pragma shader_feature_local_fragment _SPECGLOSSMAP

            //#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"

            #include "../ShaderLibrary/CustomLitMetaPass.hlsl"

            ENDHLSL
        }
        
    }
}