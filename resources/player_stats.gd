class_name PlayerStats
extends Resource

@export var essence: int = 0
@export var max_hp: float = 100.0
@export var move_speed: float = 180.0
@export var max_stamina: float = 100.0
@export var dash_multiplier: float = 1.8
@export var vision_zoom: float = 1.0

var hp_rank: int = 0
var move_speed_rank: int = 0
var max_stamina_rank: int = 0
var dash_rank: int = 0
var vision_rank: int = 0
## Полый боец: сквозь него проходят игроки и мобы. Покупается один раз.
var body_hollow: bool = false
const HOLLOW_COST: int = 20

const HP_BASE := 100.0
const HP_STEP := 25.0
const HP_BASE_COST := 12
const HP_COST_GROWTH := 5
const HP_CAP := 200.0

const SPEED_BASE := 180.0
const SPEED_STEP := 15.0
const SPEED_BASE_COST := 10
const SPEED_COST_GROWTH := 5
const SPEED_CAP := 330.0

const STAMINA_BASE := 100.0
const STAMINA_STEP := 20.0
const STAMINA_BASE_COST := 10
const STAMINA_COST_GROWTH := 5
const STAMINA_CAP := 200.0

const DASH_BASE := 1.8
const DASH_STEP := 0.15
const DASH_BASE_COST := 15
const DASH_COST_GROWTH := 5
const DASH_CAP := 2.55

const VISION_BASE := 1.0
const VISION_STEP := 0.1
const VISION_BASE_COST := 12
const VISION_COST_GROWTH := 5
const VISION_CAP := 1.5


func try_spend(cost: int) -> bool:
	if cost < 0 or essence < cost:
		return false
	essence -= cost
	return true


func try_upgrade_max_hp() -> bool:
	if max_hp >= HP_CAP:
		return false
	var cost := HP_BASE_COST + hp_rank * HP_COST_GROWTH
	if not try_spend(cost):
		return false
	max_hp = minf(max_hp + HP_STEP, HP_CAP)
	hp_rank += 1
	emit_changed()
	return true


func try_upgrade_move_speed() -> bool:
	if move_speed >= SPEED_CAP:
		return false
	var cost := SPEED_BASE_COST + move_speed_rank * SPEED_COST_GROWTH
	if not try_spend(cost):
		return false
	move_speed = minf(move_speed + SPEED_STEP, SPEED_CAP)
	move_speed_rank += 1
	emit_changed()
	return true


func try_upgrade_max_stamina() -> bool:
	if max_stamina >= STAMINA_CAP:
		return false
	var cost := STAMINA_BASE_COST + max_stamina_rank * STAMINA_COST_GROWTH
	if not try_spend(cost):
		return false
	max_stamina = minf(max_stamina + STAMINA_STEP, STAMINA_CAP)
	max_stamina_rank += 1
	emit_changed()
	return true


func try_upgrade_dash_multiplier() -> bool:
	if dash_multiplier >= DASH_CAP:
		return false
	var cost := DASH_BASE_COST + dash_rank * DASH_COST_GROWTH
	if not try_spend(cost):
		return false
	dash_multiplier = minf(dash_multiplier + DASH_STEP, DASH_CAP)
	dash_rank += 1
	emit_changed()
	return true


func try_upgrade_vision_zoom() -> bool:
	if vision_zoom >= VISION_CAP:
		return false
	var cost := VISION_BASE_COST + vision_rank * VISION_COST_GROWTH
	if not try_spend(cost):
		return false
	vision_zoom = minf(vision_zoom + VISION_STEP, VISION_CAP)
	vision_rank += 1
	emit_changed()
	return true


func try_downgrade_max_hp() -> bool:
	if hp_rank <= 0:
		return false
	var refund := HP_BASE_COST + (hp_rank - 1) * HP_COST_GROWTH
	hp_rank -= 1
	max_hp = maxf(HP_BASE + float(hp_rank) * HP_STEP, HP_BASE)
	essence += refund
	emit_changed()
	return true


func try_downgrade_move_speed() -> bool:
	if move_speed_rank <= 0:
		return false
	var refund := SPEED_BASE_COST + (move_speed_rank - 1) * SPEED_COST_GROWTH
	move_speed_rank -= 1
	move_speed = maxf(SPEED_BASE + float(move_speed_rank) * SPEED_STEP, SPEED_BASE)
	essence += refund
	emit_changed()
	return true


func try_downgrade_max_stamina() -> bool:
	if max_stamina_rank <= 0:
		return false
	var refund := STAMINA_BASE_COST + (max_stamina_rank - 1) * STAMINA_COST_GROWTH
	max_stamina_rank -= 1
	max_stamina = maxf(STAMINA_BASE + float(max_stamina_rank) * STAMINA_STEP, STAMINA_BASE)
	essence += refund
	emit_changed()
	return true


func try_downgrade_dash_multiplier() -> bool:
	if dash_rank <= 0:
		return false
	var refund := DASH_BASE_COST + (dash_rank - 1) * DASH_COST_GROWTH
	dash_rank -= 1
	dash_multiplier = maxf(DASH_BASE + float(dash_rank) * DASH_STEP, DASH_BASE)
	essence += refund
	emit_changed()
	return true


func try_purchase_hollow() -> bool:
	if body_hollow or not try_spend(HOLLOW_COST):
		return false
	body_hollow = true
	emit_changed()
	return true


func try_refund_hollow() -> bool:
	if not body_hollow:
		return false
	body_hollow = false
	essence += HOLLOW_COST
	emit_changed()
	return true


func try_downgrade_vision_zoom() -> bool:
	if vision_rank <= 0:
		return false
	var refund := VISION_BASE_COST + (vision_rank - 1) * VISION_COST_GROWTH
	vision_rank -= 1
	vision_zoom = maxf(VISION_BASE + float(vision_rank) * VISION_STEP, VISION_BASE)
	essence += refund
	emit_changed()
	return true