shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never;
uniform float seed = 0.0;
float noise(vec2 p) {
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 float a=fract(sin(dot(i,vec2(127.1,311.7))+seed)*43758.5453);
 float b=fract(sin(dot(i+vec2(1,0),vec2(127.1,311.7))+seed)*43758.5453);
 float c=fract(sin(dot(i+vec2(0,1),vec2(127.1,311.7))+seed)*43758.5453);
 float d=fract(sin(dot(i+vec2(1,1),vec2(127.1,311.7))+seed)*43758.5453);
 return mix(mix(a,b,f.x),mix(c,d,f.x),f.y);
}
void fragment() {
 float threads=noise(vec2(UV.x*43.0,UV.y*9.0-TIME*1.6));
 float streak=noise(vec2(UV.x*113.0,UV.y*17.0-TIME*4.3));
 float edge=smoothstep(0.0,.16,UV.x)*smoothstep(0.0,.16,1.0-UV.x);
 float split=smoothstep(.19,.55,threads);
 float tail=1.0-smoothstep(.74,1.0,UV.y);
 ALBEDO=mix(vec3(.18,.36,.43),vec3(.68,.85,.87),threads*.65+streak*.35);
 ROUGHNESS=.34;
 EMISSION=vec3(.11,.22,.27)*(.4+streak*.55);
 ALPHA=edge*tail*(.14+split*.63);
 NORMAL_MAP=vec3(.5+(threads-.5)*.2,.5+(streak-.5)*.1,1.0);
}
