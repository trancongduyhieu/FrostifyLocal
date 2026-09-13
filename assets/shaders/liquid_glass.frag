#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 u_resolution;    // Size of the glass item (width, height in pixels)
    float u_radius;       // Corner radius in pixels
    float u_displacement; // Refraction strength (pixel offset in source texture)
    float u_aberration;   // Chromatic dispersion factor (0.0 to 1.0)
    float u_bevelWidth;   // Width of the curved bevel edge (pixels)
    vec4 u_tint;          // Tint color and alpha
    vec2 u_sourceSize;    // Size of the background texture in pixels
    vec2 u_sourceOffset;  // Global pixel offset of this item inside source texture
};

layout(binding = 1) uniform sampler2D source;

// Inigo Quilez 2D Rounded Box SDF
float sdRoundedBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + vec2(r);
    return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}

// Circle map curve from AndroidLiquidGlass / Kyant0 (SimpMusic)
float circleMap(float x) {
    return 1.0 - sqrt(max(0.0, 1.0 - x * x));
}

// Analytical Gradient of Rounded Box SDF (Zero numerical jitter, perfectly uniform at corners)
vec2 gradSdRoundedRect(vec2 coord, vec2 halfSize, float radius) {
    vec2 cornerCoord = abs(coord) - (halfSize - vec2(radius));
    if (cornerCoord.x >= 0.0 || cornerCoord.y >= 0.0) {
        return sign(coord) * normalize(max(cornerCoord, vec2(1e-5)));
    } else {
        float gradX = step(cornerCoord.y, cornerCoord.x);
        return sign(coord) * vec2(gradX, 1.0 - gradX);
    }
}

