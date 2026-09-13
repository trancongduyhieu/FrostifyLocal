# LIQUID GLASS & KEO 502 WATER-CLEAR RESIN SPECIFICATION
## Cẩm Nang Kỹ Thuật Toàn Diện Cho AI & Nhà Phát Triển (Full Implementation Guide)

Tài liệu đặc tả kiến trúc kỹ thuật, công thức toán học quang học, thuật toán GLSL Shader Qt 6 RHI và mã nguồn mẫu hoàn chỉnh để tái tạo hiệu ứng **Liquid Glass (Kính Lỏng Quang Học)** kết hợp chất liệu **Keo 502 Trong Suốt & Dẻo (Water-Clear Meniscus Resin)** và **Sóng Lỏng Dẻo Lan Màu (Viscous Flow Wave)** trong các ứng dụng Qt 6 / QML Wayland.

---

## 1. Triết Lý Thiết Kế & Quang Học (Optical Foundations)

### 1.1. Sự Khác Biệt Giữa "Frosted Blur" Thông Thường Và "Liquid Glass"
- **Frosted Blur (Mờ đục thông thường)**: Chỉ áp dụng thuật toán Gaussian/Box blur lên nền phía sau và phủ một lớp màu bán trong suốt (như Acrylic của Windows hay Frosted glass của macOS đời cũ). Kết quả thường phẳng lì, thiếu sức sống và làm mất chi tiết.
- **Liquid Glass (Kính Lỏng Quang Học)**: 
  1. **Khúc xạ quang học (Optical Refraction)**: Giống như một thấu kính lồi bằng chất lỏng đọng trên mặt bàn, kính lỏng bẻ cong (displace) tọa độ UV của các đối tượng phía sau theo đường cong thấu kính lồi.
  2. **Quang sai tán sắc (Chromatic Aberration)**: Khi ánh sáng đi qua rìa mép kính bị bẻ cong lệch pha, 3 kênh màu Red, Green, Blue bị tách nhẹ (RGB splitting) tạo hiệu ứng lăng kính tự nhiên.
  3. **Sức căng bề mặt & Mép cong (Meniscus Curvature)**: Tại đường viền bo góc, chất lỏng co lại tạo độ vồng căng mọng (meniscus), tạo cảm giác trơn dẻo như một giọt keo 502 hay giọt nước.
  4. **Phản quang bề mặt (Glossy Specular Sheen)**: Vệt ánh sáng lướt trên bề mặt cong tạo độ bóng bẩy, chân thực.

### 1.2. Keo 502 Trong Suốt (Water-Clear Cyanoacrylate Resin)
- **Độ trong vắt (Zero Milkiness)**: Tuyệt đối không dùng lớp nền xám chì hoặc đen đục. Kính phải trong veo để người dùng nhìn thấy rõ 100% hình khối và chữ của các thành phần bên dưới đang lướt qua.
- **Tính dẻo trơn bóng**: Độ cong lồi quang học mô phỏng sức căng bề mặt chất lỏng, kết hợp phản xạ bóng bẩy ở mép trên (`topReflect`) và viền ngoài (`rimSheen`).

---

## 2. Kiến Trúc Đệm Nền 3 Tầng (Triple-Tier Composite Backdrop)

### 2.1. Vấn Đề Cốt Tử: Pixel Rỗng Trên Cửa Sổ Bán Trong Suốt
Trong các giao diện Wayland hiện đại (như Niri compositor), cửa sổ thường có độ trong suốt nhìn thấu ra hình nền desktop.
- Nếu dùng `ShaderEffectSource` để chụp trực tiếp nội dung cửa sổ (`sourceItem: windowContent`), thì tại những vùng trống không có card bài hát (ví dụ: đáy danh sách cuộn), giá trị pixel trả về là `(0, 0, 0, 0)` (hoàn toàn rỗng).
- Khi Shader lấy mẫu pixel rỗng này, nó sẽ rơi về màu đen xì hoặc xám chì, biến thanh kính thành một thanh nhựa tối tăm, thô ráp.

