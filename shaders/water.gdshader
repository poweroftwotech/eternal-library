shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
uniform float simulation_time = 0.0;
uniform vec3 water_tint : source_color = vec3(.10,.18,.15);
varying vec3 world_pos;
float ripple(vec2 p,float t){
 return sin(p.y*18.0+t*2.2+sin(p.x*7.0))*.45
       +sin(p.x*24.0-p.y*9.0+t*1.3)*.25
       +sin(p.x*37.0+p.y*29.0-t*2.8)*.12;
}
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=world_pos.xz;
 float t=simulation_time;
 float h=ripple(p,t);
 float dx=(ripple(p+vec2(.012,0),t)-h)*.12;
 float dz=(ripple(p+vec2(0,.012),t)-h)*.12;
 NORMAL_MAP=normalize(vec3(-dx,-dz,1.0))*.5+.5;
 NORMAL_MAP_DEPTH=.6;
 float fresnel=pow(1.0-clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0),4.0);
 ALBEDO=water_tint+vec3(.012,.018,.012)*h;
 METALLIC=0.0;
 SPECULAR=.25;
 ROUGHNESS=.30;
 ALPHA=.27+fresnel*.25;
}
