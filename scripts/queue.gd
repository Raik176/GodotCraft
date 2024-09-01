class_name Queue
extends Node

# Doing some workarounds
var _capacity: int = -2 : set = _set_capacity
var _queue: Array       : set = _set_queue

func _init(capacity: int):
	_capacity = -1 if capacity < -1 else capacity
	_queue = []

func _set_capacity(new_state):
	if _capacity == -2:
		_capacity = new_state
func _set_queue(new_state):
	if _queue == null:
		_queue = new_state

## Clears the queue.
func clear() -> void:
	_queue.clear()

## Returns whether the queue contains said item.
func contains(object) -> bool:
	return _queue.has(object)

## Returns whether the queue is full.
func full() -> bool:
	return false if _capacity == -1 else _queue.size() == _capacity
	
## Returns whether the queue is empty.
func empty() -> bool:
	return _queue.is_empty()

## Inserts the specified element into this queue if it is possible to do 
## so immediately without violating capacity restrictions. 
## When using a capacity-restricted queue, this method is generally 
## preferable to [method add], which can fail to 
## insert an element only by throwing an exception
func offer(object) -> bool:
	if not full():
		_queue.push_back(object)
		return true
	else:
		return false

## Retrieves and removes the head of this queue, 
## or returns null if this queue is empty.
func poll():
	return _queue.pop_front()

## Retrieves, but does not remove, the head of this queue, 
## or returns null if this queue is empty.
func peek():
	return _queue[0]