void main() {
    vec2 pixelPos = qt_TexCoord0 * u_resolution;
    vec2 center = u_resolution * 0.5;
    vec2 halfSize = u_resolution * 0.5;
    vec2 centeredCoord = pixelPos - center;
    
    // Distance from current pixel to rounded box border
    float d = sdRoundedBox(centeredCoord, halfSize, u_radius);
    
    // Anti-aliased outer silhouette mask
    float edgeWidth = fwidth(d);
    float mask = 1.0 - smoothstep(-edgeWidth, edgeWidth, d);
    if (mask <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }
    
    float distInside = -d;
    
    // Bevel normal and curvature
    float gradRadius = min(u_radius * 1.5, min(halfSize.x, halfSize.y));
    vec2 grad = gradSdRoundedRect(centeredCoord, halfSize, gradRadius);
    vec2 normCentered = normalize(centeredCoord);
    grad = normalize(grad + 0.35 * normCentered);
    
    // SimpMusic liquid lens displacement:
    // Pulls / magnifies underlying artwork and spreads colors through the gel
    float refrHeight = max(18.0, min(u_bevelWidth, halfSize.y * 0.75));
    float t = clamp(1.0 - distInside / refrHeight, 0.0, 1.0);
    float dispAmount = -abs(u_displacement > 0.0 ? u_displacement : 18.0);
    vec2 sampleOffset = circleMap(t) * dispAmount * grad;
    
    vec2 displacedPixel = pixelPos + sampleOffset;
    vec2 uv = clamp((u_sourceOffset + displacedPixel) / u_sourceSize, vec2(0.001), vec2(0.999));
    vec2 pixelStep = 1.0 / u_sourceSize;
    
    // =========================================================================
    // Two-tier Viscous Liquid Gel Multi-Tap Diffusion ("Keo nước" lan tỏa màu)
    // Wide bloom (LOD 3.8 + 20px taps) + Form preservation (LOD 2.0 + 8px taps)
    // =========================================================================
    float rWide = 20.0;
    float rMed  = 8.0;
    
    vec2 w1 = vec2( rWide,  0.0) * pixelStep;
    vec2 w2 = vec2(-rWide,  0.0) * pixelStep;
    vec2 w3 = vec2( 0.0,  rWide) * pixelStep;
    vec2 w4 = vec2( 0.0, -rWide) * pixelStep;
    vec2 w5 = vec2( rWide * 0.707,  rWide * 0.707) * pixelStep;
    vec2 w6 = vec2(-rWide * 0.707, -rWide * 0.707) * pixelStep;
    vec2 w7 = vec2( rWide * 0.707, -rWide * 0.707) * pixelStep;
    vec2 w8 = vec2(-rWide * 0.707,  rWide * 0.707) * pixelStep;

    vec3 s0_wide = textureLod(source, uv, 3.8).rgb;
    vec3 s1_wide = textureLod(source, uv+w1, 3.8).rgb;
    vec3 s2_wide = textureLod(source, uv+w2, 3.8).rgb;
    vec3 s3_wide = textureLod(source, uv+w3, 3.8).rgb;
    vec3 s4_wide = textureLod(source, uv+w4, 3.8).rgb;
    vec3 s5_wide = textureLod(source, uv+w5, 3.8).rgb;
    vec3 s6_wide = textureLod(source, uv+w6, 3.8).rgb;
    vec3 s7_wide = textureLod(source, uv+w7, 3.8).rgb;
    vec3 s8_wide = textureLod(source, uv+w8, 3.8).rgb;
    vec3 wideBloom = s0_wide * 0.28 + (s1_wide + s2_wide + s3_wide + s4_wide) * 0.11 + (s5_wide + s6_wide + s7_wide + s8_wide) * 0.07;

    vec2 m1 = vec2( rMed,  0.0) * pixelStep;
    vec2 m2 = vec2(-rMed,  0.0) * pixelStep;
    vec2 m3 = vec2( 0.0,  rMed) * pixelStep;
    vec2 m4 = vec2( 0.0, -rMed) * pixelStep;
    vec3 med0 = textureLod(source, uv, 2.0).rgb;
    vec3 med1 = textureLod(source, uv+m1, 2.0).rgb;
    vec3 med2 = textureLod(source, uv+m2, 2.0).rgb;
    vec3 med3 = textureLod(source, uv+m3, 2.0).rgb;
    vec3 med4 = textureLod(source, uv+m4, 2.0).rgb;
    vec3 medBloom = med0 * 0.40 + (med1 + med2 + med3 + med4) * 0.15;

    // Liquid gel composite: 65% wide atmospheric glow + 35% defined shape
    vec3 diffuseColor = wideBloom * 0.65 + medBloom * 0.35;
    
    // SimpMusic Vibrancy & ColorControls: Saturation 1.6x, subtle brightness lift
    float lum = dot(diffuseColor, vec3(0.2126, 0.7152, 0.0722));
    vec3 vibrantColor = clamp(mix(vec3(lum), diffuseColor, 1.60) + vec3(0.03 * lum), 0.0, 1.0);
    
    // =========================================================================
    // Pure Chromatic Rim Glow (Viền phát sáng đúng màu lem, KHÔNG bị trắng)
    // =========================================================================
    float rimProfile = smoothstep(2.5, 0.3, distInside);
    
    // Lấy mẫu trực tiếp tại mép viền để nắm bắt màu sắc avatar đang tiếp xúc
    vec2 directUV = clamp((u_sourceOffset + pixelPos) / u_sourceSize, vec2(0.001), vec2(0.999));
    vec3 directEdgeCol = textureLod(source, directUV, 2.2).rgb;
    
    // Màu sắc đại diện cho vùng mép kính (kết hợp màu khuếch tán và màu trực tiếp)
    vec3 rimSourceCol = mix(vibrantColor, directEdgeCol, 0.45);
    
    // Đo đạc độ bão hòa màu sắc (Saturation) để lọc sạch hoàn toàn chữ màu trắng & nền đen
    float maxC = max(rimSourceCol.r, max(rimSourceCol.g, rimSourceCol.b));
    float minC = min(rimSourceCol.r, min(rimSourceCol.g, rimSourceCol.b));
    float chromaSat = maxC > 0.01 ? (maxC - minC) / maxC : 0.0;
    float chromaLum = dot(rimSourceCol, vec3(0.2126, 0.7152, 0.0722));
    
    // CHỈ PHÁT SÁNG KHI LÀ MÀU THỰC SỰ (chromaSat > 0.08 và có ánh sáng):
    // Tuyệt đối loại trừ màu trắng (chromaSat ~ 0.0) và nền đen (chromaLum ~ 0.0)
    float isChromatic = smoothstep(0.07, 0.18, chromaSat) * smoothstep(0.04, 0.12, chromaLum);
    
    // Đẩy bão hòa màu sắc lên cực đại để viền phát sáng rực rỡ đúng màu tím/hồng/vàng/xanh
    vec3 pureHue = clamp(mix(vec3(chromaLum), rimSourceCol, 2.5), 0.0, 1.0);
    vec3 glowingRim = clamp(pureHue * 1.65, 0.0, 1.0);
    
    // =========================================================================
    // SimpMusic Adaptive Darken: 12% on black background, up to 48% on white
    // =========================================================================
    float darken = mix(0.12, 0.48, clamp((lum - 0.08) / 0.42, 0.0, 1.0));
    vec3 baseGlass = mix(vibrantColor, u_tint.rgb, darken);
    
    // Phủ viền phát sáng đúng màu đã lem (chỉ khi có màu sắc thực thụ, không phát sáng trắng)
    vec3 finalColor = mix(baseGlass, glowingRim, rimProfile * isChromatic * 0.95);
    finalColor = clamp(finalColor, 0.0, 1.0);
    
    // CRITICAL: Premultiplied alpha for Qt Quick RHI rendering pipeline
    // Guarantees ZERO white corner fringe or halo on dark backgrounds
    fragColor = vec4(finalColor * mask, mask) * qt_Opacity;
}
