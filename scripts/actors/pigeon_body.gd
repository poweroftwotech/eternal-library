class_name PigeonBody
extends RefCounted
## The pigeon's body (phase 20 step 2: the rock dove, C16), made in code from
## the same low-poly parts as the nightingale (BirdBody's helpers), merged
## into one mesh per pose so a whole flock draws as three MultiMeshes
## (PigeonFlock): wings folded, wings up, wings down. A pigeon is never seen
## close for long, and moves in a crowd; a part per pivot (the nightingale's
## way) would be ten draw calls a bird.
##
## Real size (33 cm, metres), feet at the origin, beak toward -Z. The atlas's
## colours: blue-grey with darker head and tail band, two dark wing bars, a
## green and purple sheen on the neck, orange eyes, pink feet.

enum Pose { FOLDED, UP, DOWN }

const SIZE: float = 0.33

static var _meshes: Array[ArrayMesh] = []


## The three poses' meshes (Pose order), made once.
static func meshes() -> Array[ArrayMesh]:
	if not _meshes.is_empty():
		return _meshes
	for pose: int in 3:
		_meshes.append(_build(pose))
	return _meshes


## The material: BirdBody's (vertex colours, matte, both sides).
static func material() -> StandardMaterial3D:
	return BirdBody.material()


static func _build(pose: int) -> ArrayMesh:
	var grey := Color("8e98a6")
	var pale := Color("98a1ae")     # (the belly is grey too: a paler one read as a snowman from the front)
	var wing_pale := Color("a7afbb")
	var slate := Color("5c6675")
	var dark := Color("363b44")
	var sheen_g := Color("4fa38a")
	var sheen_p := Color("7d5c8c")
	var flying: bool = pose != Pose.FOLDED
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# In flight the body levels out (it sits tail-down at rest).
	var lean: float = 0.0 if flying else 0.18
	var whole := Transform3D(Basis(Vector3.RIGHT, lean), Vector3(0, 0.0 if not flying else 0.04, 0))
	# Body: plump, paler below.
	var body: ArrayMesh = BirdBody._egg(Vector3(0.115, 0.115, 0.23), func(n: Vector3, p: Vector3) -> Color:
		if n.y > 0.15:
			return grey.lerp(slate, clampf(p.z * 9.0, 0.0, 0.6))     # darker toward the rump
		return pale)
	st.append_from(body, 0, whole * Transform3D(Basis(), Vector3(0, 0.1, 0.0)))
	# Neck: the sheen, green on the sides turning purple at the front.
	var neck: ArrayMesh = BirdBody._egg(Vector3(0.078, 0.095, 0.08), func(n: Vector3, _p: Vector3) -> Color:
		return sheen_g.lerp(sheen_p, clampf(-n.z, 0.0, 1.0)).lerp(slate, 0.25))
	st.append_from(neck, 0, whole * Transform3D(Basis(), Vector3(0, 0.155, -0.075)))
	# Head: small and dark.
	var head_at := Vector3(0, 0.205, -0.098)
	var head: ArrayMesh = BirdBody._egg(Vector3(0.055, 0.055, 0.066), func(_n: Vector3, _p: Vector3) -> Color: return slate)
	st.append_from(head, 0, whole * Transform3D(Basis(), head_at))
	st.append_from(BirdBody._cone(0.0075, 0.022, Color("3f3c3a")), 0, whole * Transform3D(Basis(), head_at + Vector3(0, -0.004, -0.03)))
	st.append_from(BirdBody._disc(0.0055, Color("f2f0ea")), 0, whole * Transform3D(Basis(), head_at + Vector3(0, 0.006, -0.03)))     # the cere
	for s: float in [1.0, -1.0]:
		var side := Basis(Vector3.UP, s * PI * 0.5)
		st.append_from(BirdBody._disc(0.0068, Color("e07a2a")), 0, whole * Transform3D(side, head_at + Vector3(0.0262 * s, 0.006, -0.012)))
		st.append_from(BirdBody._disc(0.0032, Color("120e0c")), 0, whole * Transform3D(side, head_at + Vector3(0.0268 * s, 0.006, -0.012)))
	# Tail: grey with a dark band at its end.
	var tail: ArrayMesh = BirdBody._fan(0.05, 0.08 if flying else 0.068, 0.115, grey, dark)
	st.append_from(tail, 0, whole * Transform3D(Basis(Vector3.RIGHT, -0.05 if flying else 0.15), Vector3(0, 0.095, 0.085)))
	# Wings: pale grey, dark tips and trailing edge (the bars).
	var wing: ArrayMesh = BirdBody._blade(0.185 if not flying else 0.21, 0.085, dark, wing_pale)     # (folded, the tips reach the tail, not past it)
	for s: float in [1.0, -1.0]:
		var spread: float = 0.0 if not flying else 1.0
		var beat: float = 0.0 if not flying else (0.85 if pose == Pose.UP else -0.75)
		var rot := Basis.from_euler(Vector3(0.0, s * spread * 1.45, s * (spread * beat * 1.1 + (1.0 - spread) * -0.1)))
		var mirror := Basis().scaled(Vector3(s, 1, 1))
		st.append_from(wing, 0, whole * Transform3D(rot * mirror, Vector3(0.048 * s, 0.135, -0.05)))
	# Legs: short and pink; tucked away in flight.
	if not flying:
		for s: float in [1.0, -1.0]:
			st.append_from(BirdBody._stick(0.024, Color("c46a6a")), 0, Transform3D(Basis().scaled(Vector3(2.4, 2.0, 2.4)), Vector3(0.016 * s, 0.0, -0.01)))
	return st.commit()