### 2.2. Giải Pháp: `glassCompositeBackdrop` Tàng Hình Với Scene Graph
Để khắc phục, chúng ta tạo một container nguồn tổng hợp đặt ngầm bên dưới:
```qml
Item {
    id: glassCompositeBackdrop
    anchors.fill: parent
    z: -999
    opacity: 0.001 // CỰC KỲ QUAN TRỌNG!
```
> [!IMPORTANT]
> **Tại sao phải dùng `opacity: 0.001` thay vì `visible: false`?**
> Nếu đặt `visible: false`, Qt Quick Scene Graph sẽ lập tức bỏ qua không vẽ item đó vào GPU Framebuffer Object (FBO).
> Khi đặt `visible: true, opacity: 0.001, z: -999`, mắt người hoàn toàn không nhìn thấy (giữ trọn cửa sổ trong suốt 100% nhìn ra desktop), nhưng GPU vẫn kích hoạt pipeline vẽ đầy đủ màu sắc vào texture để Shader của LiquidGlass lấy mẫu!

### 2.3. Kiến Trúc 3 Tầng Hòa Trộn Không Giật Cục (Zero-Jolt Continuous Dissolution)
Cấu trúc bên trong `glassCompositeBackdrop`:
1. **Đáy cùng**: Hình nền Desktop (`fallbackWallpaperImg`, luôn hiển thị).
2. **Lớp giữa**: Ảnh bìa bài hát đang phát (`fallbackPlayingImg`), nằm đè lên hình nền với `opacity: (win.currentTrack && win.isPlaying) ? 1.0 : 0.0` kèm `Behavior on opacity { NumberAnimation { duration: 900; easing.type: Easing.InOutQuad } }`.
3. **Lớp làm mờ**: `MultiEffect` làm mờ trực tiếp container chứa cả 2 ảnh trên.
   - *Lợi ích*: Khi nhạc tắt/tạm dừng, ảnh bìa từ từ tan biến (fade out 900ms), để lộ hình nền desktop bên dưới một cách êm ái, KHÔNG BAO GIỜ bị giật cục hay nháy đen.
4. **Lớp đỉnh**: `ShaderEffectSource` chụp `mainContentBackdrop` (chứa các card bài hát cuộn thật). Khi có card, card che phủ lên trên; khi ở vùng trống, để lộ lớp đệm bên dưới.

---

## 3. Toán Học & Giải Thuật GLSL Shader (`liquid_glass.frag`)

Shader được viết theo chuẩn **GLSL 440**, tương thích đa nền tảng Qt 6 RHI (Vulkan, Metal, Direct3D 11/12, OpenGL ES 3.0+).

### 3.1. Inigo Quilez Signed Distance Field (SDF Rounded Box)
Tính khoảng cách giải tích chính xác từ pixel đến mép bo góc hộp:
```glsl
float sdRoundedBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + vec2(r);
    return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}
```

### 3.2. Analytical SDF Gradient (Chống Răng Cưa Góc Bo)
Thay vì dùng xấp xỉ đạo hàm số (`dFdx`/`dFdy`) gây nhiễu góc bo, ta dùng vector pháp tuyến giải tích:
```glsl
vec2 gradSdRoundedRect(vec2 coord, vec2 halfSize, float radius) {
    vec2 cornerCoord = abs(coord) - (halfSize - vec2(radius));
    if (cornerCoord.x >= 0.0 || cornerCoord.y >= 0.0) {
        return sign(coord) * normalize(max(cornerCoord, vec2(1e-5)));
    } else {
        float gradX = step(cornerCoord.y, cornerCoord.x);
        return sign(coord) * vec2(gradX, 1.0 - gradX);
    }
}
```

### 3.3. Đường Cong Circle Map Khúc Xạ Thấu Kính (Kyant0 / SimpMusic Formula)
Mô phỏng mặt cắt hình cung tròn của giọt nước:
```glsl
float circleMap(float x) {
    return 1.0 - sqrt(max(0.0, 1.0 - x * x));
}
```
Độ dịch chuyển UV thấu kính:
```glsl
float t = clamp(1.0 - distInside / refrHeight, 0.0, 1.0);
float dispAmount = -abs(u_displacement > 0.0 ? u_displacement : 16.0);
vec2 sampleOffset = circleMap(t) * dispAmount * grad;
vec2 displacedPixel = pixelPos + sampleOffset;
vec2 uv = clamp((u_sourceOffset + displacedPixel) / u_sourceSize, vec2(0.001), vec2(0.999));
```

