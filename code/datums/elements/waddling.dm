/datum/element/waddling
	var/hops = FALSE

/datum/element/waddling/hopping
	hops = TRUE

/datum/element/waddling/Attach(datum/target)
	. = ..()
	if(!ismovable(target))
		return ELEMENT_INCOMPATIBLE
	if(!HAS_TRAIT(target, TRAIT_WADDLING))
		stack_trace("[type] added to [target] without adding TRAIT_WADDLING first. Please use AddElementTrait instead.")
	RegisterSignal(target, COMSIG_MOVABLE_MOVED, PROC_REF(Waddle))

/datum/element/waddling/Detach(datum/source)
	. = ..()
	UnregisterSignal(source, COMSIG_MOVABLE_MOVED)

/datum/element/waddling/proc/Waddle(atom/movable/moved, atom/oldloc, direction, forced)
	SIGNAL_HANDLER
	if(forced || CHECK_MOVE_LOOP_FLAGS(moved, MOVEMENT_LOOP_OUTSIDE_CONTROL))
		return
	if(isliving(moved))
		var/mob/living/living_moved = moved
		if (living_moved.incapacitated() || living_moved.body_position == LYING_DOWN)
			return
	waddling_animation(moved, hops)

/datum/element/waddling/proc/waddling_animation(atom/movable/target, hopping = FALSE)
	if(!hopping)
		animate(target, pixel_z = 4, time = 0)
		var/prev_trans = matrix(target.transform)
		animate(pixel_z = 0, transform = turn(target.transform, pick(-12, 0, 12)), time=2)
		animate(pixel_z = 0, transform = prev_trans, time = 0)
	else
		if(HAS_TRAIT(target, TRAIT_MOVE_FLYING))
			return
		animate(target, pixel_y = target.pixel_y + 4, time = 1, easing = CIRCULAR_EASING|EASE_OUT)
		animate(pixel_y = initial(target.pixel_y), time = 1, easing = CIRCULAR_EASING|EASE_IN)
