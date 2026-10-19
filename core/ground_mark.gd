class_name GroundMark
extends Node3D
## A flat marking on the ground (player rings, zones, warnings). Uses a Decal so it
## wraps over uneven ground, or a flat quad on the Compatibility renderer (web builds),
## which has no decals.

static var use_decals := RenderingServer.get_current_rendering_method() != "gl_compatibility"

var size := Vector3.ONE:
	set(v):
		size = v
		_apply()
var modulate := Color.WHITE:
	set(v):
		modulate = v
		_apply()
var emission_energy := 0.0:
	set(v):
		emission_energy = v
		_apply()

var _decal: Decal
var _quad: MeshInstance3D
var _mat: StandardMaterial3D


func _init(texture: Texture2D, p_size: Vector3, glow := 0.0) -> void:
	if use_decals:
		_decal = Decal.new()
		_decal.texture_albedo = texture
		if glow > 0.0:
			_decal.texture_emission = texture
		_decal.cull_mask = 1
		_decal.normal_fade = 0.4
		add_child(_decal)
	else:
		_quad = MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2.ONE
		_quad.mesh = plane
		_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mat = StandardMaterial3D.new()
		_mat.albedo_texture = texture
		_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat.render_priority = -1
		_quad.material_override = _mat
		_quad.position.y = 0.03
		add_child(_quad)
	emission_energy = glow
	size = p_size


func _apply() -> void:
	if _decal:
		_decal.size = size
		_decal.modulate = modulate
		_decal.emission_energy = emission_energy
	elif _quad:
		_quad.scale = Vector3(size.x, 1.0, size.z)
		_mat.albedo_color = modulate * (1.0 + emission_energy * 0.25)
