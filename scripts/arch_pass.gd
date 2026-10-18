extends RefCounted
## v0.12 architecture massing toward the concept (ART_DIRECTION.md backlog 3).
## The pointed arch geometry itself lives in world.gd (arch_specs); this pass adds
##   * the centre pier's projecting courses and full-height inset mosaic panel
##   * ivy clumps along the arch heads and short strands hanging from them
var world
var art
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

## Centre pier between the garden and archive arches (visible face, z = +.5).
const PIER_X: Vector2 = Vector2(3.25,5.43)
const PANEL_WIDTH: float = .78
const PANEL_BOTTOM: float = 1.55
const PANEL_TOP: float = 7.15

var ivy_leaf: QuadMesh

func _init(owner, factory) -> void:
	world = owner
	art = factory
	rng.seed = 30303

func build() -> void:
	ivy_leaf = QuadMesh.new()
	ivy_leaf.size = Vector2(.17,.19)
	centre_pier()
	for spec in world.arch_specs:
		arch_head_ivy(spec)
	pier_ivy()

func centre_pier() -> void:
	var cx: float = (PIER_X.x+PIER_X.y)*.5
	var width: float = PIER_X.y-PIER_X.x
	var spring: float = world.arch_specs[0][2]
	# Projecting courses: base course over the dado, impost course split by the
	# panel, and a deep cornice under the existing cap.
	art.worn_block(Vector3(cx,PANEL_BOTTOM-.1,.6),Vector3(width,.2,.3),art.mat("limestone"),.04)
	art.worn_block(Vector3(cx,PANEL_TOP+.12,.6),Vector3(width,.24,.32),art.mat("limestone"),.05)
	var half_panel: float = PANEL_WIDTH*.5+.12
	for side in [-1,1]:
		var inner: float = cx+side*half_panel
		var outer: float = PIER_X.y if side>0 else PIER_X.x
		var course = art.worn_block(Vector3((inner+outer)*.5,spring+.23,.62),Vector3(absf(outer-inner),.2,.28),art.mat("limestone"),.04)
		course.name = "PierCourse"
	# Raised frame with a one-stone return, so the mosaic reads as inset.
	var height: float = PANEL_TOP-PANEL_BOTTOM
	var mid: float = (PANEL_TOP+PANEL_BOTTOM)*.5
	for side in [-1,1]:
		art.box(Vector3(cx+side*(PANEL_WIDTH*.5+.06),mid,.58),Vector3(.12,height,.16),art.mat("limestone"))
	for y in [PANEL_BOTTOM+.06,PANEL_TOP-.06]:
		art.box(Vector3(cx,y,.58),Vector3(PANEL_WIDTH+.24,.12,.16),art.mat("limestone"))
	art.box(Vector3(cx,mid,.53),Vector3(PANEL_WIDTH,height-.12,.06),art.mat("mosaic"))
	# Thin gold fillet inside the frame (concept panel border).
	for side in [-1,1]:
		art.box(Vector3(cx+side*(PANEL_WIDTH*.5-.02),mid,.565),Vector3(.03,height-.2,.02),art.mat("brass"))

## Ivy clumps on the extrados near the apex and strands hanging into the opening.
func arch_head_ivy(spec: Array) -> void:
	var origin: Vector3 = spec[0]
	var radius: float = spec[1]
	var spring: float = spec[2]
	var rise: float = spec[3]
	var thickness: float = spec[4]
	for side in [-1,1]:
		for i in range(16):
			var t: float = lerpf(.45,1.0,float(i)/15.0)
			var p: Vector2 = world.arch_point(radius+thickness+.12,spring,rise+thickness+.12,t)
			var center: Vector3 = origin+Vector3(side*p.x,p.y,.82)
			for j in range(9):
				leaf(center+Vector3(rng.randf_range(-.28,.28),rng.randf_range(-.24,.2),rng.randf_range(-.04,.12)))
		for i in range(7):
			var t: float = lerpf(.5,.97,float(i)/6.0)+rng.randf_range(-.03,.03)
			var p: Vector2 = world.arch_point(radius,spring,rise,t)
			var top: Vector3 = origin+Vector3(side*p.x,p.y,.62)
			var length: int = rng.randi_range(3,11)
			var sway: float = rng.randf_range(-.05,.05)
			for j in range(length):
				leaf(top+Vector3(sway*j+rng.randf_range(-.05,.05),-j*.13,rng.randf_range(-.03,.05)))

## Strands falling down the centre pier's edges from the cornice.
func pier_ivy() -> void:
	for x in [PIER_X.x+.15,PIER_X.y-.15]:
		for strand in range(3):
			var top: Vector3 = Vector3(x+rng.randf_range(-.18,.18),PANEL_TOP+.25,.8)
			for j in range(rng.randi_range(12,30)):
				leaf(top+Vector3(rng.randf_range(-.07,.07),-j*.13,rng.randf_range(-.02,.05)))

func leaf(p: Vector3) -> void:
	var basis: Basis = Basis.from_euler(Vector3(rng.randf_range(-.5,.5),rng.randf_range(-.6,.6),rng.randf_range(-.9,.9)))
	art.batch_mesh("arch_head_ivy",ivy_leaf,art.mat("ivy_leaf"),Transform3D(basis,p),Color(rng.randf_range(.62,.86),rng.randf_range(.78,1.0),.62))
