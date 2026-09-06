uniform sampler2D u_Tex0;
uniform vec2 u_TextureSize;
uniform float u_XbrEnabled;
uniform float u_XbrSmooth;
varying vec2 v_TexCoord;

const float LUMINANCE_WEIGHT = 1.0;
const float EQUAL_COLOR_TOLERANCE = 15.0 / 255.0;
const float STEEP_DIRECTION_THRESHOLD = 2.2;
const float DOMINANT_DIRECTION_THRESHOLD = 3.6;

float reduce(vec3 color) {
    return dot(color, vec3(65536.0, 256.0, 1.0));
}

float DistYCbCr(vec3 pixA, vec3 pixB) {
    const vec3 w = vec3(0.2627, 0.6780, 0.0593);
    const float scaleB = 0.5 / (1.0 - w.b);
    const float scaleR = 0.5 / (1.0 - w.r);
    vec3 diff = pixA - pixB;
    float Y = dot(diff, w);
    float Cb = scaleB * (diff.b - Y);
    float Cr = scaleR * (diff.r - Y);
    return sqrt(((LUMINANCE_WEIGHT * Y) * (LUMINANCE_WEIGHT * Y)) + (Cb * Cb) + (Cr * Cr));
}

bool IsPixEqual(vec3 pixA, vec3 pixB) {
    return (DistYCbCr(pixA, pixB) < EQUAL_COLOR_TOLERANCE);
}

