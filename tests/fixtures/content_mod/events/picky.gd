extends "res://core/run/events/event_model.gd"

## Test fixture: an event that never fits the run.


func is_allowed(_run_state) -> bool:
	return false


func generate_initial_options() -> Array:
	return [option("GO", func(): set_event_finished("DONE"))]
