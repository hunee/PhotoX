precision highp float; 

varying highp vec2 v_TexCoord0;

uniform sampler2D texture0;
uniform sampler2D texture1;

uniform vec2 center; // Mouse position

//dent
// Parameter settings for effect sliders: Default, Minimum, Maximum, Increment.
// 0.0  -1.0  1.0  0.02
// 0.7   0.0  2.0  0.02

float param1 = 0.0;
float param2 = 0.7;

void main()
{
	vec2 texCoord = v_TexCoord0.xy;      // [0.0 ,1.0] x [0.0, 1.0]
	texCoord.x /= center.x * 2.0;
	texCoord.y /= center.y * 2.0;
	
  vec2 normCoord = 2.0 * texCoord - 1.0;  // [-1.0 ,1.0] x [-1.0, 1.0]
	
  // Convert to polar coordinates.
  float r = length(normCoord);
  float phi = atan(normCoord.y, normCoord.x);
	
  // Effect function: Dent
  r = 2.0*r - r*smoothstep(param1, param2, r);

	// Convert back to cartesian coordinates.
  normCoord.x = r * cos(phi);
  normCoord.y = r * sin(phi);

  texCoord = normCoord / 2.0 + 0.5; // [0.0 ,1.0] x [0.0, 1.0]
	texCoord.x *= center.x * 2.0;
	texCoord.y *= center.y * 2.0;
	
  gl_FragColor = texture2D(texture0, texCoord);
}
