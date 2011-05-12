precision highp float; 

varying highp vec2 v_TexCoord0;

uniform sampler2D texture0;
uniform sampler2D texture1;

uniform float time;
uniform vec2 center; // Mouse position
uniform vec3 shockParams; // 10.0, 0.8, 0.1

uniform float width;
uniform float height;

//const vec3 LightColor = { 1.0, 0.9,  0.5  };
//const vec3 DarkColor  = { 0.2, 0.05, 0.0  };
//const vec3 grayXfer   = { 0.3, 0.59, 0.11 };

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
	
	//GRAY
	vec4 color = texture2D(texture0, texCoord);
//	float sepia = 0.299*color.x + 0.587*color.y + 0.299*color.z;
	
	vec3 sepia;
	sepia.x = 0.393*color.x + 0.769*color.y + 0.189*color.z;
	sepia.y = 0.349*color.x + 0.686*color.y + 0.168*color.z;
	sepia.z = 0.272*color.x + 0.534*color.y + 0.131*color.z;
	
	gl_FragColor = vec4(sepia.x, sepia.y, sepia.z, 1.0);
	
}