### 3.4. Quang Sai Tán Sắc (Chromatic Aberration)
Tách rời 3 kênh màu đỏ, xanh lục, xanh lam lệch pha quang phổ khi ánh sáng bẻ cong:
```glsl
float split = u_aberration * 6.0 * circleMap(t);
vec3 clearRefraction;
clearRefraction.r = textureLod(source, uv + grad * split * pixelStep, 0.5).r;
clearRefraction.g = textureLod(source, uv, 0.5).g;
clearRefraction.b = textureLod(source, uv - grad * split * pixelStep, 0.5).b;
```

### 3.5. Sức Căng Bề Mặt & Phản Quang Giọt Keo 502 (Meniscus Specular)
Tạo độ bóng trơn dẻo lấp lánh như giọt keo lỏng:
```glsl
float rimDistance = clamp(distInside / 8.0, 0.0, 1.0);
float rimSheen = pow(1.0 - rimDistance, 3.5) * 0.16;

float topReflect = smoothstep(halfSize.y, -halfSize.y * 0.3, centeredCoord.y) * 
                   pow(clamp(1.0 - abs(distInside - 2.2) / 2.2, 0.0, 1.0), 2.0) * 0.14;
float keo502Gloss = rimSheen + topReflect;
```

### 3.6. Trích Xuất Màu Tự Động & Sóng Lỏng Dẻo Lan Màu (Viscous Flow Wave)
1. **Trích xuất 2 màu chủ đạo tại runtime từ texture LOD 6.0**:
```glsl
vec3 songColorA = textureLod(source, vec2(0.20, 0.25), 6.0).rgb;
vec3 songColorB = textureLod(source, vec2(0.80, 0.75), 6.0).rgb;
```
2. **3 tầng sóng giao thoa chậm rãi điều khiển bằng thời gian**:
```glsl
float flowTime = u_time * 0.22; // Chu kỳ ~14 giây chậm rãi
float wave1 = sin(pixelPos.x * 0.005 + flowTime * 0.8) * 0.5 + 0.5;
float wave2 = cos(pixelPos.x * 0.003 - pixelPos.y * 0.015 + flowTime * 0.6) * 0.5 + 0.5;
float wave3 = sin((pixelPos.x + pixelPos.y * 0.5) * 0.004 - flowTime * 0.4) * 0.5 + 0.5;

float fluidPattern = smoothstep(0.20, 0.80, wave1 * 0.45 + wave2 * 0.35 + wave3 * 0.20);
vec3 diffusingSongColor = mix(songColorA, songColorB, fluidPattern);

float tintStrength = 0.22 * clamp(u_flowActive, 0.0, 1.0);
vec3 tintedKeo = mix(clearRefraction, diffusingSongColor, tintStrength);
```

---

## 4. Toàn Bộ Mã Nguồn Mẫu Hoàn Chỉnh (Complete Code Templates)

