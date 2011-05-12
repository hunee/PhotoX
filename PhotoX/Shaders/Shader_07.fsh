precision highp float; 

varying highp vec2 v_TexCoord0;

uniform sampler2D texture0;
uniform sampler2D texture1;

uniform float time;
uniform vec2 center; // Mouse position
uniform vec3 shockParams; // 10.0, 0.8, 0.1

uniform float width;
uniform float height;

void main()
{
	///Thermal Vision
	vec3 pixcol = texture2D(texture0, v_TexCoord0.xy).rgb;
	vec3 colors[3];
	colors[0] = vec3(0.,0.,1.);
	colors[1] = vec3(1.,1.,0.);
	colors[2] = vec3(1.,0.,0.);
	float lum = (pixcol.r+pixcol.g+pixcol.b)/3.;
	int ix = (lum < 0.5)? 0:1;
	gl_FragColor = vec4(mix(colors[ix],colors[ix+1],(lum-float(ix)*0.5)/0.5), 1.0);
	
}
