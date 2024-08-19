/// how long it takes to infuse
#define INFUSING_TIME 4 SECONDS
/// we throw in a scream along the way.
#define SCREAM_TIME 3 SECONDS

/obj/machinery/dna_infuser
	name = "\improper DNA infuser"
	desc = "A defunct genetics machine for merging foreign DNA with a subject's own."
	icon = 'icons/obj/machines/cloning.dmi'
	icon_state = "infuser"
	base_icon_state = "infuser"
	density = TRUE
	obj_flags = BLOCKS_CONSTRUCTION // Becomes undense when the door is open
	interaction_flags_mouse_drop = NEED_HANDS | NEED_DEXTERITY
	circuit = /obj/item/circuitboard/machine/dna_infuser

	/// maximum tier this will infuse
	var/max_tier_allowed = DNA_MUTANT_TIER_ONE
	///currently infusing a vict- subject
	var/infusing = FALSE
	///what we're infusing with
	var/atom/movable/infusing_from
	///what we're turning into
	var/datum/infuser_entry/infusing_into
	///a message for relaying that the machine is locked if someone tries to leave while it's active
	COOLDOWN_DECLARE(message_cooldown)

/obj/machinery/dna_infuser/Initialize(mapload)
	. = ..()
	occupant_typecache = typecacheof(/mob/living/carbon/human)

/obj/machinery/dna_infuser/Destroy()
	. = ..()
	//dump_inventory_contents called by parent, emptying infusing_from
	infusing_into = null

/obj/machinery/dna_infuser/examine(mob/user)
	. = ..()
	if(!occupant)
		. += span_notice("Requires [span_bold("a subject")].")
	else
		. += span_notice("\"[span_bold(occupant.name)]\" is inside the infusion chamber.")
	if(!infusing_from)
		. += span_notice("Missing [span_bold("an infusion source")].")
	else
		. += span_notice("[span_bold(infusing_from.name)] is in the infusion slot.")
	. += span_notice("To operate: Obtain dead creature. Depending on size, drag or drop into the infuser slot.")
	. += span_notice("Subject enters the chamber, someone activates the machine. Voila! One of your organs has... changed!")
	. += span_notice("Alt-click to eject the infusion source, if one is inside.")
	if(max_tier_allowed < DNA_INFUSER_MAX_TIER)
		. += span_boldnotice("Right now, the DNA Infuser can only infuse Tier [max_tier_allowed] entries.")
	else
		. += span_boldnotice("Maximum tier unlocked. All DNA entries are possible.")
	. += span_notice("Examine further for more information.")

/obj/machinery/dna_infuser/examine_more(mob/user)
	. = ..()
	. += span_notice("If you infuse a Tier [DNA_MUTANT_TIER_ONE] entry until it unlocks the bonus, it will upgrade the maximum tier and allow more complicated infusions.")
	. += span_notice("The maximum level it can reach is Tier [DNA_INFUSER_MAX_TIER].")

/obj/machinery/dna_infuser/interact(mob/user)
	if(user == occupant)
		toggle_open(user)
		return
	if(infusing)
		balloon_alert(user, "not while it's on!")
		return
	if(occupant && infusing_from)
		if(!occupant.can_infuse(user))
			playsound(src, 'sound/machines/scanbuzz.ogg', 35, vary = TRUE)
			return
		balloon_alert(user, "starting DNA infusion...")
		start_infuse()
		return
	toggle_open(user)

/obj/machinery/dna_infuser/proc/start_infuse()
	var/mob/living/carbon/human/human_occupant = occupant
	infusing = TRUE
	visible_message(span_notice("[src] hums to life, beginning the infusion process!"))

	infusing_into = infusing_from.get_infusion_entry()
	var/fail_title = ""
	var/fail_explanation = ""
	if(istype(infusing_into, /datum/infuser_entry/fly))
		fail_title = "Unknown DNA"
		fail_explanation = "Unknown DNA. Consult the \"DNA infusion book\"."
	if(infusing_into.tier > max_tier_allowed)
		infusing_into = GLOB.infuser_entries[/datum/infuser_entry/fly]
		fail_title = "Overcomplexity"
		fail_explanation = "DNA too complicated to infuse. The machine needs to infuse simpler DNA first."
	playsound(src, 'sound/machines/blender.ogg', 50, vary = TRUE)
	to_chat(human_occupant, span_danger("Little needles repeatedly prick you!"))
	human_occupant.take_overall_damage(10)
	human_occupant.add_mob_memory(/datum/memory/dna_infusion, protagonist = human_occupant, deuteragonist = infusing_from, mutantlike = infusing_into.infusion_desc)
	Shake(duration = INFUSING_TIME)
	addtimer(CALLBACK(human_occupant, TYPE_PROC_REF(/mob, emote), "scream"), INFUSING_TIME - 1 SECONDS)
	addtimer(CALLBACK(src, PROC_REF(end_infuse), fail_explanation, fail_title), INFUSING_TIME)
	update_appearance()

