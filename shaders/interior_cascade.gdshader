shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
uniform float simulation_time = 0.0;
void fragment(){
 float fine=sin(UV.x*82.0+sin(UV.y*11.0-simulation_time*5.0)*.6)*.5+.5;
 float streak=sin(UV.y*31.0-simulation_time*8.0+UV.x*7.0)*.5+.5;
 ALBEDO=mix(vec3(.16,.26,.22),vec3(.47,.55,.45),fine*.18+streak*.08);
 ROUGHNESS=.38;
 SPECULAR=.22;
 METALLIC=0.0;
 ALPHA=.22+fine*.12;
}
