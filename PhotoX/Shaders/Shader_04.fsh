precision highp float; 

varying highp vec2 v_TexCoord0;

uniform sampler2D texture0;
uniform sampler2D texture1;

uniform float time;
uniform vec2 center; // Mouse position
uniform vec3 shockParams; // 10.0, 0.8, 0.1

uniform float gamma; // 0.6
uniform float numColors; // 8.0

void main()
{
	vec2 uv = v_TexCoord0.xy;
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
	
	//	if (mirror == 1)
	//		texCoord.y = 1.0 - texCoord.y;
	
	//GAMMA
	vec3 c = texture2D(texture0, texCoord.xy).rgb;
	c = pow(c, vec3(gamma, gamma, gamma));
	c = c * numColors;
	c = floor(c);
	c = c / numColors;
	c = pow(c, vec3(1.0/gamma));
	gl_FragColor = vec4(c, 1.0);
}
