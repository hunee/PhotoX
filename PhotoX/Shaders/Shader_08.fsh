precision highp float; 

varying highp vec2 v_TexCoord0;

uniform sampler2D texture0;
uniform sampler2D texture1;

uniform float time;
uniform vec2 center; // Mouse position
uniform vec3 shockParams; // 10.0, 0.8, 0.1

//XRAY
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
	
	vec4 color = texture2D(texture0, texCoord);
	float gray = 0.3*color.x + 0.59*color.y + 0.11*color.z;
	vec4 gcolor = vec4(gray, gray, gray, 1.0);
	gl_FragColor = 1.0 - color;
}
