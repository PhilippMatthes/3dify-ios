
void main() {
    float depth = texture2D(u_image_depth, v_tex_coord).r;
    gl_FragColor = texture2D(u_image, v_tex_coord + u_offset * depth * u_intensity);
}
