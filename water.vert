void MAIN() {
    float t = uTime * 3.0;
    float wave1 = sin(VERTEX.x * 0.15 + t) * 1.5;
    float wave2 = cos(VERTEX.z * 0.12 + t * 0.8) * 1.2;
    float wave3 = sin((VERTEX.x + VERTEX.z) * 0.08 - t * 1.2) * 0.8;
    VERTEX.y += wave1 + wave2 + wave3;
}
