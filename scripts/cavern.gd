extends RefCounted
## Closed, organic cavern around the overlook vista (ART_DIRECTION.md section 8,
## slice 1). It replaces the smooth heightfield roof and loose crags with:
## a low ragged vault that comes down behind and above the banks, stalactite
## clusters, rock spurs that rise out of the banks into the vault and pinch a
## throat, a closed far apse behind the sanctum, and a lit mist floor.
## Runs after the banks so it can keep clear of every terrace (vista.ledges).

## Vault crown height along the gorge: near chamber, throat, far hall, apse.
const CROWN: Array = [
	Vector2(-16, 44), Vector2(-115, 47), Vector2(-160, 42), Vector2(-188, 38),
	Vector2(-215, 50), Vector2(-245, 74), Vector2(-292, 76), Vector2(-318, 54), Vector2(-336, 24)]
const SIDE_DROP: float = 46.0        # how far the vault falls toward the outer walls
const CLEARANCE: float = 8.0         # rock never comes closer than this above a terrace
const MIN_TIP: float = 22.0          # bridges and their pavilions stay clear
const SIGHTLINE_X: float = 20.0      # keep the throat centre open toward the sanctum
const SANCTUM: Vector3 = Vector3(8, 0, -256)
const UPLIGHT_ENERGY: float = .3     # cool fill on the rock from below
const CITY_GLOW_ENERGY: float = 3.0   # warm window glow on the rock above each tower
const MIST_LIGHT_ENERGY: float = 2.5  # under the mist floor
const RIM_LIGHT_ENERGY: float = 2.0   # cool light along the vault
const FAR_HALL_ENERGY: float = 5.0    # behind the sanctum: the end of the sightline

var vista
var world
var art
var rng := RandomNumberGenerator.new()
var noise := FastNoiseLite.new()
var stalactite_count: int = 0

func _init(owner) -> void:
	vista = owner
	world = owner.world
	art = owner.art
	rng.seed = 51207
	noise.seed = 31921
	noise.frequency = .03

func build() -> void:
	var material: StandardMaterial3D = art.mat("cave").duplicate()
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color("c9d3dc")
	art.materials["gorge_roof"] = material
	var previous: int = art.render_layer
	art.render_layer = 4
	var vault := SurfaceTool.new()
	vault.begin(Mesh.PRIMITIVE_TRIANGLES)
	build_vault(vault)
	shadowless(art.mesh_node(vault.commit(), Vector3.ZERO, material))
	var rock := SurfaceTool.new()
	rock.begin(Mesh.PRIMITIVE_TRIANGLES)
	build_spurs(rock)
	build_apse(rock)
	build_stalactites(rock)
	shadowless(art.mesh_node(rock.commit(), Vector3.ZERO, material))
	art.render_layer = previous
	build_mist()
	build_lights()

func shadowless(node: MeshInstance3D) -> void:
	# The vault sits above everything; as a caster it would black out the
	# exterior bounce light.
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func crown(z: float) -> float:
	if z >= CROWN[0].x:
		return CROWN[0].y
	for i in range(CROWN.size() - 1):
		var a: Vector2 = CROWN[i]
		var b: Vector2 = CROWN[i + 1]
		if z <= a.x and z >= b.x:
			return lerpf(a.y, b.y, smoothstep(0.0, 1.0, (a.x - z) / (a.x - b.x)))
	return CROWN.back().y

## Lowest y rock may reach at (x, z): above every terrace and the sanctum.
func floor_at(x: float, z: float) -> float:
	var y: float = -INF
	for ledge: Dictionary in vista.ledges:
		var c: Vector2 = ledge.center
		var dx: float = (x - c.x) / (ledge.rx * 1.12 + 4.0)
		var dz: float = (z - c.y) / (ledge.rz * 1.12 + 4.0)
		if dx * dx + dz * dz <= 1.0:
			y = maxf(y, ledge.height + CLEARANCE)
	if Vector2(x - SANCTUM.x, z - SANCTUM.z).length() < 34.0:
		y = maxf(y, 64.0)
	return y

func vault_height(x: float, z: float) -> float:
	var raw: float = crown(z) - SIDE_DROP * pow(minf(absf(x) / 150.0, 1.0), 1.6)
	# Broad lumps and pockets, then sharper ridges, so light pools and breaks.
	raw += noise.get_noise_2d(x * .4, z * .4) * 16.0 + noise.get_noise_2d(x, z) * 9.0
	raw -= absf(noise.get_noise_2d(x * 3.1, z * 3.1)) * 7.0
	return maxf(raw, floor_at(x, z))