### 4.1. File `assets/shaders/liquid_glass.frag`
```glsl
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

float sdRoundedBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + vec2(r);
    return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}

float circleMap(float x) {
    return 1.0 - sqrt(max(0.0, 1.0 - x * x));
}

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
    
    float d = sdRoundedBox(centeredCoord, halfSize, u_radius);
    float edgeWidth = fwidth(d);
    float mask = 1.0 - smoothstep(-edgeWidth, edgeWidth, d);
    if (mask <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }
    
    float distInside = -d;
    
    float gradRadius = min(u_radius * 1.5, min(halfSize.x, halfSize.y));
    vec2 grad = gradSdRoundedRect(centeredCoord, halfSize, gradRadius);
    vec2 normCentered = normalize(centeredCoord);
    grad = normalize(grad + 0.35 * normCentered);
    
    // Meniscus Displacement (Keo 502)
    float refrHeight = max(18.0, min(u_bevelWidth, halfSize.y * 0.75));
    float t = clamp(1.0 - distInside / refrHeight, 0.0, 1.0);
    float dispAmount = -abs(u_displacement > 0.0 ? u_displacement : 16.0);
    vec2 sampleOffset = circleMap(t) * dispAmount * grad;
    
    vec2 displacedPixel = pixelPos + sampleOffset;
    vec2 uv = clamp((u_sourceOffset + displacedPixel) / u_sourceSize, vec2(0.001), vec2(0.999));
    vec2 pixelStep = 1.0 / u_sourceSize;
    
    // Clear Refraction
    float split = u_aberration * 6.0 * circleMap(t);
    vec3 clearRefraction;
    clearRefraction.r = textureLod(source, uv + grad * split * pixelStep, 0.5).r;
    clearRefraction.g = textureLod(source, uv, 0.5).g;
    clearRefraction.b = textureLod(source, uv - grad * split * pixelStep, 0.5).b;
    
    // Glossy Specular
    float rimDistance = clamp(distInside / 8.0, 0.0, 1.0);
    float rimSheen = pow(1.0 - rimDistance, 3.5) * 0.16;
    float topReflect = smoothstep(halfSize.y, -halfSize.y * 0.3, centeredCoord.y) * 
                       pow(clamp(1.0 - abs(distInside - 2.2) / 2.2, 0.0, 1.0), 2.0) * 0.14;
    float keo502Gloss = rimSheen + topReflect;
    
    // Dual-Tone Song Extraction
    vec3 songColorA = textureLod(source, vec2(0.20, 0.25), 6.0).rgb;
    vec3 songColorB = textureLod(source, vec2(0.80, 0.75), 6.0).rgb;
    float lumA = dot(songColorA, vec3(0.2126, 0.7152, 0.0722));
    songColorA = mix(songColorA, vec3(0.95, 0.98, 1.0), max(0.0, 0.25 - lumA));
    
    // Viscous Flow Wave
    float flowTime = u_time * 0.22;
    float wave1 = sin(pixelPos.x * 0.005 + flowTime * 0.8) * 0.5 + 0.5;
    float wave2 = cos(pixelPos.x * 0.003 - pixelPos.y * 0.015 + flowTime * 0.6) * 0.5 + 0.5;
    float wave3 = sin((pixelPos.x + pixelPos.y * 0.5) * 0.004 - flowTime * 0.4) * 0.5 + 0.5;
    float fluidPattern = smoothstep(0.20, 0.80, wave1 * 0.45 + wave2 * 0.35 + wave3 * 0.20);
    vec3 diffusingSongColor = mix(songColorA, songColorB, fluidPattern);
    
    float tintStrength = 0.22 * clamp(u_flowActive, 0.0, 1.0);
    vec3 tintedKeo = mix(clearRefraction, diffusingSongColor, tintStrength);
    
    float rimProfile = smoothstep(2.5, 0.3, distInside);
    vec3 organicRim = mix(u_tint.rgb * 1.1 + vec3(0.04), diffusingSongColor, 0.45);
    vec3 finalColor = mix(tintedKeo, organicRim, rimProfile * 0.35) + vec3(keo502Gloss);
    finalColor = clamp(finalColor, 0.0, 1.0);
    
    float baseAlpha = clamp(max(u_tint.a, 0.48), 0.48, 0.58);
    float glassAlpha = mask * mix(baseAlpha, 0.62, u_flowActive * 0.25);
    fragColor = vec4(finalColor * glassAlpha, glassAlpha) * qt_Opacity;
}
```

