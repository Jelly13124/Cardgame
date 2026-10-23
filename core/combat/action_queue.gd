extends RefCounted

## Top-level combat action queue (STS2 ActionQueueSet + ActionExecutor).
## Player-driven actions — playing a card, using a tool, ending the turn — run
## one at a time in the order they were made. Inside an action, commands and
## hook reactions still run depth-first with await; only top-level actions
## queue. Ending the combat drops actions that have not started.

signal drained

var _pending: Array = []  # [label: String, action: Callable]
var _running := false


## Queue `action` (a function, usually a coroutine) to run after everything
## queued before it. Starts immediately when the queue is idle.
func enqueue(label: String, action: Callable) -> void:
	_pending.append([label, action])
	if not _running:
		_run()


func is_busy() -> bool:
	return _running or not _pending.is_empty()


## Drop every action that has not started; the running one finishes.
func clear_pending() -> void:
	_pending.clear()


func _run() -> void:
	_running = true
	while not _pending.is_empty():
		var item: Array = _pending.pop_front()
		var action: Callable = item[1]
		if action.is_valid():
			await action.call()
	_running = false
	drained.emit()
