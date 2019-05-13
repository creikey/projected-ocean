tool
extends ImmediateGeometry


# amplitude, steepness, wavelength
export (Array, Vector3) var waves = [Vector3(2.0, 50.0, 20.0)] setget set_waves
export (PoolRealArray) var wave_directions  = PoolRealArray([0.0]) setget set_wave_directions
#const NUMBER_OF_WAVES = 10;

export(float) var speed = 10.0 setget set_speed
export (float) var n_max = 15.0 setget set_n_max

export(bool) var noise_enabled = true setget set_noise_enabled
export(float) var noise_amplitude = 0.28 setget set_noise_amplitude
export(float) var noise_frequency = 0.065 setget set_noise_frequency
export(float) var noise_speed = 0.48 setget set_noise_speed

export(int) var seed_value = 0 setget set_seed

var res = 250.0
var initialized = false

var counter = 0.5
#var cube_cam = preload("res://CubeCamra.tscn")
export (NodePath) var cube_cam_path
onready var cube_cam = get_node(cube_cam_path) as cube_camera;

#var waves = []
var waves_in_tex = ImageTexture.new()

func set_n_max(new_n_max):
	n_max = new_n_max
	material_override.set_shader_param('n_max', new_n_max)

func set_waves(new_waves):
	waves = new_waves
	if waves.size() != wave_directions.size():
		printerr("new waves size not equal to wave directions size")
	else:
		update_waves()

func set_wave_directions(new_wave_directions):
	wave_directions = new_wave_directions
	if waves.size() != wave_directions.size():
		printerr("new wave directions size not equal to waves size")
	else:
		update_waves()

func _ready():
	
	for j in range(res):
		var y = j/res - 0.5
		var n_y = (j+1)/res - 0.5
		begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in range(res):
			var x = i/res - 0.5
			
#			var new_x = x 
#			var new_y = y
			
			add_vertex(Vector3(x*2, 0, -y*2))
			
#			new_y = n_y - translation.z
			add_vertex(Vector3(x*2, 0, -n_y*2))
		end()
	begin(Mesh.PRIMITIVE_POINTS)
	add_vertex(-Vector3(1,1,1)*pow(2,32))
	add_vertex(Vector3(1,1,1)*pow(2,32))
	end()
	material_override.set_shader_param('resolution', res)
#	waves_in_tex = ImageTexture.new()
	update_waves()


func _process(delta):
	counter -= delta
	if counter <= 0:
		if cube_cam != null:
			var cube_map = cube_cam.update_cube_map()
			material_override.set_shader_param('environment', cube_map)
		counter = INF
	
	material_override.set_shader_param('time_offset', OS.get_ticks_msec()/1000.0 * speed)
	initialized = true


func set_seed(value):
	seed_value = value
	if initialized:
		update_waves()

func set_speed(value):
	speed = value
	material_override.set_shader_param('speed', value)

func set_noise_enabled(value):
	noise_enabled = value
	var old_noise_params = material_override.get_shader_param('noise_params')
	old_noise_params.d = 1 if value else 0
	material_override.set_shader_param('noise_params', old_noise_params)

func set_noise_amplitude(value):
	noise_amplitude = value
	var old_noise_params = material_override.get_shader_param('noise_params')
	old_noise_params.x = value
	material_override.set_shader_param('noise_params', old_noise_params)

func set_noise_frequency(value):
	noise_frequency = value
	var old_noise_params = material_override.get_shader_param('noise_params')
	old_noise_params.y = value
	material_override.set_shader_param('noise_params', old_noise_params)

func set_noise_speed(value):
	noise_speed = value
	var old_noise_params = material_override.get_shader_param('noise_params')
	old_noise_params.z = value
	material_override.set_shader_param('noise_params', old_noise_params)

func get_displace(position):
	
	var new_p;
	if typeof(position) == TYPE_VECTOR3:
		new_p = Vector3(position.x, 0.0, position.z)
	elif typeof(position) == TYPE_VECTOR2:
		new_p = Vector3(position.x, 0.0, position.y)
	else:
		printerr('Position is not a vector3!')
		breakpoint
	
	var freq; var amp; var steep; var phase; var dir
	for i in waves.size():
		var w = waves[i]
		amp = w[0]/100.0
		if amp == 0.0: continue
		
		dir = Vector2(1.0, 1.0).rotated(deg2rad(wave_directions[i]))
		freq = TAU/w[2]
		steep = w[1]/100.0
		phase = 2.0 * freq
		
		var W = position.dot(freq*dir) + phase * OS.get_ticks_msec()/1000.0 * speed
		
		new_p.x += steep*amp * dir.x * cos(W)
		new_p.z += steep*amp * dir.y * cos(W)
		new_p.y += amp * sin(W)
	return new_p;

func update_waves():
	#Generate Waves..
	seed(seed_value)
#	var amp_length_ratio = amplitude / wavelength
	waves_in_tex = ImageTexture.new()
	var img = Image.new()
	img.create(5, waves.size(), false, Image.FORMAT_RF)
	img.lock()
	for i in range(waves.size()):
		var w = waves[i]
#		var _wavelength = rand_range(wavelength/2.0, wavelength*2.0)
		var _wind_direction = Vector2(1.0, 1.0).rotated(deg2rad(wave_directions[i]))
		
		img.set_pixel(0, i, Color(w[0]/100.0, 0,0,0))
		img.set_pixel(1, i, Color(w[1]/100.0, 0,0,0))
		img.set_pixel(2, i, Color(_wind_direction.x, 0,0,0))
		img.set_pixel(3, i, Color(_wind_direction.y, 0,0,0))
		img.set_pixel(4, i, Color((TAU)/w[2], 0,0,0))

	img.unlock()
	waves_in_tex.create_from_image(img, 0)
	
	material_override.set_shader_param('waves', waves_in_tex)