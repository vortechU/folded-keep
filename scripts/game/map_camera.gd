extends RefCounted
## A light orbit-like drift and damped impact recoil for the printed map.
## Transform the whole Board so the paper, aiming overlays, FX and pointer mapping agree.

const MAP_SIZE := Vector2(360, 640)
const DRIFT_ROLL := 0.004
const DRIFT_SKEW := 0.003
const MAX_ROLL := 0.014
const MAX_SHIFT := 5.0

var _time := 0.0
var _weight := 0.0
var _shift := Vector2.ZERO
var _velocity := Vector2.ZERO
var _roll := 0.0
var _roll_velocity := 0.0


func reset() -> void:
	_weight = 0.0
	_shift = Vector2.ZERO
	_velocity = Vector2.ZERO
	_roll = 0.0
	_roll_velocity = 0.0


func kick(normal: Vector2, strength: float) -> void:
	var direction := normal.normalized()
	var amount := clampf(strength, 0.0, 1.6)
	_velocity = (_velocity + direction * amount * 65.0).limit_length(110.0)
	_roll_velocity = clampf(_roll_velocity + direction.x * amount * 0.16, -0.25, 0.25)


func advance(real_delta: float, active: bool, aiming: bool) -> void:
	# Never move the page under a held pointer, even during a slow-time fold.
	if aiming:
		return
	var remaining := minf(real_delta, 0.1)
	while remaining > 0.0:
		var step := minf(remaining, 1.0 / 120.0)
		_time += step
		_weight = lerpf(_weight, 1.0 if active else 0.0, 1.0 - exp(-step * 4.0))
		_velocity += (-_shift * 210.0 - _velocity * 18.0) * step
		_shift = (_shift + _velocity * step).limit_length(MAX_SHIFT)
		_roll_velocity += (-_roll * 150.0 - _roll_velocity * 17.0) * step
		_roll = clampf(_roll + _roll_velocity * step, -MAX_ROLL, MAX_ROLL)
		remaining -= step


func apply(board: Node2D, origin: Vector2, viewport_size: Vector2,
		looking: bool, pan: Vector2, look_zoom: float, shake: Vector2) -> void:
	if looking:
		board.transform = Transform2D(0.0, Vector2.ONE * look_zoom, 0.0,
			origin - pan * look_zoom + shake)
		return
	var roll := sin(_time * 0.48) * DRIFT_ROLL * _weight + _roll
	var skew := sin(_time * 0.37) * DRIFT_SKEW * _weight
	var scale := Vector2(1.0, 1.0 - (0.5 + 0.5 * sin(_time * 0.43)) * 0.004 * _weight)
	var drift := Vector2(sin(_time * 0.41) * 1.3, sin(_time * 0.53) * 1.8) * _weight
	var center := origin + MAP_SIZE * 0.5 + drift + _shift
	var pose := Transform2D(roll, scale, skew, Vector2.ZERO)
	# Fit every corner inside the viewport, including on phones with no spare table.
	var half_extent := pose.x.abs() * MAP_SIZE.x * 0.5 + pose.y.abs() * MAP_SIZE.y * 0.5
	var available := center.min(viewport_size - center) - Vector2.ONE * _weight * 0.75
	var fit := clampf(minf(available.x / half_extent.x, available.y / half_extent.y), 0.9, 1.0)
	pose = Transform2D(roll, scale * fit, skew, Vector2.ZERO)
	pose.origin = center + shake - pose.basis_xform(MAP_SIZE * 0.5)
	board.transform = pose
