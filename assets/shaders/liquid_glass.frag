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
    float u_time;         // Time in seconds for viscous wave flow
    float u_flowActive;   // 1.0 when music is playing, 0.0 when stopped
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
    
    // =========================================================================
    // 1. Keo 502 Surface Tension Meniscus Displacement
    // Độ bẻ cong quang học dạng giọt keo lỏng căng tròn bề mặt
    // =========================================================================
    float refrHeight = max(18.0, min(u_bevelWidth, halfSize.y * 0.75));
    float t = clamp(1.0 - distInside / refrHeight, 0.0, 1.0);
    float dispAmount = -abs(u_displacement > 0.0 ? u_displacement : 16.0);
    vec2 sampleOffset = circleMap(t) * dispAmount * grad;
    
    vec2 displacedPixel = pixelPos + sampleOffset;
    vec2 uv = clamp((u_sourceOffset + displacedPixel) / u_sourceSize, vec2(0.001), vec2(0.999));
    vec2 pixelStep = 1.0 / u_sourceSize;
    
    // =========================================================================
    // 2. Water-Clear Refraction (Độ trong vắt như keo 502 với tán sắc nhẹ)
    // =========================================================================
    float split = u_aberration * 6.0 * circleMap(t);
    vec3 clearRefraction;
    clearRefraction.r = textureLod(source, uv + grad * split * pixelStep, 0.5).r;
    clearRefraction.g = textureLod(source, uv, 0.5).g;
    clearRefraction.b = textureLod(source, uv - grad * split * pixelStep, 0.5).b;
    
    // =========================================================================
    // 3. Keo 502 Glossy Meniscus Specular (Sức căng bề mặt & độ bóng trơn dẻo)
    // =========================================================================
    float rimDistance = clamp(distInside / 8.0, 0.0, 1.0);
    float rimSheen = pow(1.0 - rimDistance, 3.5) * 0.16;
    
    // Phản xạ ánh sáng mép trên (Top Light Specular Reflection)
    float topReflect = smoothstep(halfSize.y, -halfSize.y * 0.3, centeredCoord.y) * 
                       pow(clamp(1.0 - abs(distInside - 2.2) / 2.2, 0.0, 1.0), 2.0) * 0.14;
    float keo502Gloss = rimSheen + topReflect;
    
    // =========================================================================
    // 4. Dynamic Dual-Tone Song Extraction (Trích xuất 2 màu của bài hát)
    // =========================================================================
    vec3 songColorA = textureLod(source, vec2(0.20, 0.25), 6.0).rgb;
    vec3 songColorB = textureLod(source, vec2(0.80, 0.75), 6.0).rgb;
    
    float lumA = dot(songColorA, vec3(0.2126, 0.7152, 0.0722));
    songColorA = mix(songColorA, vec3(0.95, 0.98, 1.0), max(0.0, 0.25 - lumA));
    
    // =========================================================================
    // 5. Viscous Flow Wave Diffusion (Sóng lỏng dẻo lan màu từ từ)
    // =========================================================================
    float flowTime = u_time * 0.22;
    
    // 3 lớp sóng chất lỏng dẻo giao thoa lượn sóng
    float wave1 = sin(pixelPos.x * 0.005 + flowTime * 0.8) * 0.5 + 0.5;
    float wave2 = cos(pixelPos.x * 0.003 - pixelPos.y * 0.015 + flowTime * 0.6) * 0.5 + 0.5;
    float wave3 = sin((pixelPos.x + pixelPos.y * 0.5) * 0.004 - flowTime * 0.4) * 0.5 + 0.5;
    
    float fluidPattern = smoothstep(0.20, 0.80, wave1 * 0.45 + wave2 * 0.35 + wave3 * 0.20);
    
    // Hòa sắc giữa 2 gam màu bài hát (ví dụ xanh biển và trắng)
    vec3 diffusingSongColor = mix(songColorA, songColorB, fluidPattern);
    
    // Lan màu nhẹ nhàng (subtle ambient tint ~22%), giữ trọn vẹn độ trong veo của keo
    float tintStrength = 0.22 * clamp(u_flowActive, 0.0, 1.0);
    vec3 tintedKeo = mix(clearRefraction, diffusingSongColor, tintStrength);
    
    // =========================================================================
    // 6. Final Composite & Water-Clear Transparency
    // =========================================================================
    float rimProfile = smoothstep(2.5, 0.3, distInside);
    vec3 organicRim = mix(u_tint.rgb * 1.1 + vec3(0.04), diffusingSongColor, 0.45);
    vec3 finalColor = mix(tintedKeo, organicRim, rimProfile * 0.35) + vec3(keo502Gloss);
    finalColor = clamp(finalColor, 0.0, 1.0);
    
    // Độ trong suốt keo 502 (Water-Clear Transparency ~ 0.48 - 0.58)
    // Không bao giờ bị đục xám hay đen ngầu, nhìn thấu các card bên dưới
    float baseAlpha = clamp(max(u_tint.a, 0.48), 0.48, 0.58);
    float glassAlpha = mask * mix(baseAlpha, 0.62, u_flowActive * 0.25);
    fragColor = vec4(finalColor * glassAlpha, glassAlpha) * qt_Opacity;
}

