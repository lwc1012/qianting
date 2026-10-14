void MAIN() {
    vec3 viewDir = normalize(VIEW_VECTOR);
    vec3 normal = normalize(NORMAL);
    float fresnel = dot(viewDir, normal);
    fresnel = clamp(1.0 - fresnel, 0.0, 1.0);
    fresnel = pow(fresnel, 2.0);

    vec3 shallowColor = vec3(0.0, 0.5, 0.8);
    vec3 deepColor = vec3(0.01, 0.12, 0.25);
    vec3 finalColor = mix(shallowColor, deepColor, fresnel);

    float distToOrigin = length(VAR_WORLD_POSITION.xz);

    // fadeStart: 距离中心多少单位内完全不透明 (实体海面)
    // fadeEnd: 距离中心多少单位外完全变透明 (融入深海黑背景)
    float fadeStart = 400.0;
    float fadeEnd = 800.0;

    float edgeFade = 1.0 - smoothstep(fadeStart, fadeEnd, distToOrigin);
    float finalAlpha = 0.70 * edgeFade;
    BASE_COLOR = vec4(finalColor, finalAlpha);
    ROUGHNESS = 0.05;
    METALNESS = 0.9;
}