vec4 calculatePixel() {
    vec4 Ec = texture2D(u_Tex0, v_TexCoord);
    
    float xbrEnabled = (u_XbrEnabled > 0.0) ? u_XbrEnabled : 2.0;
    if (xbrEnabled < 0.5)
        return vec4(Ec.rgb, 1.0);

    vec2 texSize = u_TextureSize;
    if (texSize.x <= 0.0 || texSize.y <= 0.0) {
        texSize = vec2(textureSize(u_Tex0, 0));
    }
    if (texSize.x <= 0.0 || texSize.y <= 0.0) {
        texSize = vec2(1024.0, 768.0);
    }

    vec2 ps = 1.0 / texSize;
    float dx = ps.x;
    float dy = ps.y;
    vec2 f = fract(v_TexCoord * texSize);

    vec3 s0 = Ec.rgb;
    vec3 s1 = texture2D(u_Tex0, v_TexCoord + vec2(dx, 0.0)).rgb;
    vec3 s2 = texture2D(u_Tex0, v_TexCoord + vec2(dx, dy)).rgb;
    vec3 s3 = texture2D(u_Tex0, v_TexCoord + vec2(0.0, dy)).rgb;
    vec3 s4 = texture2D(u_Tex0, v_TexCoord + vec2(-dx, dy)).rgb;
    vec3 s5 = texture2D(u_Tex0, v_TexCoord + vec2(-dx, 0.0)).rgb;
    vec3 s6 = texture2D(u_Tex0, v_TexCoord + vec2(-dx, -dy)).rgb;
    vec3 s7 = texture2D(u_Tex0, v_TexCoord + vec2(0.0, -dy)).rgb;
    vec3 s8 = texture2D(u_Tex0, v_TexCoord + vec2(dx, -dy)).rgb;

    if (xbrEnabled < 1.5) {
        const vec3 w = vec3(0.2627, 0.6780, 0.0593);
        float la = dot(s6, w), lb = dot(s7, w), lc = dot(s8, w), ld = dot(s5, w), le = dot(s0, w), lf = dot(s1, w), lg = dot(s4, w), lh = dot(s3, w), li = dot(s2, w);
        vec3 res = s0;
        float w1, w2;
        if (f.x >= 0.5 && f.y >= 0.5) {
            w1 = abs(le - lc) + abs(le - lg) + 4.0 * abs(lh - lf);
            w2 = abs(lf - lb) + abs(lh - ld) + 4.0 * abs(le - li);
            if (w1 < w2) res = mix(s0, abs(le - lf) <= abs(le - lh) ? s1 : s3, 0.5);
        } else if (f.x >= 0.5) {
            w1 = abs(le - la) + abs(le - li) + 4.0 * abs(lb - lf);
            w2 = abs(lb - ld) + abs(lf - lh) + 4.0 * abs(le - lc);
            if (w1 < w2) res = mix(s0, abs(le - lb) <= abs(le - lf) ? s7 : s1, 0.5);
        } else if (f.y >= 0.5) {
            w1 = abs(le - la) + abs(le - li) + 4.0 * abs(lh - ld);
            w2 = abs(ld - lb) + abs(lh - lf) + 4.0 * abs(le - lg);
            if (w1 < w2) res = mix(s0, abs(le - ld) <= abs(le - lh) ? s5 : s3, 0.5);
        } else {
            w1 = abs(le - lc) + abs(le - lg) + 4.0 * abs(lb - ld);
            w2 = abs(lb - lf) + abs(ld - lh) + 4.0 * abs(le - la);
            if (w1 < w2) res = mix(s0, abs(le - lb) <= abs(le - ld) ? s7 : s5, 0.5);
        }
        if (u_XbrSmooth >= 0.0) {
            vec2 t = smoothstep(vec2(0.0), vec2(1.0), f);
            res = mix(res, mix(mix(s5, s1, t.x), mix(s7, s3, t.y), 0.5), 0.25);
        }
        return vec4(res, 1.0);
    }

    // 4xBRZ - using individual variables for ps_3_0 compatibility
    float v0 = reduce(s0); float v1 = reduce(s1); float v2 = reduce(s2);
    float v3 = reduce(s3); float v4 = reduce(s4); float v5 = reduce(s5);
    float v6 = reduce(s6); float v7 = reduce(s7); float v8 = reduce(s8);

    vec4 blendResult = vec4(0.0);

    // Corner (1, 1)
    if (!((v0 == v1 && v3 == v2) || (v0 == v3 && v1 == v2))) {
        float dist_03_01 = DistYCbCr(s4, s0) + DistYCbCr(s0, s8) + DistYCbCr(s3, s2) + DistYCbCr(s2, s1) + (4.0 * DistYCbCr(s3, s1));
        float dist_00_02 = DistYCbCr(s5, s3) + DistYCbCr(s3, s2) + DistYCbCr(s7, s1) + DistYCbCr(s1, s2) + (4.0 * DistYCbCr(s0, s2));
        bool dominantGradient = (DOMINANT_DIRECTION_THRESHOLD * dist_03_01) < dist_00_02;
        blendResult.z = ((dist_03_01 < dist_00_02) && (v0 != v1) && (v0 != v3)) ? ((dominantGradient) ? 2.0 : 1.0) : 0.0;
    }
    // Corner (0, 1)
    if (!((v5 == v0 && v4 == v3) || (v5 == v4 && v0 == v3))) {
        float dist_04_00 = DistYCbCr(s4, s5) + DistYCbCr(s5, s7) + DistYCbCr(s4, s3) + DistYCbCr(s3, s1) + (4.0 * DistYCbCr(s4, s0));
        float dist_05_03 = DistYCbCr(s5, s4) + DistYCbCr(s4, s3) + DistYCbCr(s6, s0) + DistYCbCr(s0, s2) + (4.0 * DistYCbCr(s5, s3));
        bool dominantGradient = (DOMINANT_DIRECTION_THRESHOLD * dist_05_03) < dist_04_00;
        blendResult.w = ((dist_04_00 > dist_05_03) && (v0 != v5) && (v0 != v3)) ? ((dominantGradient) ? 2.0 : 1.0) : 0.0;
    }
    // Corner (1, 0)
    if (!((v7 == v8 && v0 == v1) || (v7 == v0 && v8 == v1))) {
        float dist_00_08 = DistYCbCr(s5, s7) + DistYCbCr(s7, s8) + DistYCbCr(s3, s1) + DistYCbCr(s1, s8) + (4.0 * DistYCbCr(s0, s8));
        float dist_07_01 = DistYCbCr(s6, s0) + DistYCbCr(s0, s2) + DistYCbCr(s7, s8) + DistYCbCr(s8, s1) + (4.0 * DistYCbCr(s7, s1));
        bool dominantGradient = (DOMINANT_DIRECTION_THRESHOLD * dist_07_01) < dist_00_08;
        blendResult.y = ((dist_00_08 > dist_07_01) && (v0 != v7) && (v0 != v1)) ? ((dominantGradient) ? 2.0 : 1.0) : 0.0;
    }
    // Corner (0, 0)
    if (!((v6 == v7 && v5 == v0) || (v6 == v5 && v7 == v0))) {
        float dist_05_07 = DistYCbCr(s5, s6) + DistYCbCr(s6, s7) + DistYCbCr(s4, s0) + DistYCbCr(s0, s8) + (4.0 * DistYCbCr(s5, s7));
        float dist_06_00 = DistYCbCr(s6, s5) + DistYCbCr(s5, s3) + DistYCbCr(s6, s7) + DistYCbCr(s7, s1) + (4.0 * DistYCbCr(s6, s0));
        bool dominantGradient = (DOMINANT_DIRECTION_THRESHOLD * dist_05_07) < dist_06_00;
        blendResult.x = ((dist_05_07 < dist_06_00) && (v0 != v5) && (v0 != v7)) ? ((dominantGradient) ? 2.0 : 1.0) : 0.0;
    }

    vec3 d0=s0; vec3 d1=s0; vec3 d2=s0; vec3 d3=s0;
    vec3 d4=s0; vec3 d5=s0; vec3 d6=s0; vec3 d7=s0;
    vec3 d8=s0; vec3 d9=s0; vec3 d10=s0; vec3 d11=s0;
    vec3 d12=s0; vec3 d13=s0; vec3 d14=s0; vec3 d15=s0;

    if (blendResult.x > 0.5 || blendResult.y > 0.5 || blendResult.z > 0.5 || blendResult.w > 0.5) {
        float dist_01_04 = DistYCbCr(s1, s4);
        float dist_03_08 = DistYCbCr(s3, s8);
        bool haveShallowLine = (STEEP_DIRECTION_THRESHOLD * dist_01_04 <= dist_03_08) && (v0 != v4) && (v5 != v4);
        bool haveSteepLine   = (STEEP_DIRECTION_THRESHOLD * dist_03_08 <= dist_01_04) && (v0 != v8) && (v7 != v8);
        bool needBlend = (blendResult.z > 0.5);
        bool doLineBlend = (blendResult.z >= 1.5 ||
                           ((blendResult.y > 0.5 && !IsPixEqual(s0, s4)) ||
                             (blendResult.w > 0.5 && !IsPixEqual(s0, s8)) ||
                             (IsPixEqual(s4, s3) && IsPixEqual(s3, s2) && IsPixEqual(s2, s1) && IsPixEqual(s1, s8) && !IsPixEqual(s0, s2))) == false);

        vec3 blendPix = (DistYCbCr(s0, s1) <= DistYCbCr(s0, s3)) ? s1 : s3;
        d2  = mix(d2,  blendPix, (needBlend && doLineBlend) ? ((haveShallowLine) ? ((haveSteepLine) ? 1.0/3.0 : 0.25) : ((haveSteepLine) ? 0.25 : 0.00)) : 0.00);
        d9  = mix(d9,  blendPix, (needBlend && doLineBlend && haveSteepLine) ? 0.25 : 0.00);
        d10 = mix(d10, blendPix, (needBlend && doLineBlend && haveSteepLine) ? 0.75 : 0.00);
        d11 = mix(d11, blendPix, (needBlend) ? ((doLineBlend) ? ((haveSteepLine) ? 1.00 : ((haveShallowLine) ? 0.75 : 0.50)) : 0.08677704501) : 0.00);
        d12 = mix(d12, blendPix, (needBlend) ? ((doLineBlend) ? 1.00 : 0.6848532563) : 0.00);
        d13 = mix(d13, blendPix, (needBlend) ? ((doLineBlend) ? ((haveShallowLine) ? 1.00 : ((haveSteepLine) ? 0.75 : 0.50)) : 0.08677704501) : 0.00);
        d14 = mix(d14, blendPix, (needBlend && doLineBlend && haveShallowLine) ? 0.75 : 0.00);
        d15 = mix(d15, blendPix, (needBlend && doLineBlend && haveShallowLine) ? 0.25 : 0.00);

        dist_01_04 = DistYCbCr(s7, s2);
        dist_03_08 = DistYCbCr(s1, s6);
        haveShallowLine = (STEEP_DIRECTION_THRESHOLD * dist_01_04 <= dist_03_08) && (v0 != v2) && (v3 != v2);
        haveSteepLine   = (STEEP_DIRECTION_THRESHOLD * dist_03_08 <= dist_01_04) && (v0 != v6) && (v5 != v6);
        needBlend = (blendResult.y > 0.5);
        doLineBlend = (blendResult.y >= 1.5 ||
                      !((blendResult.x > 0.5 && !IsPixEqual(s0, s2)) ||
                        (blendResult.z > 0.5 && !IsPixEqual(s0, s6)) ||
                        (IsPixEqual(s2, s1) && IsPixEqual(s1, s8) && IsPixEqual(s8, s7) && IsPixEqual(s7, s6) && !IsPixEqual(s0, s8))));

        blendPix = (DistYCbCr(s0, s7) <= DistYCbCr(s0, s1)) ? s7 : s1;
        d1  = mix(d1,  blendPix, (needBlend && doLineBlend) ? ((haveShallowLine) ? ((haveSteepLine) ? 1.0/3.0 : 0.25) : ((haveSteepLine) ? 0.25 : 0.00)) : 0.00);
        d6  = mix(d6,  blendPix, (needBlend && doLineBlend && haveSteepLine) ? 0.25 : 0.00);
        d7  = mix(d7,  blendPix, (needBlend && doLineBlend && haveSteepLine) ? 0.75 : 0.00);
        d8  = mix(d8,  blendPix, (needBlend) ? ((doLineBlend) ? ((haveSteepLine) ? 1.00 : ((haveShallowLine) ? 0.75 : 0.50)) : 0.08677704501) : 0.00);
        d9  = mix(d9,  blendPix, (needBlend) ? ((doLineBlend) ? 1.00 : 0.6848532563) : 0.00);
        d10 = mix(d10, blendPix, (needBlend) ? ((doLineBlend) ? ((haveShallowLine) ? 1.00 : ((haveSteepLine) ? 0.75 : 0.50)) : 0.08677704501) : 0.00);
        d11 = mix(d11, blendPix, (needBlend && doLineBlend && haveShallowLine) ? 0.75 : 0.00);
        d12 = mix(d12, blendPix, (needBlend && doLineBlend && haveShallowLine) ? 0.25 : 0.00);

        dist_01_04 = DistYCbCr(s5, s8);
        dist_03_08 = DistYCbCr(s7, s4);
        haveShallowLine = (STEEP_DIRECTION_THRESHOLD * dist_01_04 <= dist_03_08) && (v0 != v8) && (v1 != v8);
        haveSteepLine   = (STEEP_DIRECTION_THRESHOLD * dist_03_08 <= dist_01_04) && (v0 != v4) && (v3 != v4);
        needBlend = (blendResult.x > 0.5);
        doLineBlend = (blendResult.x >= 1.5 ||
                      !((blendResult.w > 0.5 && !IsPixEqual(s0, s8)) ||
                        (blendResult.y > 0.5 && !IsPixEqual(s0, s4)) ||
                        (IsPixEqual(s8, s7) && IsPixEqual(s7, s6) && IsPixEqual(s6, s5) && IsPixEqual(s5, s4) && !IsPixEqual(s0, s6))));

        blendPix = (DistYCbCr(s0, s5) <= DistYCbCr(s0, s7)) ? s5 : s7;
        d0  = mix(d0,  blendPix, (needBlend && doLineBlend) ? ((haveShallowLine) ? ((haveSteepLine) ? 1.0/3.0 : 0.25) : ((haveSteepLine) ? 0.25 : 0.00)) : 0.00);
        d15 = mix(d15, blendPix, (needBlend && doLineBlend && haveSteepLine) ? 0.25 : 0.00);
        d4  = mix(d4,  blendPix, (needBlend && doLineBlend && haveSteepLine) ? 0.75 : 0.00);
        d5  = mix(d5,  blendPix, (needBlend) ? ((doLineBlend) ? ((haveSteepLine) ? 1.00 : ((haveShallowLine) ? 0.75 : 0.50)) : 0.08677704501) : 0.00);
        d6  = mix(d6,  blendPix, (needBlend) ? ((doLineBlend) ? 1.00 : 0.6848532563) : 0.00);
        d7  = mix(d7,  blendPix, (needBlend) ? ((doLineBlend) ? ((haveShallowLine) ? 1.00 : ((haveSteepLine) ? 0.75 : 0.50)) : 0.08677704501) : 0.00);
        d8  = mix(d8,  blendPix, (needBlend && doLineBlend && haveShallowLine) ? 0.75 : 0.00);
        d9  = mix(d9,  blendPix, (needBlend && doLineBlend && haveShallowLine) ? 0.25 : 0.00);

        dist_01_04 = DistYCbCr(s3, s6);
        dist_03_08 = DistYCbCr(s5, s2);
        haveShallowLine = (STEEP_DIRECTION_THRESHOLD * dist_01_04 <= dist_03_08) && (v0 != v6) && (v7 != v6);
        haveSteepLine   = (STEEP_DIRECTION_THRESHOLD * dist_03_08 <= dist_01_04) && (v0 != v2) && (v1 != v2);
        needBlend = (blendResult.w > 0.5);
        doLineBlend = (blendResult.w >= 1.5 ||
                      !((blendResult.z > 0.5 && !IsPixEqual(s0, s6)) ||
                        (blendResult.x > 0.5 && !IsPixEqual(s0, s2)) ||
                        (IsPixEqual(s6, s5) && IsPixEqual(s5, s4) && IsPixEqual(s4, s3) && IsPixEqual(s3, s2) && !IsPixEqual(s0, s4))));

        blendPix = (DistYCbCr(s0, s3) <= DistYCbCr(s0, s5)) ? s3 : s5;
        d3  = mix(d3,  blendPix, (needBlend && doLineBlend) ? ((haveShallowLine) ? ((haveSteepLine) ? 1.0/3.0 : 0.25) : ((haveSteepLine) ? 0.25 : 0.00)) : 0.00);
        d12 = mix(d12, blendPix, (needBlend && doLineBlend && haveSteepLine) ? 0.25 : 0.00);
        d13 = mix(d13, blendPix, (needBlend && doLineBlend && haveSteepLine) ? 0.75 : 0.00);
        d14 = mix(d14, blendPix, (needBlend) ? ((doLineBlend) ? ((haveSteepLine) ? 1.00 : ((haveShallowLine) ? 0.75 : 0.50)) : 0.08677704501) : 0.00);
        d15 = mix(d15, blendPix, (needBlend) ? ((doLineBlend) ? 1.00 : 0.6848532563) : 0.00);
        d4  = mix(d4,  blendPix, (needBlend) ? ((doLineBlend) ? ((haveShallowLine) ? 1.00 : ((haveSteepLine) ? 0.75 : 0.50)) : 0.08677704501) : 0.00);
        d5  = mix(d5,  blendPix, (needBlend && doLineBlend && haveShallowLine) ? 0.75 : 0.00);
        d6  = mix(d6,  blendPix, (needBlend && doLineBlend && haveShallowLine) ? 0.25 : 0.00);
    }

    vec3 res = mix(mix(mix(mix(d6, d7, step(0.25, f.x)), mix(d8, d9, step(0.75, f.x)), step(0.50, f.x)),
                       mix(mix(d5, d0, step(0.25, f.x)), mix(d1, d10, step(0.75, f.x)), step(0.50, f.x)), step(0.25, f.y)),
                   mix(mix(mix(d4, d3, step(0.25, f.x)), mix(d2, d11, step(0.75, f.x)), step(0.50, f.x)),
                       mix(mix(d15, d14, step(0.25, f.x)), mix(d13, d12, step(0.75, f.x)), step(0.50, f.x)), step(0.75, f.y)),
                       step(0.50, f.y));

    if (u_XbrSmooth >= 0.0) {
        vec2 t = smoothstep(vec2(0.0), vec2(1.0), f);
        vec3 hMix = mix(s5, s1, t.x);
        vec3 vMix = mix(s7, s3, t.y);
        vec3 bilinear = mix(hMix, vMix, 0.5);
        res = mix(res, bilinear, 0.25);
    }

    return vec4(res, 1.0);
}

void main() {
    gl_FragColor = calculatePixel();
}