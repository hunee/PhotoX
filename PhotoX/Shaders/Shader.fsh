precision highp float; 

varying highp vec2 v_TexCoord0;

uniform sampler2D texture0;
uniform sampler2D texture1;


//uniform float gamma; // 0.6
//uniform float numColors; // 8.0

uniform float time;
uniform float width;
uniform float height;

uniform vec2 center; // Mouse position
uniform vec3 shockParams; // 10.0, 0.8, 0.1

float pixel_w = 20.0;
float pixel_h = 15.0;

//dent
// Parameter settings for effect sliders: Default, Minimum, Maximum, Increment.
// 0.0  -1.0  1.0  0.02
// 0.7   0.0  2.0  0.02

//bugle
// Parameter settings for effect sliders: Default, Minimum, Maximum, Increment.
// -0.1  -0.5  0.5  0.02
//  0.5   0.0  1.0  0.02

//fisheye
// Parameter settings for effect sliders: Default, Minimum, Maximum, Increment.
// 2.0  0.1  4.0  0.02
// 0.0  0.0  0.0  0.00

//lightTunnel
// Parameter settings for effect sliders: Default, Minimum, Maximum, Increment.
// 0.5  0.0  1.5  0.02
// 0.0  0.0  0.0  0.00

//mirror
// Parameter settings for effect sliders: Default, Minimum, Maximum, Increment.
// 0.0  0.0  0.0  0.0
// 0.0  0.0  0.0  0.0

//squeeze
// Parameter settings for effect sliders: Default, Minimum, Maximum, Increment.
// 1.8  1.0  3.0  0.02
// 0.8  0.1  2.0  0.02
float param1=1.8;
float param2 = 0.8;

void main()
{
	//GRAY
//	vec4 color = texture2D(texture0, v_TexCoord0);
//	gl_FragColor = vec4(color.x, color.x, color.x, 1.0);
	
	//GAMMA
/*	vec3 c = texture2D(texture0, v_TexCoord0.xy).rgb;
	c = pow(c, vec3(gamma, gamma, gamma));
	c = c * numColors;
	c = floor(c);
	c = c / numColors;
	c = pow(c, vec3(1.0/gamma));
	gl_FragColor = vec4(c, 1.0);*/
	
	
	//MOSIC
/*	vec2 uv = v_TexCoord0.xy;
	
	float dx = pixel_w*(1./width);
	float dy = pixel_h*(1./height);
	vec2 coord = vec2(dx*floor(uv.x/dx), dy*floor(uv.y/dy));
	gl_FragColor = vec4(texture2D(texture0, coord).rgb, 1.0);*/
	
	///Thermal Vision
	vec3 pixcol = texture2D(texture0, v_TexCoord0.xy).rgb;
	vec3 colors[3];
	colors[0] = vec3(0.,0.,1.);
	colors[1] = vec3(1.,1.,0.);
	colors[2] = vec3(1.,0.,0.);
	float lum = (pixcol.r+pixcol.g+pixcol.b)/3.;
	int ix = (lum < 0.5)? 0:1;
	gl_FragColor = vec4(mix(colors[ix],colors[ix+1],(lum-float(ix)*0.5)/0.5), 1.0);
	
/*	vec2 uv = v_TexCoord0.xy;
	vec2 texCoord = uv;
	float distance = distance(uv, center);
	if ( (distance <= (time + shockParams.z)) &&
		(distance >= (time - shockParams.z)) )
	{
		float diff = (distance - time);
		float powDiff = 1.0 - pow(abs(diff*shockParams.x),
								  shockParams.y);
		float diffTime = diff  * powDiff;
		vec2 diffUV = normalize(uv - center);
		texCoord = uv + (diffUV * diffTime);
	}
	gl_FragColor = texture2D(texture0, texCoord);
*/
	
/*
	vec2 texCoord = v_TexCoord0.xy;      // [0.0 ,1.0] x [0.0, 1.0]
    texCoord.x /= center.x * 2.0;
    texCoord.y /= center.y * 2.0;
    vec2 normCoord = 2.0 * texCoord - 1.0;  // [-1.0 ,1.0] x [-1.0, 1.0]
	
    // Convert to polar coordinates.
    float r = length(normCoord);
    float phi = atan(normCoord.y, normCoord.x);
	
    // Effect function: Dent
    //r = 2.0*r - r*smoothstep(param1, param2, r);
	
    // Effect function: Bulge
    //r = r * smoothstep(param1, param2, r);
	
	// Effect function: FishEye
    //r = pow(r, param1) / sqrt(2.0);
	
	// Effect function: LightTunnel
    //if (r > param1) r = param1;

    // Effect function: Squeeze
    r = pow(r, 1.0/param1) * param2;
	
    // Convert back to cartesian coordinates.
    normCoord.x = r * cos(phi);
    normCoord.y = r * sin(phi);

	// Effect function: Mirror
//    normCoord.x = normCoord.x * sign(normCoord.x);
	
	
    texCoord = normCoord / 2.0 + 0.5; // [0.0 ,1.0] x [0.0, 1.0]
    texCoord.x *= center.x * 2.0;
    texCoord.y *= center.y * 2.0;
	
    gl_FragColor = texture2D(texture0, texCoord);*/
}
