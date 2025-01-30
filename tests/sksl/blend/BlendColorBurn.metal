#include <metal_stdlib>
#include <simd/simd.h>
#ifdef __clang__
#pragma clang diagnostic ignored "-Wall"
#endif
using namespace metal;
constant const half sk_PrivkGuardedDivideEpsilon = half(false ? 1e-08 : 0.0);
constant const half sk_PrivkMinNormalHalf = 6.10351562e-05h;
struct Uniforms {
    half4 src;
    half4 dst;
};
struct Inputs {
};
struct Outputs {
    half4 sk_FragColor [[color(0)]];
};
half guarded_divide_Qhhh(half n, half d);
half color_burn_component_Qhh2h2(half2 s, half2 d);
half guarded_divide_Qhhh(half n, half d) {
    return n / (d + sk_PrivkGuardedDivideEpsilon);
}
half color_burn_component_Qhh2h2(half2 s, half2 d) {
    half dyTerm = d.y == d.x ? d.y : 0.0h;
    half delta = abs(s.x) >= sk_PrivkMinNormalHalf ? d.y - min(d.y, guarded_divide_Qhhh((d.y - d.x) * s.y, s.x)) : dyTerm;
    return (delta * s.y + s.x * (1.0h - d.y)) + d.x * (1.0h - s.y);
}
fragment Outputs fragmentMain(Inputs _in [[stage_in]], constant Uniforms& _uniforms [[buffer(0)]], bool _frontFacing [[front_facing]], float4 _fragCoord [[position]]) {
    Outputs _out;
    (void)_out;
    _out.sk_FragColor = half4(color_burn_component_Qhh2h2(_uniforms.src.xw, _uniforms.dst.xw), color_burn_component_Qhh2h2(_uniforms.src.yw, _uniforms.dst.yw), color_burn_component_Qhh2h2(_uniforms.src.zw, _uniforms.dst.zw), _uniforms.src.w + (1.0h - _uniforms.src.w) * _uniforms.dst.w);
    return _out;
}
