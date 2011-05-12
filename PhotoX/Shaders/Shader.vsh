precision highp float; 

attribute vec4 position;
attribute vec4 texcoord0;

varying vec2 v_TexCoord0;

void main()
{
	gl_Position = position;
	v_TexCoord0 = texcoord0.xy;
}