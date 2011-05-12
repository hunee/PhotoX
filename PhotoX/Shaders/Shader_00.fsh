precision highp float; 

varying highp vec2 v_TexCoord0;

uniform sampler2D texture0;
uniform sampler2D texture1;

void main()
{
	///NORMAL
	gl_FragColor = texture2D(texture0, v_TexCoord0);
}