func build_vault(surface: SurfaceTool) -> void:
	var points: Array = []
	for row in range(54):
		var line: Array = []
		for col in range(55):
			var x: float = -162.0 + col * 6.0
			var z: float = -16.0 - row * 6.0
			line.append(Vector3(x, vault_height(x, z), z))
		points.append(line)
	for row in range(53):
		for col in range(54):
			var corners: Array = []
			var normals: Array = []
			for ij: Vector2i in [Vector2i(col, row), Vector2i(col + 1, row), Vector2i(col, row + 1),
					Vector2i(col + 1, row), Vector2i(col + 1, row + 1), Vector2i(col, row + 1)]:
				var p: Vector3 = points[ij.y][ij.x]
				var left: Vector3 = points[ij.y][maxi(ij.x - 1, 0)]
				var right: Vector3 = points[ij.y][mini(ij.x + 1, 54)]
				var near: Vector3 = points[maxi(ij.y - 1, 0)][ij.x]
				var far: Vector3 = points[mini(ij.y + 1, 53)][ij.x]
				var hx: float = (right.y - left.y) / maxf(right.x - left.x, .01)
				var hz: float = (far.y - near.y) / minf(far.z - near.z, -.01)
				# The visible side faces down into the gorge.
				corners.append(p)
				normals.append(Vector3(hx, -1.0, hz).normalized())
			for t in range(2):
				triangle(surface, corners.slice(t * 3, t * 3 + 3), normals.slice(t * 3, t * 3 + 3))

## A tapering, slightly bent rock drip hanging from `top`.
func hang(surface: SurfaceTool, top: Vector3, radius: float, length: float, flat: float = 1.0) -> void:
	stalactite_count += 1
	var lean := Vector2(rng.randf_range(-.1, .1), rng.randf_range(-.1, .1)) * length
	var phase: float = rng.randf() * TAU
	var rings: Array = []
	var centres: Array = []
	for ring in range(8):
		var t: float = ring / 7.0
		var centre: Vector3 = top + Vector3(lean.x * t * t, 3.0 * (1.0 - t) - length * t, lean.y * t * t)
		var r: float = radius * pow(1.0 - t, 1.3) * (1.0 + .22 * sin(t * 11.0 + phase)) + .03
		var row: Array = []
		for i in range(10):
			var a: float = TAU * i / 9.0 + phase
			var j: float = rng.randf_range(.8, 1.2) if i < 9 else 1.0
			row.append(centre + Vector3(cos(a) * r * j, rng.randf_range(-.25, .25) * r * (1.0 - t), sin(a) * r * j * flat))
		row[9] = row[0]
		rings.append(row)
		centres.append(centre)
	emit_tube(surface, rings, centres, -.35)

## A rock pillar rising from deep below into the vault, with a noisy profile.
func column(surface: SurfaceTool, base: Vector2, radius: float, bottom: float, top: float) -> void:
	var rings: Array = []
	var centres: Array = []
	var count: int = maxi(4, int((top - bottom) / 9.0))
	for ring in range(count + 1):
		var t: float = float(ring) / count
		var y: float = lerpf(bottom, top, t)
		var centre := Vector3(base.x + noise.get_noise_1d(y * 2.0 + base.x) * radius * .35, y, base.y + noise.get_noise_1d(y * 2.0 + base.y) * radius * .35)
		# Flares where it meets the vault, like a flowstone curtain.
		var r: float = radius * (1.0 + .45 * pow(t, 4.0))
		var row: Array = []
		for i in range(15):
			var a: float = TAU * i / 14.0
			var bulge: float = 1.0 + .3 * noise.get_noise_2d(cos(a) * 40.0 + base.x, y * 1.5)
			row.append(centre + Vector3(cos(a), 0, sin(a)) * r * bulge)
		row[14] = row[0]
		rings.append(row)
		centres.append(centre)
	emit_tube(surface, rings, centres, 0.0)

func emit_tube(surface: SurfaceTool, rings: Array, centres: Array, droop: float) -> void:
	for ring in range(rings.size() - 1):
		for i in range(rings[ring].size() - 1):
			var corners: Array = []
			var normals: Array = []
			for ij: Vector2i in [Vector2i(i, ring), Vector2i(i + 1, ring), Vector2i(i, ring + 1),
					Vector2i(i + 1, ring), Vector2i(i + 1, ring + 1), Vector2i(i, ring + 1)]:
				var p: Vector3 = rings[ij.y][ij.x]
				var out: Vector3 = p - centres[ij.y]
				out.y = 0.0
				corners.append(p)
				normals.append((out.normalized() + Vector3(0, droop, 0)).normalized())
			for t in range(2):
				triangle(surface, corners.slice(t * 3, t * 3 + 3), normals.slice(t * 3, t * 3 + 3))

## Godot treats clockwise triangles as front faces and, with culling off,
## flips the normal of back faces. Wind each triangle so its front side
## matches the shading normal, or the rock renders black.
func triangle(surface: SurfaceTool, corners: Array, normals: Array) -> void:
	var order: Array = [0, 1, 2]
	var facing: Vector3 = (corners[2] - corners[0]).cross(corners[1] - corners[0])
	if facing.dot(normals[0] + normals[1] + normals[2]) < 0.0:
		order = [0, 2, 1]
	for k: int in order:
		var p: Vector3 = corners[k]
		surface.set_normal(normals[k])
		surface.set_uv(Vector2(p.x + p.z, p.y) * .05)
		surface.add_vertex(p)

