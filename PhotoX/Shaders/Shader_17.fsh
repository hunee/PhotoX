precision highp float; 

varying highp vec2 v_TexCoord0;

uniform sampler2D texture0;
uniform sampler2D texture1;

uniform vec2 center; // Mouse position

// Parameter settings for effect sliders: Default, Minimum, Maximum, Increment.
// 0.25  0.0  0.5  0.02
// 0.50  0.0  1.0  0.02

uniform float time;
uniform float width;
uniform float height;

float pixel_w = 20.0;
float pixel_h = 15.0;

float param1 = 0.25;
float param2 = 0.5;

void main()
{
	vec2 texCoord = v_TexCoord0.xy;      // [0.0 ,1.0] x [0.0, 1.0]
	texCoord.x /= center.x * 2.0;
	texCoord.y /= center.y * 2.0;	

	vec2 normCoord = 2.0 * texCoord - 1.0;  // [-1.0 ,1.0] x [-1.0, 1.0]
	
	// Effect function: Stretch
	vec2 s = sign(normCoord);
	normCoord = abs(normCoord);
	normCoord = 0.5 * normCoord + 0.5 * smoothstep(param1, param2, normCoord) * normCoord;
	normCoord = s * normCoord;
	
	texCoord = normCoord / 2.0 + 0.5; // [0.0 ,1.0] x [0.0, 1.0]
	texCoord.x *= center.x * 2.0;
	texCoord.y *= center.y * 2.0;
	
	gl_FragColor = texture2D(texture0, texCoord);
}
