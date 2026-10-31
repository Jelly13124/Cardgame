extends "res://core/run/events/event_model.gd"

## Test fixture: INITIAL offers GO (to page TWO) and a locked NOPE; END on TWO
## finishes on DONE. `go_runs` counts how often GO ran.

var go_runs := 0


func generate_initial_options() -> Array:
	return [option("GO", _go), option("NOPE", Callable())]


func _go() -> void:
	go_runs += 1
	set_event_state("TWO", [option("END", func(): set_event_finished("DONE"))])
