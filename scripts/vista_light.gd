extends RefCounted
## Exterior slice 2, light for depth (ART_DIRECTION.md section 8): warm near,
## cool and hazy far, and one hero glow at the end of the sightline.
## Brightness order: sanctum glow > warm lamp clusters > mid stone > vault.
## Runs last in vista.build(), after the cavern. Every tuning number is here.

const LAMP_CLUSTER_FREQUENCY: float = .035   # size of an inhabited stretch (~30 m)
const LAMP_CLUSTER_CUTOFF: float = .05       # higher = fewer, tighter clusters
const LAMP_COLOR: Color = Color("ffb35c")
const LAMP_GLOW: float = 3.2

const CLUSTER_CELL: float = 14.0             # metres; lamps in one cell share a light
const CLUSTER_MIN_LAMPS: int = 4
const CLUSTER_LIGHT_LIMIT: int = 56
const CLUSTER_REACH: float = 170.0           # only clusters this close get a light
const CLUSTER_COLOR: Color = Color("ff9d4a")
const CLUSTER_ENERGY: float = 5.0             # 6.0 until slice 7
const CLUSTER_RANGE: float = 20.0

const FAR_HAZE_DENSITY: float = .007
const FAR_HAZE_ALBEDO: Color = Color("c8dbe8")
const FAR_HAZE_EMISSION: Color = Color("1d2c3a")

const SANCTUM: Vector3 = Vector3(8, -13, -252)
const SANCTUM_HALO_EMISSION: Color = Color("7290a8")
const SANCTUM_HALO_DENSITY: float = .012
const SANCTUM_KEY_COLOR: Color = Color("d6ecf7")
const SANCTUM_KEY_ENERGY: float = 12.0

const EXTERIOR_MASK: int = 2
const VAULT_BOUNCE_ENERGY: float = .68        # ExteriorVaultBounce (vista.gd); .8 until slice 7, .9 originally
const VAULT_BOUNCE_COLOR: Color = Color("cdb79a") # warm city light off the stone; was cool a6bac1
const EYE: Vector3 = Vector3(-1, 4, -27.5)         # the overlook camera
const NEAR_SHELF_REACH: float = 110.0
const NEAR_SHELF_EMISSION: Color = Color("ffb867")
const NEAR_SHELF_GLOW: float = .9          # gorge_stacks_near (warm candle-lit stacks near the overlook)

var vista
var world
var art

func _init(owner) -> void:
	vista = owner
	world = owner.world
	art = owner.art

func build() -> void:
	lamp_material()
	cluster_lights()
	far_haze()
	sanctum_glow()

func lamp_material() -> void:
	var near: StandardMaterial3D = art.mat("gorge_stacks_near")
	near.emission = NEAR_SHELF_EMISSION
	near.emission_energy_multiplier = NEAR_SHELF_GLOW
	var lamp: StandardMaterial3D = art.mat("vista_lamp")
	lamp.albedo_color = LAMP_COLOR.lightened(.3)
	lamp.emission = LAMP_COLOR
	lamp.emission_energy_multiplier = LAMP_GLOW

## One warm light per dense lamp cluster near the overlook, so lit stretches
## throw warm pools onto their own facades instead of only showing dots.
func cluster_lights() -> void:
	var cells: Dictionary = {}
	for p: Vector3 in vista.lamp_points:
		var key := Vector3i((p / CLUSTER_CELL).floor())
		if not cells.has(key):
			cells[key] = []
		cells[key].append(p)
	var eye: Vector3 = EYE
	var picked: Array = []
	for key: Vector3i in cells:
		var points: Array = cells[key]
		if points.size() < CLUSTER_MIN_LAMPS:
			continue
		var centre := Vector3.ZERO
		for p: Vector3 in points:
			centre += p
		centre /= points.size()
		if centre.distance_to(eye) < CLUSTER_REACH:
			picked.append({"centre": centre, "count": points.size()})
	picked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.count > b.count)
	for i in range(mini(picked.size(), CLUSTER_LIGHT_LIMIT)):
		# Sit the light just off the facade, toward the open gorge.
		var centre: Vector3 = picked[i].centre
		var out := Vector3(-signf(centre.x) * 3.0, 1.5, 0)
		var node: OmniLight3D = vista.big_light(centre + out, CLUSTER_COLOR, CLUSTER_ENERGY, CLUSTER_RANGE, EXTERIOR_MASK)
		node.light_volumetric_fog_energy = 0.0   # fog scattering per light is costly

func fog(name: String, p: Vector3, size: Vector3, density: float, albedo: Color, emission: Color) -> FogVolume:
	var node := FogVolume.new()
	node.name = name
	node.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	node.position = p
	node.size = size
	var material := FogMaterial.new()
	material.density = density
	material.albedo = albedo
	material.emission = emission
	material.edge_fade = 1.0
	node.material = material
	world.add_child(node)
	return node

## Aerial perspective: the far half of the gorge sits in a cool, faintly lit
## haze that thickens with distance (soft ellipsoid edge toward the overlook).
func far_haze() -> void:
	fog("FarHaze", Vector3(4, 10, -300), Vector3(330, 260, 300), FAR_HAZE_DENSITY, FAR_HAZE_ALBEDO, FAR_HAZE_EMISSION)

## The end of the sightline: a cool luminous halo around the sanctum and a key
## light on its face, so it is the brightest thing in the view.
func sanctum_glow() -> void:
	fog("SanctumHalo", SANCTUM + Vector3(0, 40, -8), Vector3(100, 90, 70), SANCTUM_HALO_DENSITY, Color("dceaf1"), SANCTUM_HALO_EMISSION)
	vista.big_light(SANCTUM + Vector3(0, 42, 40), SANCTUM_KEY_COLOR, SANCTUM_KEY_ENERGY, 95, EXTERIOR_MASK)
