shader_type spatial;
render_mode skip_vertex_transform, cull_front, unshaded;

uniform sampler2D waves;

uniform float resolution = 200.0;
uniform float n_max = 200.0;
uniform float alpha = 0.9;
uniform float PI = 3.14159;

uniform sampler2D noise;
uniform vec4 noise_params;
/*This uniform contains data that changes noise.
X- The amplitude of the noise.
Y- The frequency of the noise.
Z- The propagation speed of the noise.
W- Whether to use noise. Values greater than 0 means yes.
*/

uniform samplerCube environment;
uniform vec4 water_color: hint_color;

uniform float project_bias = 1.2;

uniform float time_offset;

mat3 getRotation(mat4 camera) {
	return mat3(
		camera[0].xyz,
		camera[1].xyz,
		camera[2].xyz
	);
}
vec3 getPosition(mat4 camera) {
	return -camera[3].xyz * getRotation(camera);
}

vec2 getImagePlan(mat4 projection, vec2 uv) {
	float focal = projection[0].x * project_bias;
	float aspect = projection[1].y * project_bias;
	
	return vec2((uv.x - 0.5) * aspect, (uv.y - 0.5) * focal);}
vec3 getCamRay(mat4 projection, mat3 rotation, vec2 screenUV) {
	return vec3(screenUV.xy, projection[0].x) * rotation;}
vec3 interceptPlane(vec3 source, vec3 dir, vec4 plane) {
	float dist = (-plane.w - dot(plane.xyz, source)) / dot(plane.xyz, dir);
	if(dist < 0.0) {
		return source + dir * dist;
	} else {
		return -(vec3(source.x, plane.w, source.z) + vec3(dir.x, plane.w, dir.z) * 100000.0);
	}
}

vec3 computeProjectedPosition(in vec3 cam_pos, in mat3 cam_rot, in mat4 projection, in vec2 uv) {
	vec2 screenUV = getImagePlan(projection, uv);
	
	vec3 ray = getCamRay(projection, cam_rot, screenUV);
	return interceptPlane(cam_pos, ray, vec4(0.0,-1.0,0.0,0.0));
}

float noise3D(vec3 p) {
	float iz = floor(p.z);
	float fz = fract(p.z);
	vec2 a_off = vec2(0.852, 29.0) * iz*0.643;
	vec2 b_off = vec2(0.852, 29.0) * (iz+1.0)*0.643;
	float a = texture(noise, p.xy + a_off).r;
	float b = texture(noise, p.xy + b_off).r;
	
	return mix(a, b, fz);
}

vec3 wave_interpolated(vec2 pos, float time, float grid_distance) {
	vec3 new_p = vec3(pos.x, 0.0, pos.y);
	
	float w, amp, steep, phase;
	vec2 dir;
	for(int i = 0; i < textureSize(waves, 0).y; i++) {
		amp = texelFetch(waves, ivec2(0, i), 0).r;
		if(amp == 0.0) continue;
		
		dir = vec2(texelFetch(waves, ivec2(2, i), 0).r, texelFetch(waves, ivec2(3, i), 0).r);
		w = texelFetch(waves, ivec2(4, i), 0).r;
		steep = texelFetch(waves, ivec2(1, i), 0).r /(w*amp);
		phase = 2.0 * w;
		
		float W = dot(w*dir, pos) + phase*time;
		
		float dim_factor = clamp( (((((2.0*PI)/w)/grid_distance) - 1.0) / (n_max - 1.0)), 0.0, 1.0);
		new_p.xz += (steep*amp * dir * cos(W))*dim_factor;
		new_p.y += (amp * sin(W))*dim_factor;
	}
	if(noise_params.w > 0.0)
		new_p.y += noise3D(vec3(pos.xy*noise_params.y, time*noise_params.z))*noise_params.x;
	return new_p;
}

