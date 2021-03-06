void borderVertexPass(vec4 positionIn) {
  if (renderBorder == 1) {
        vec4 adjustPosition = positionIn + vec4(normalize(normal) * borderWidth, 0.0);
        if (useAdditionMatrix == 1) {
            vec4 finalPos = viewProjection * additionMatrix * modelMatrix *  adjustPosition;
            gl_Position = finalPos;
        } else {
            vec4 finalPos = viewProjection * modelMatrix * adjustPosition;
            gl_Position = finalPos;
        }
    }
}