/obj/machinery/dna_infuser/proc/end_infuse(fail_reason, fail_title)
	if(infuse_organ(occupant) || infuse_limb(occupant))
		to_chat(occupant, span_danger("You feel yourself becoming more... [infusing_into.infusion_desc]?"))
	infusing = FALSE
	infusing_into = null
	QDEL_NULL(infusing_from)
	playsound(src, 'sound/machines/microwave/microwave-end.ogg', 100, vary = FALSE)
	if(fail_explanation)
		playsound(src, 'sound/machines/printer.ogg', 100, TRUE)
		visible_message(span_notice("[src] prints an error report."))
		var/obj/item/paper/printed_paper = new /obj/item/paper(loc)
		printed_paper.name = "error report - '[fail_title]'"
		printed_paper.add_raw_text(fail_explanation)
		printed_paper.update_appearance()
	toggle_open()
	update_appearance()

/// Attempt to replace/add-to the occupant's organs with "mutated" equivalents.
/// Returns TRUE on success, FALSE on failure.
/// Requires the target mob to have an existing organic organ to "mutate".
// TODO: In the future, this should have more logic:
// - Replace non-mutant organs before mutant ones.
/obj/machinery/dna_infuser/proc/infuse_organ(mob/living/carbon/human/target)
	if(!ishuman(target))
		return FALSE
	var/obj/item/organ/new_organ = pick_organ(target)
	if(!new_organ)
		return FALSE
	// Valid organ successfully picked.
	new_organ = new new_organ()
	new_organ.replace_into(target)
	check_tier_progression(target)
	return TRUE

/obj/machinery/dna_infuser/proc/infuse_limb(mob/living/carbon/human/target)
	if(!ishuman(target))
		return FALSE
	var/obj/item/bodypart/new_limb = pick_limb(target)
	if(!new_limb)
		return FALSE
	new_limb = new new_limb()
	target.del_and_replace_bodypart(new_limb, special = TRUE)
	new_limb.variable_color = target.hair_color
	new_limb.update_limb(is_creating = TRUE)
	target.updateappearance(mutcolor_update = TRUE)
	check_tier_progression(target)
	if(!pick_limb(target) && infusing_into.all_limbs_mutant) // no more viable limbs
		ADD_TRAIT(target, TRAIT_MUTANT, BODYPART_TRAIT)
	return TRUE

/obj/machinery/dna_infuser/proc/pick_limb(mob/living/carbon/human/target)
	if(!infusing_into)
		return FALSE
	var/list/obj/item/organ/potential_new_limbs = infusing_into.output_limbs.Copy()
	for(var/obj/item/bodypart/new_limb as anything in infusing_into.output_limbs)
		var/obj/item/bodypart/old_limb = target.get_bodypart(initial(new_limb.body_zone))
		if(old_limb)
			if((old_limb.type != new_limb) && !IS_ROBOTIC_LIMB(old_limb))
				continue
		potential_new_limbs -= new_limb
	if(length(potential_new_limbs))
		return pick(potential_new_limbs)
	return FALSE

/// Picks a random mutated organ from the infuser entry which is also compatible with the target mob.
/// Tries to return a typepath of a valid mutant organ if all of the following criteria are true:
/// 1. Target must have a pre-existing organ in the same organ slot as the new organ;
///   - or the new organ must be external.
/// 2. Target's pre-existing organ must be organic / not robotic.
/// 3. Target must not have the same/identical organ.
/obj/machinery/dna_infuser/proc/pick_organ(mob/living/carbon/human/target)
	if(!infusing_into)
		return FALSE
	var/list/obj/item/organ/potential_new_organs = infusing_into.output_organs.Copy()
	// Remove organ typepaths from the list if they're incompatible with target.
	for(var/obj/item/organ/new_organ as anything in infusing_into.output_organs)
		var/obj/item/organ/old_organ = target.get_organ_slot(initial(new_organ.slot))
		if(old_organ)
			if((old_organ.type != new_organ) && !IS_ROBOTIC_ORGAN(old_organ))
				continue // Old organ can be mutated!
		else if(ispath(new_organ, /obj/item/organ/external))
			continue // External organ can be grown!
		// Internal organ is either missing, or is non-organic.
		potential_new_organs -= new_organ
	// Pick a random organ from the filtered list.
	if(length(potential_new_organs))
		return pick(potential_new_organs)
	return FALSE

