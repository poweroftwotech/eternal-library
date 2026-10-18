shader_type spatial;
render_mode cull_disabled;
uniform sampler2D leaf_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float simulation_time = 0.0;
uniform float wind_strength = 0.05;
void vertex(){
 vec3 p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 float breeze=sin(simulation_time*.83+p.x*.64+p.z*.31)*.62+sin(simulation_time*1.67+p.x*1.18-p.z*.7)*.24;
 float flutter=sin(simulation_time*3.2+p.x*3.1+p.y*2.0)*.14;
 float weight=.12+.88*pow(clamp(1.0-UV.y,0.0,1.0),1.35);
 vec3 offset=vec3(breeze+flutter,flutter*.18,breeze*.43)*wind_strength*weight;
 // Orthogonal instance axes: transform a world displacement without a 4x4 inverse.
 vec3 ax=MODEL_MATRIX[0].xyz, ay=MODEL_MATRIX[1].xyz, az=MODEL_MATRIX[2].xyz;
 VERTEX+=vec3(dot(offset,ax)/max(dot(ax,ax),.0001),
              dot(offset,ay)/max(dot(ay,ay),.0001),
              dot(offset,az)/max(dot(az,az),.0001));
}
void fragment(){
 vec4 leaf=texture(leaf_texture,UV);
 ALBEDO=leaf.rgb*tint.rgb*COLOR.rgb;
 ALPHA=leaf.a;
 ALPHA_SCISSOR_THRESHOLD=.45;
 ROUGHNESS=.93;
 SPECULAR=.22;
 BACKLIGHT=leaf.rgb*.10;
}
