#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 u_size;
    float u_radius;
    vec4 u_accent;
    float u_hasAccent;
    float u_isHovered;
};

// 精确 2D 胶囊体距离场 (SDF)
float sdRoundedBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + vec2(r);
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

void main() {
    vec2 halfSize = u_size * 0.5;
    vec2 p = (qt_TexCoord0 - 0.5) * u_size;

    // 当前像素距边缘物理距离
    float d = sdRoundedBox(p, halfSize, u_radius);

    // 胶囊外轮廓物理裁切 (1px 亚像素平滑抗锯齿)
    float edgeAlpha = 1.0 - smoothstep(-0.6, 0.4, d);
    if (edgeAlpha <= 0.001) {
        fragColor = vec4(0.0);
        return;
    }

    // =========================================================================
    // 1. 水滴倒角微曲面法线推导 (3.5px 极窄精密外壁)
    // =========================================================================
    float bevelWidth = 3.5;
    float depth = clamp((-d) / bevelWidth, 0.0, 1.0);
    float heightProfile = sin(depth * 1.5707963);

    vec2 eps = vec2(1.0, 0.0);
    vec2 grad = vec2(
        sdRoundedBox(p + eps.xy, halfSize, u_radius) - sdRoundedBox(p - eps.xy, halfSize, u_radius),
        sdRoundedBox(p + eps.yx, halfSize, u_radius) - sdRoundedBox(p - eps.yx, halfSize, u_radius)
    );
    grad = normalize(grad + vec2(0.0001));

    float slope = (1.0 - heightProfile);
    vec3 N = normalize(vec3(grad * slope, heightProfile * 0.95 + 0.05));

    // =========================================================================
    // 2. 🚀 360° 全包裹物理水滴边缘光 (上下左右完整包覆)
    // =========================================================================
    vec3 V = vec3(0.0, 0.0, 1.0);
    
    // 2.1 全周物理菲涅尔反射 (四周边缘视线切角处自然汇聚全反射)
    float fresnel = pow(1.0 - max(0.0, dot(N, V)), 3.0);

    // 2.2 纳米级外壁白光切线 (约 0.8px 宽)
    float outerRim = smoothstep(-1.2, 0.0, d);

    // 2.3 水滴内壁弯月面聚焦环 (在 1.0px ~ 3.0px 处形成水滴玻璃厚度)
    float innerMeniscus = smoothstep(-3.2, -1.0, d) * smoothstep(0.0, -1.0, d);

    // 2.4 全周自适应光强分布：顶面 1.0，两端圆角 0.85，底面 0.72 (四周皆清晰可见，保持立体)
    float ambientRim = mix(1.0, 0.72, smoothstep(0.0, 1.0, qt_TexCoord0.y));

    // 2.5 纯净冷白高定外壁光辉 (完全杜绝任何发黄、杂色)
    vec3 rimLight = vec3(1.0) * (outerRim * 0.38 + innerMeniscus * 0.48 + fresnel * 0.22) * ambientRim;

    // =========================================================================
    // 3. 内部纯净深邃黑曜石 OLED 底色 (内部全黑，零穿帮)
    // =========================================================================
    vec3 baseBlack = vec3(0.02, 0.025, 0.035);
    float baseAlpha = 0.96; // 96% 高度不透明，彻底切断背后文字穿透

    // 动态主题色浸润 (切歌、来电时 360° 边缘温润漫溢)
    vec3 accentGlow = u_accent.rgb * (innerMeniscus * 0.65 + fresnel * 0.35) * u_hasAccent;

    // 悬浮轻微受光微增强
    float hoverBoost = u_isHovered * 0.05;

    // 最终颜色合成 (内部纯黑，四周为冷白晶莹水滴边框)
    vec3 finalRgb = baseBlack + rimLight + accentGlow + vec3(hoverBoost);
    float finalAlpha = clamp(baseAlpha + outerRim * 0.04, 0.0, 1.0);

    float outAlpha = finalAlpha * edgeAlpha * qt_Opacity;

    // 严格预乘 Alpha 输出
    fragColor = vec4(finalRgb * outAlpha, outAlpha);
}