func build_spurs(surface: SurfaceTool) -> void:
	# Two staggered spurs rise out of the banks behind their facades and merge
	# into the vault: the gorge narrows into a throat before the far hall.
	for data: Array in [[-74, -178, 21], [80, -199, 23], [-96, -120, 15], [104, -150, 16]]:
		var top: float = vault_height(data[0], data[1]) + 6.0
		column(surface, Vector2(data[0], data[1]), data[2], -176.0, top)
	# Curtains hang across the throat's shoulders.
	for i in range(10):
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var x: float = side * rng.randf_range(24.0, 62.0)
		var z: float = rng.randf_range(-176.0, -204.0)
		var top: float = vault_height(x, z)
		var tip: float = maxf(maxf(floor_at(x, z), MIN_TIP), top - rng.randf_range(16.0, 26.0))
		hang(surface, Vector3(x, top, z), rng.randf_range(5.0, 9.0), top - tip, .55)

func build_apse(surface: SurfaceTool) -> void:
	# Rock closes the far hall behind the sanctum so the sightline ends.
	for data: Array in [[-82, -300, 18], [-38, -314, 20], [8, -320, 22], [52, -314, 19], [96, -298, 17]]:
		column(surface, Vector2(data[0], data[1]), data[2], -176.0, vault_height(data[0], data[1]) + 6.0)

func build_stalactites(surface: SurfaceTool) -> void:
	# Curtains: each cluster is strung along a random direction, one long
	# leader with shorter, thick drips beside it.
	for cluster in range(170):
		var cx: float = rng.randf_range(-140.0, 140.0)
		var cz: float = rng.randf_range(-60.0, -320.0)
		# Denser over the throat lip, which frames the far hall.
		if cluster < 40:
			cz = rng.randf_range(-168.0, -212.0)
		var along := Vector2.from_angle(rng.randf() * TAU)
		for i in range(rng.randi_range(3, 9)):
			var offset: Vector2 = along * rng.randf_range(-14.0, 14.0) + along.orthogonal() * rng.randf_range(-3.0, 3.0)
			var x: float = cx + offset.x
			var z: float = cz + offset.y
			var top: float = vault_height(x, z)
			var length: float = rng.randf_range(4.0, 14.0) * (2.6 if i == 0 else 1.0)
			if absf(x - SANCTUM.x) < SIGHTLINE_X and z < -160.0:
				length = minf(length, 7.0)
			var tip: float = maxf(maxf(floor_at(x, z), MIN_TIP), top - length)
			if top - tip < 2.0:
				continue
			hang(surface, Vector3(x, top, z), clampf((top - tip) * rng.randf_range(.14, .24), .8, 6.0), top - tip)

func build_mist() -> void:
	# Pale lit mist replaces the black void below the terraces.
	var fog := FogVolume.new()
	fog.name = "GorgeMistFloor"
	fog.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	fog.position = Vector3(4, -52, -175)
	fog.size = Vector3(230, 76, 300)
	var material := FogMaterial.new()
	material.density = .02
	material.albedo = Color("e4e9ea")
	material.emission = Color("5b5c74")
	material.height_falloff = .02
	fog.material = material
	world.add_child(fog)

func build_lights() -> void:
	# Cool light under the mist and along the vault rims; the far hall glows.
	for p: Vector3 in [Vector3(-20, -30, -90), Vector3(24, -34, -150), Vector3(-8, -32, -215)]:
		big_light(p, Color("c9cdea"), MIST_LIGHT_ENERGY, 90)
	big_light(Vector3(-30, 30, -110), Color("8aaab7"), RIM_LIGHT_ENERGY, 70)
	big_light(Vector3(36, 28, -190), Color("9fc0cb"), RIM_LIGHT_ENERGY, 70)
	big_light(Vector3(8, 46, -292), Color("b5dbea"), FAR_HALL_ENERGY, 95)
	# Light that reaches only the rock layer (4): a soft cool uplight bounced off
	# the mist, and the warm glow of each tower top on the rock above it.
	var uplight := DirectionalLight3D.new()
	uplight.name = "CavernUplight"
	uplight.rotation_degrees = Vector3(70, 15, 0)
	uplight.light_color = Color("7d98a8")
	uplight.light_energy = UPLIGHT_ENERGY
	uplight.light_cull_mask = 4
	uplight.light_volumetric_fog_energy = 0.0
	world.add_child(uplight)
	for ledge: Dictionary in vista.ledges:
		var top: bool = true
		for other: Dictionary in vista.ledges:
			if other.height > ledge.height and other.center.distance_to(ledge.center) < 25.0:
				top = false
				break
		if top:
			var glow: OmniLight3D = big_light(Vector3(ledge.center.x, ledge.height + 3.0, ledge.center.y), Color("ffbf7a"), CITY_GLOW_ENERGY, 55)
			glow.light_cull_mask = 4
			glow.light_volumetric_fog_energy = 0.0

## world.light() falls off as distance^-1.2, tuned for the camp's few-metre
## lights. At cavern scale (10-60 m) that leaves almost nothing, so these use
## a gentler falloff.
func big_light(p: Vector3, color: Color, energy: float, distance: float) -> OmniLight3D:
	var node: OmniLight3D = world.light(p, color, energy, distance)
	node.omni_attenuation = .5
	return node
