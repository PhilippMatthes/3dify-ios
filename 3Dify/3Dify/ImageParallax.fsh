
void main() {
    float depth = texture2D(u_image_depth, v_tex_coord).r;
    vec2 depth_offset = depth * u_offset * u_intensity;
    gl_FragColor = texture2D(u_image, v_tex_coord + depth_offset);
}