/// checks to see if the machine should progress a new tier.
/obj/machinery/dna_infuser/proc/check_tier_progression(mob/living/carbon/human/target)
	if(
		max_tier_allowed != DNA_INFUSER_MAX_TIER \
		&& infusing_into.tier == max_tier_allowed \
		&& target.has_status_effect(infusing_into.status_effect_type) \
	)
		max_tier_allowed++
		playsound(src, 'sound/machines/ding.ogg', 50, TRUE)
		visible_message(span_notice("[src] dings as it records the results of the full infusion."))

/obj/machinery/dna_infuser/update_icon_state()
	//out of order
	if(machine_stat & (NOPOWER | BROKEN))
		icon_state = base_icon_state
		return ..()
	//maintenance
	if((machine_stat & MAINT) || panel_open)
		icon_state = "[base_icon_state]_panel"
		return ..()
	//actively running
	if(infusing)
		icon_state = "[base_icon_state]_on"
		return ..()
	//open or not
	icon_state = "[base_icon_state][state_open ? "_open" : null]"
	return ..()

/obj/machinery/dna_infuser/proc/toggle_open(mob/user)
	if(panel_open)
		if(user)
			balloon_alert(user, "close panel first!")
		return
	if(state_open)
		close_machine()
		return
	else if(infusing)
		if(user)
			balloon_alert(user, "not while it's on!")
		return
	open_machine(drop = FALSE)
	//we set drop to false to manually call it with an allowlist
	dump_inventory_contents(list(occupant))

/obj/machinery/dna_infuser/attackby(obj/item/used, mob/user, params)
	if(infusing)
		return
	if(!occupant && default_deconstruction_screwdriver(user, icon_state, icon_state, used))//sent icon_state is irrelevant...
		update_appearance()//..since we're updating the icon here, since the scanner can be unpowered when opened/closed
		return
	if(default_pry_open(used))
		return
	if(default_deconstruction_crowbar(used))
		return
	if(ismovable(used))
		add_infusion_item(used, user)
	return ..()

/obj/machinery/dna_infuser/relaymove(mob/living/user, direction)
	if(user.stat)
		if(COOLDOWN_FINISHED(src, message_cooldown))
			COOLDOWN_START(src, message_cooldown, 4 SECONDS)
			to_chat(user, span_warning("[src]'s door won't budge!"))
		return
	if(infusing)
		if(COOLDOWN_FINISHED(src, message_cooldown))
			COOLDOWN_START(src, message_cooldown, 4 SECONDS)
			to_chat(user, span_danger("[src]'s door won't budge while all the needles are infusing you!"))
		return
	open_machine(drop = FALSE)
	//we set drop to false to manually call it with an allowlist
	dump_inventory_contents(list(occupant))

// mostly good for dead mobs that turn into items like dead mice (smack to add).
/obj/machinery/dna_infuser/proc/add_infusion_item(obj/item/target, mob/user)
	// if the machine already has a infusion target, or the target is not valid then no adding.
	if(!is_valid_infusion(target, user))
		return
	if(!user.transferItemToLoc(target, src))
		to_chat(user, span_warning("[target] is stuck to your hand!"))
		return
	infusing_from = target

// mostly good for dead mobs like corpses (drag to add).
/obj/machinery/dna_infuser/mouse_drop_receive(atom/target, mob/user, params)
	// if the machine is closed, already has a infusion target, or the target is not valid then no mouse drop.
	if(!is_valid_infusion(target, user))
		return
	infusing_from = target
	infusing_from.forceMove(src)

/// Verify that the given infusion source/mob is a dead creature.
/obj/machinery/dna_infuser/proc/is_valid_infusion(atom/movable/target, mob/user)
	if(user.stat != CONSCIOUS || HAS_TRAIT(user, TRAIT_UI_BLOCKED) || !Adjacent(user) || !user.Adjacent(target) || !ISADVANCEDTOOLUSER(user))
		return FALSE
	if(target.flags_1 & HOLOGRAM_1)
		balloon_alert(user, "can't infuse with holograms!")
		return FALSE
	var/datum/component/edible/food_comp = IS_EDIBLE(target)
	if(infusing_from)
		balloon_alert(user, "empty the machine first!")
		return FALSE
	if(isliving(target))
		var/mob/living/living_target = target
		if(living_target.stat != DEAD)
			balloon_alert(user, "only dead creatures!")
			return FALSE
	else if(food_comp)
		if(!(food_comp.foodtypes & GORE))
			balloon_alert(user, "only creatures!")
			return FALSE
	else
		return FALSE
	return TRUE

/obj/machinery/dna_infuser/click_alt(mob/user)
	if(infusing)
		balloon_alert(user, "not while it's on!")
		return
	if(!infusing_from)
		balloon_alert(user, "no sample to eject!")
		return
	balloon_alert(user, "ejected sample")
	infusing_from.forceMove(get_turf(src))
	infusing_from = null
	return CLICK_ACTION_SUCCESS

#undef INFUSING_TIME
#undef SCREAM_TIME
