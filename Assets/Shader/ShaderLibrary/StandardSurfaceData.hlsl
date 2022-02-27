#ifndef UNIVERSAL_STANDARD_SURFACE_DATA_INCLUDED//修改头文件
#define UNIVERSAL_STANDARD_SURFACE_DATA_INCLUDED

    // Must match Universal ShaderGraph master node
    struct SurfaceData//需要计算的数据在此添加，这里添加了额外的SSSMap和ShadowData
    {
        half3 albedo;
        half3 specular;
        half  metallic;
        half  smoothness;
        half3 normalTS;
        half3 emission;
        half  occlusion;
        half  alpha;
        half clearCoatSmoothness;
        half clearCoatMask;
    };

#endif
