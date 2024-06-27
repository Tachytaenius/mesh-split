varying vec3 fragmentNormal;

#ifdef VERTEX

uniform mat4 modelToClip;

attribute vec3 VertexNormal;

vec4 position(mat4 loveTransform, vec4 modelSpaceVertexPos) {
	fragmentNormal = VertexNormal;
	return modelToClip * modelSpaceVertexPos;
}

#endif

#ifdef PIXEL

vec4 effect(vec4 colour, sampler2D image, vec2 textureCoords, vec2 windowCoords) {
	return colour * vec4(fragmentNormal / 2.0 + 0.5, 1.0);
}

#endif
