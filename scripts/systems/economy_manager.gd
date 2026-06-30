class_name EconomyManager
extends Node

## Gold, income, and spending for a single player lane.

signal gold_changed(amount: int)
signal income_changed(amount: int)
signal income_tick(seconds_remaining: float)
signal transaction(type: String, amount: int)

var gold: int = 0
var income: int = 0
var income_tick_seconds: float = 10.0
var _tick_timer: float = 0.0

var total_gold_earned: int = 0
var total_income_earned: int = 0
var total_spent_towers: int = 0
var total_spent_sends: int = 0


func setup() -> void:
	var eco: Dictionary = BalanceConfig.economy
	gold = int(eco.get("starting_gold", 100))
	income = int(eco.get("starting_income", 10))
	income_tick_seconds = float(eco.get("income_tick_seconds", 10.0))
	_tick_timer = income_tick_seconds
	total_gold_earned = gold
	gold_changed.emit(gold)
	income_changed.emit(income)


func apply_network_state(p_gold: int, p_income: int) -> void:
	gold = p_gold
	income = p_income
	gold_changed.emit(gold)
	income_changed.emit(income)


func _process(delta: float) -> void:
	_tick_timer -= delta
	income_tick.emit(maxf(_tick_timer, 0.0))
	if _tick_timer <= 0.0:
		_tick_timer += income_tick_seconds
		add_gold(income, "income")


func add_gold(amount: int, source: String = "") -> void:
	gold += amount
	if amount > 0:
		total_gold_earned += amount
		if source == "income":
			total_income_earned += amount
	gold_changed.emit(gold)
	transaction.emit(source, amount)


func can_afford(cost: int) -> bool:
	return gold >= cost


func spend(cost: int, category: String = "") -> bool:
	if not can_afford(cost):
		return false
	gold -= cost
	if category == "tower":
		total_spent_towers += cost
	elif category == "send":
		total_spent_sends += cost
	gold_changed.emit(gold)
	transaction.emit("spend_" + category, -cost)
	return true


func add_income(amount: int) -> void:
	income += amount
	income_changed.emit(income)


func refund(amount: int) -> void:
	add_gold(amount, "refund")