vec3 wave(vec2 pos, float time) {
	vec3 new_p = vec3(pos.x, 0.0, pos.y);
	
	float w, amp, steep, phase;
	vec2 dir;
	for(int i = 0; i < textureSize(waves, 0).y; i++) {
		amp = texelFetch(waves, ivec2(0, i), 0).r;
		if(amp == 0.0) continue;
		
		dir = vec2(texelFetch(waves, ivec2(2, i), 0).r, texelFetch(waves, ivec2(3, i), 0).r);
		w = texelFetch(waves, ivec2(4, i), 0).r;
		steep = texelFetch(waves, ivec2(1, i), 0).r /(w*amp);
		phase = 2.0 * w;
		
		float W = dot(w*dir, pos) + phase*time;
		
		new_p.xz += steep*amp * dir * cos(W);
		new_p.y += amp * sin(W);
	}
	if(noise_params.w > 0.0)
		new_p.y += noise3D(vec3(pos.xy*noise_params.y, time*noise_params.z))*noise_params.x;
	return new_p;
}

vec3 wave_normal(vec2 pos, float time, float res) {
	
	vec3 right = wave(pos + vec2(res, 0.0), time);
	vec3 left = wave(pos - vec2(res, 0.0), time);
	vec3 down = wave(pos - vec2(0.0, res), time);
	vec3 up = wave(pos + vec2(0.0, res), time);
	
	return -normalize(cross(right-left, down-up));
}

varying vec2 vert_coord;
varying float vert_dist;

varying vec3 eyeVector;
//varying float grid_distance;

void vertex() {
	vec2 screen_uv = VERTEX.xz + 0.5;
	
	mat4 projected_cam_matrix = INV_CAMERA_MATRIX;
	
	mat3 camRotation = getRotation(projected_cam_matrix);
	vec3 camPosition = getPosition(projected_cam_matrix);
	
	VERTEX = computeProjectedPosition(camPosition, camRotation, PROJECTION_MATRIX, screen_uv);
	
	vec2 pre_displace = VERTEX.xz;
	vec3 next_point = computeProjectedPosition(camPosition, camRotation, PROJECTION_MATRIX, screen_uv + vec2(1.0 / resolution));
	float grid_distance = distance(VERTEX, next_point);
	VERTEX = wave_interpolated(VERTEX.xz, time_offset, grid_distance);
//	VERTEX = wave(VERTEX.xz, time_offset);
	if( any(lessThan(screen_uv, vec2(0.0))) || any(greaterThan(screen_uv, vec2(1.0))) )
		VERTEX.xz = pre_displace;
	
	eyeVector = normalize(VERTEX - camPosition);
	vert_coord = VERTEX.xz;
	VERTEX = (INV_CAMERA_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vert_dist = length(VERTEX);
}

float fresnel(float n1, float n2, float cos_theta) {
	float R0 = pow((n1 - n2) / (n1+n2), 2);
	return R0 + (1.0 - R0)*pow(1.0 - cos_theta, 5);
}

void fragment() {
	NORMAL = wave_normal(vert_coord, time_offset, vert_dist/80.0);
	NORMAL = mix(NORMAL, vec3(0, -1, 0), min(vert_dist/1500.0, 1));
	
	float eye_dot_norm = dot(eyeVector, NORMAL);
	float n1 = 1.0, n2 = 1.3333;
	
	float reflectiveness = fresnel(n1, n2, abs(eye_dot_norm));
	
	vec3 reflect_global = texture(environment, reflect(eyeVector, NORMAL)).rgb;
	vec3 refract_global;
	if(eye_dot_norm < 0.0)
		refract_global = texture(environment, refract(eyeVector, NORMAL, n1/n2)).rgb;
	else
		refract_global = water_color.rgb;
	
	ALBEDO = mix(refract_global, reflect_global, reflectiveness);
//	ALBEDO = vec3(grid_distance/5.0);
	ALPHA = alpha;
}