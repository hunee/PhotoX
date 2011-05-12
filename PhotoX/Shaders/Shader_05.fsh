precision highp float; 

varying highp vec2 v_TexCoord0;

uniform sampler2D texture0;
uniform sampler2D texture1;

uniform float time;
uniform vec2 center; // Mouse position
uniform vec3 shockParams; // 10.0, 0.8, 0.1

uniform float width;
uniform float height;

float pixel_w = 8.0;
float pixel_h = 8.0;

void main()
{
	//MOSIC
	vec2 uv = v_TexCoord0.xy;
	
	float dx = pixel_w*(1./width);
	float dy = pixel_h*(1./height);
	vec2 coord = vec2(dx*floor(uv.x/dx), dy*floor(uv.y/dy));
	gl_FragColor = vec4(texture2D(texture0, coord).rgb, 1.0);
}
