class_name PostFx
extends CanvasLayer
## Light screen overlay: a soft vignette, a short warm edge when the player is hurt. Joins group "post_fx": HitFx calls kick() on every hit.

const SHADER := """
shader_type canvas_item;
// Cheap overlay (no screen read, fine on old GPUs): a soft daylight vignette, a brief warm edge when hurt.
uniform float ca = 0.0;
uniform float hurt = 0.0;

void fragment() {
	vec2 d = UV - 0.5;
	float edge = smoothstep(0.35, 0.85, length(d * vec2(1.0, 1.3)));
	float a = edge * (0.18 + hurt * 0.35) + ca * 0.05 * edge;
	COLOR = vec4(mix(vec3(0.05, 0.03, 0.02), vec3(0.75, 0.12, 0.05), hurt), a);
}
"""

var _mat: ShaderMaterial
var _ca := 0.0
var _hurt := 0.0


func _ready() -> void:
	layer = 1
	add_to_group("post_fx")
	var r := ColorRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = Shader.new()
	_mat.shader.code = SHADER
	r.material = _mat
	add_child(r)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func kick(amount: float) -> void:
	_ca = maxf(_ca, amount)


func hurt() -> void:
	_hurt = 1.0
	kick(1.0)


func _process(delta: float) -> void:
	_ca = maxf(0.0, _ca - delta * 4.0)
	_hurt = maxf(0.0, _hurt - delta * 2.0)
	_mat.set_shader_parameter("ca", _ca)
	_mat.set_shader_parameter("hurt", _hurt)
