extends "res://core/listeners/status_listener.gd"

## Metallicize: at the bearer's turn start, after its Block reset, gain stacks
## Block.


func after_owner_block_reset(entity: Node) -> void:
	var n := amount()
	if n > 0 and entity.has_method("add_block"):
		entity.add_block(n)
