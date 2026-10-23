extends RefCounted

## Effect type → handler, per context. Cards, tools, relics, equipment sets,
## curses ("combat"), enemy moves ("enemy") and event options ("run") all run
## their `effects` through one registry, so a type behaves the same wherever it
## appears. A handler is `func(ctx, effect: Dictionary)` and may be a coroutine.
##
## DataValidator's allowed-type lists remain the data schema; a contract test
## keeps them and the registry in step.

var _handlers: Dictionary = {}  # context -> {type -> Callable}


func register(type: String, handler: Callable, contexts: Array) -> void:
	for context in contexts:
		if not _handlers.has(context):
			_handlers[context] = {}
		_handlers[context][type] = handler


func has_type(type: String, context: String) -> bool:
	return _handlers.has(context) and _handlers[context].has(type)


func types(context: String) -> PackedStringArray:
	var out := PackedStringArray()
	if _handlers.has(context):
		for type in _handlers[context]:
			out.append(str(type))
	out.sort()
	return out


func execute(ctx, effect: Dictionary) -> void:
	var type := str(effect.get("type", ""))
	var context := str(ctx.kind)
	if not has_type(type, context):
		push_error(
			(
				"EffectRegistry: unknown %s effect type '%s'. Register a handler and add it to the DataValidator allowed list."
				% [context, type]
			)
		)
		assert(false, "EffectRegistry: unknown %s effect type '%s'" % [context, type])
		return
	await _handlers[context][type].call(ctx, effect)