### 4.2. File `components/LiquidGlass.qml`
```qml
import QtQuick
import "."

Item {
    id: root

    property Item backgroundSourceItem: null
    property real radius: 16
    property real displacement: 16.0
    property real aberration: 0.03
    property real bevelWidth: 20.0
    property color tintColor: Qt.rgba(0.12, 0.14, 0.18, 0.45)
    property bool interactive: false

    property bool isFlowActive: false
    property real flowProgress: isFlowActive ? 1.0 : 0.0
    Behavior on flowProgress { NumberAnimation { duration: 950; easing.type: Easing.InOutQuad } }

    property real time: 0.0
    NumberAnimation on time {
        from: 0.0
        to: 100000.0
        duration: 100000000
        loops: Animation.Infinite
        running: true
    }

    default property alias contentData: contentContainer.data

    implicitWidth: 160
    implicitHeight: 48

    readonly property point globalOffset: {
        if (!backgroundSourceItem) return Qt.point(0, 0);
        var _rx = root.x, _ry = root.y, _rw = root.width, _rh = root.height;
        var _px = root.parent ? (root.parent.x + root.parent.y + root.parent.width + root.parent.height) : 0;
        var _sx = backgroundSourceItem.width + backgroundSourceItem.height;
        return root.mapToItem(backgroundSourceItem, 0, 0);
    }

    ShaderEffectSource {
        id: bgSource
        sourceItem: root.backgroundSourceItem
        recursive: false
        live: true
        hideSource: false
        visible: false
        smooth: true
        mipmap: true
    }

    ShaderEffect {
        id: glassShader
        anchors.fill: parent

        property variant source: bgSource
        property vector2d u_resolution: Qt.vector2d(root.width, root.height)
        property real u_radius: root.radius
        property real u_displacement: root.displacement
        property real u_aberration: root.aberration
        property real u_bevelWidth: root.bevelWidth
        property color u_tint: root.tintColor
        property vector2d u_sourceSize: Qt.vector2d(
            root.backgroundSourceItem ? Math.max(1, root.backgroundSourceItem.width) : 1,
            root.backgroundSourceItem ? Math.max(1, root.backgroundSourceItem.height) : 1
        )
        property vector2d u_sourceOffset: Qt.vector2d(root.globalOffset.x, root.globalOffset.y)
        property real u_time: root.time
        property real u_flowActive: root.flowProgress

        fragmentShader: Qt.resolvedUrl("../assets/shaders/liquid_glass.frag.qsb")
        visible: root.backgroundSourceItem !== null
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        visible: root.backgroundSourceItem === null
        color: root.tintColor
    }

    Item {
        id: contentContainer
        anchors.fill: parent
        property alias radius: root.radius
        z: 10
    }
}
```

---

## 5. Quy Trình Biên Dịch Shader Đa Nền Tảng (QSB Command)

Lệnh biên dịch bắt buộc trong môi trường Linux Wayland để không bị crash Qt RHI pipeline:
```bash
/usr/lib/qt6/bin/qsb --glsl "300 es,310 es,320 es,100 es,120,150,330,440" -o assets/shaders/liquid_glass.frag.qsb assets/shaders/liquid_glass.frag
```

---

## 6. Các Bẫy Lỗi Thường Gặp & Cách Khắc Phục (Gotchas)

1. **std140 Uniform Buffer Alignment Trap**:
   Trong uniform buffer `std140`, các biến float và vector được gom theo khối 16-byte. Nếu sau `vec2` (8 byte) đặt một `vec4`, thì 8 byte thừa sẽ bị padding. Luôn kiểm tra tổng kích thước và thứ tự khai báo (ví dụ: `vec2 u_sourceOffset` + `float u_time` + `float u_flowActive` = đúng 16 byte).
2. **QML Layout Positioning Warning**:
   Khi một `Item` nằm bên trong `RowLayout` hoặc `ColumnLayout`, tuyệt đối không gán cứng `width` và `height`. Bắt buộc phải dùng `Layout.preferredWidth` và `Layout.preferredHeight`.
3. **QML Property Alias Radius Warning**:
   Khi các component con bên trong `LiquidGlass` gọi `parent.radius`, nếu `contentContainer` không khai báo `property alias radius: root.radius`, Qt Quick sẽ in ra cảnh báo `Unable to assign [undefined] to double`.
4. **Không Thấy Cập Nhật Khi Chạy Quickshell**:
   Quickshell cache bytecode và shader. Sau khi sửa shader `.frag`, **bắt buộc phải chạy lại lệnh `qsb`** để tạo file `.frag.qsb` mới và khởi động lại tiến trình quickshell.
