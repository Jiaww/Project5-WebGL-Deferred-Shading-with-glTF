#version 100
#extension GL_EXT_draw_buffers: enable

precision highp float;
precision highp int;

#define NUM_GBUFFERS 4

uniform vec3 u_cameraPos;
uniform vec3 u_lightCol;
uniform vec3 u_lightPos;
uniform float u_lightRad;
uniform sampler2D u_gbufs[NUM_GBUFFERS];
uniform sampler2D u_depth;
uniform bool u_debugScissor;

varying vec2 v_uv;

vec3 applyNormalMap(vec3 geomnor, vec3 normap) {
    normap = normap * 2.0 - 1.0;
    vec3 up = normalize(vec3(0.001, 1, 0.001));
    vec3 surftan = normalize(cross(geomnor, up));
    vec3 surfbinor = cross(geomnor, surftan);
    return normap.y * surftan + normap.x * surfbinor + normap.z * geomnor;
}

// Blinn-Phong adapted from http://sunandblackcat.com/tipFullView.php?l=eng&topicid=30&topic=Phong-Lighting

vec3 diffuseLighting(vec3 nor, vec3 col, vec3 lightDir) {
    float diffuseTerm = clamp(dot(nor, lightDir), 0.0, 1.0);
    return u_lightCol * col * diffuseTerm;
}


vec3 specularLighting(vec3 col, vec3 pos, vec3 nor, vec3 lightDir) {
    float specularTerm = 0.0;

    // Compute specular term if light facing the surface
    if (dot(nor, lightDir) > 0.0) {

        vec3 viewDir = normalize(u_cameraPos - pos);
        // Half vector
        vec3 halfVec = normalize(lightDir + viewDir);
        specularTerm = pow(dot(nor, halfVec), 10.0);
    }

    return vec3(1,1,1) * specularTerm;
}


void main() {

    if (u_debugScissor) {
        gl_FragData[0] = vec4(0.1,0,0,1.0);
        return;
    }

    vec4 gb0 = texture2D(u_gbufs[0], v_uv);
    vec4 gb1 = texture2D(u_gbufs[1], v_uv);
    vec4 gb2 = texture2D(u_gbufs[2], v_uv);
    vec4 gb3 = texture2D(u_gbufs[3], v_uv);
    float depth = texture2D(u_depth, v_uv).x;
    // TODO: Extract needed properties from the g-buffers into local variables

    // If nothing was rendered to this pixel, set alpha to 0 so that the
    // postprocessing step can render the sky color.
    if (depth == 1.0) {
        gl_FragData[0] = vec4(1, 0, 0, 0);
        return;
    }

    vec3 pos = gb0.xyz;      // World-space position
    vec3 geomnor = gb1.xyz;  // Normals of the geometry as defined, without normal mapping
    vec3 colmap = gb2.rgb;   // The color map - unlit "albedo" (surface color)
    vec3 normap = gb3.xyz;   // The raw normal map (normals relative to the surface they're on)
    vec3 nor = applyNormalMap (geomnor, normap);     // The true normals as we want to light them - with the normal map applied to the geometry normals (applyNormalMap above)
    vec3 lightDir = normalize(u_lightPos - pos);

    float dis = distance(u_lightPos, pos);
    if (dis < u_lightRad) {

        // Write out to colorTex
        float attenuation = max(0.0, u_lightRad - dis);
        vec4 color = vec4(
            diffuseLighting(nor, colmap, lightDir) * attenuation +
            specularLighting(colmap, pos, nor, lightDir) * 0.0,
            1.0);
        gl_FragData[0] = color;

        // Write out to hdrTex
        float brightness = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
        if (brightness > 1.0) {
            gl_FragData[1] = vec4(color.rgb, 1.0);
        }
    }
}
