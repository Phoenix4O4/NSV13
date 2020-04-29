/datum/star_system/proc/add_ship(obj/structure/overmap/OM)
	system_contents += OM
	if(!occupying_z && OM.z) //Does this system have a physical existence? if not, we'll set this now so that any inbound ships jump to the same Z-level that we're on.
		occupying_z = OM.z
		restore_contents()
	var/turf/destination = get_turf(locate(round(world.maxx * 0.5, 1), round(world.maxy * 0.5, 1), occupying_z)) //Plop them bang in the center of the system.
	if(!destination)
		message_admins("WARNING: The [name] system has no exit point for ships! You probably forgot to set the [level_trait]:1 setting for that Z in your map's JSON file.")
		return
	OM.forceMove(destination)
	OM.current_system = src

/datum/star_system/proc/restore_contents()
	if(enemy_queue)
		for(var/X in enemy_queue)
			SSstar_system.spawn_ship(X, src)
			enemy_queue -= X
	if(!contents_positions.len)
		return //Nothing stored, no need to restore.
	for(var/obj/structure/overmap/ship in system_contents){
		var/list/info = contents_positions[ship]
		ship.forceMove(get_turf(locate(info["x"], info["y"], occupying_z))) //Let's unbox that ship. Nice.
		START_PROCESSING(SSovermap, ship) //And let's stop it from processing too.
	}
	contents_positions = null
	contents_positions = list()

/datum/star_system/proc/remove_ship(obj/structure/overmap/OM)
	message_admins("Removing a ship from [src].")
	var/list/other_player_ships = list()
	for(var/obj/structure/overmap/ship in system_contents)
		if(ship.role > NORMAL_OVERMAP && ship != OM)
			other_player_ships += ship
	if(OM.reserved_z == occupying_z && other_player_ships.len) //Alright, this is our Z-level but we're jumping out of it and there are still people here.
		var/obj/structure/overmap/ship = pick(other_player_ships)
		message_admins("Swapping [OM] and [ship]'s reserved Zs, as they overlap.")
		var/temp = ship.reserved_z
		ship.reserved_z = OM.reserved_z
		OM.reserved_z = temp
		OM.forceMove(locate(OM.x, OM.y, OM.reserved_z)) //Annnd actually kick them out of the current system.
		system_contents -= OM
		return //Early return here. This means that another player ship is already holding the system, and we really don't need to double-check for this.
	else
		message_admins("Successfully removed [OM] from [src]")
		OM.forceMove(locate(OM.x, OM.y, OM.reserved_z)) //Annnd actually kick them out of the current system.
		system_contents -= OM
	for(var/obj/structure/overmap/ship in system_contents)
		if(ship.role > NORMAL_OVERMAP) //If there's a player ship left to hold the system, early return and keep this Z loaded.
			return
		if(ship.operators.len && !ship.ai_controlled) //Alright, now we handle the small ships. If there is no longer a large ship to hold the system, we just get caught up its wake and travel along with it.
			ship.relay("<span class='warning'>You're caught in [OM]'s bluespace wake!</span>")
			ship.forceMove(locate(ship.x, ship.y, OM.reserved_z))
			system_contents -= ship
		else
			contents_positions[ship] = list("x" = ship.x, "y" = ship.y) //Cache the ship's position so we can regenerate it later.
			ship.moveToNullspace() //Anything that's an NPC should be stored safely in nullspace until we return.
			STOP_PROCESSING(SSovermap, ship) //And let's stop it from processing too.
	occupying_z = 0 //Alright, no ships are holding it anymore. Stop holding the Z-level

/obj/structure/overmap/proc/begin_jump(datum/star_system/target_system)
	relay_to_nearby('nsv13/sound/effects/ship/FTL.ogg', null, ignore_self=TRUE)//Ships just hear a small "crack" when another one jumps
	relay('nsv13/sound/effects/ship/FTL_long.ogg')
	desired_angle = 90 //90 degrees AKA face EAST to match the FTL parallax.
	addtimer(CALLBACK(src, .proc/jump, target_system, TRUE), 30 SECONDS)

/obj/structure/overmap/proc/jump(datum/star_system/target_system, ftl_start) //FTL start IE, are we beginning a jump? Or ending one?
	if(role == MAIN_OVERMAP)
		var/list/areas = list()
		areas = GLOB.teleportlocs.Copy()
		for(var/A in areas)
			var/area/AR = areas[A]
			if(istype(AR, /area/space))
				continue
			if(ftl_start)
				AR.parallax_movedir = EAST
			else
				AR.parallax_movedir = null
	else
		if(ftl_start)
			for(var/area/linked_area in linked_areas)
				linked_area.parallax_movedir = EAST
		else
			for(var/area/linked_area in linked_areas)
				linked_area.parallax_movedir = null
	for(var/mob/M in mobs_in_ship)
		if(M && M.client && M.hud_used && length(M.client.parallax_layers))
			M.hud_used.update_parallax(forced = TRUE)
		if(iscarbon(M))
			var/mob/living/carbon/L = M
			if(HAS_TRAIT(L, TRAIT_SEASICK))
				to_chat(L, "<span class='warning'>You can feel your head start to swim...</span>")
				if(prob(40)) //Take a roll! First option makes you puke and feel terrible. Second one makes you feel iffy.
					L.adjust_disgust(60)
				else
					L.adjust_disgust(40)
		shake_camera(M, 4, 1)
	if(ftl_start)
		relay('nsv13/sound/effects/ship/FTL_loop.ogg', "<span class='warning'>You feel the ship lurch forward</span>", loop=TRUE, channel = CHANNEL_SHIP_ALERT)
		SEND_SIGNAL(src, COMSIG_FTL_STATE_CHANGE)
		var/speed = (SSstar_system.ships[src]["current_system"].dist(target_system) / 10) //TODO: FTL drive speed upgrades.
		if(role == MAIN_OVERMAP) //Scuffed please fix
			priority_announce("Attention: All hands brace for FTL translation. Destination: [target_system]. Projected arrival time: [station_time_timestamp("hh:mm", world.time + speed MINUTES)] (Local time)","Automated announcement") //TEMP! Remove this shit when we move ruin spawns off-z
		SSstar_system.ships[src]["target_system"] = target_system
		SSstar_system.ships[src]["current_system"].remove_ship(src)
		SSstar_system.ships[src]["to_time"] = world.time + speed MINUTES
		SSstar_system.ships[src]["from_time"] = world.time
		SSstar_system.ships[src]["current_system"] = null
		addtimer(CALLBACK(src, .proc/jump, target_system, FALSE), speed MINUTES)
		if(structure_crit) //Tear the ship apart if theyre trying to limp away.
			for(var/i = 0, i < rand(4,8), i++)
				var/name = pick(GLOB.teleportlocs)
				var/area/target = GLOB.teleportlocs[name]
				var/turf/T = pick(get_area_turfs(target))
				new /obj/effect/temp_visual/explosion_telegraph(T)
	else
		SEND_SIGNAL(src, COMSIG_FTL_STATE_CHANGE)
		relay('nsv13/sound/effects/ship/freespace2/warp_close.wav', "<span class='warning'>You feel the ship lurch to a halt</span>", loop=FALSE, channel = CHANNEL_SHIP_ALERT)
		SSstar_system.ships[src]["target_system"] = null
		SSstar_system.ships[src]["current_system"] = target_system
		SSstar_system.ships[src]["last_system"] = target_system
		SSstar_system.ships[src]["from_time"] = 0
		SSstar_system.ships[src]["to_time"] = 0
		target_system.add_ship(src) //Get the system to transfer us to its location.

#define FTL_STATE_IDLE 1
#define FTL_STATE_SPOOLING 2
#define FTL_STATE_READY 3

/obj/machinery/computer/ship/ftl_computer
	name = "Seegson FTL navigation computer"
	desc = "A supercomputer which is capable of calculating incalculably complex vectors which are interpreted into a simplified 4-dimensional course through which ships are able to travel. It takes some time to spool up between uses"
	icon = 'nsv13/goonstation/icons/ftlcomp.dmi'
	icon_state = "ftl_off"
	bound_height = 96
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF | FREEZE_PROOF
	icon_screen = null
	icon_keyboard = null
	req_access = list(ACCESS_ENGINE_EQUIP)
	var/ftl_state = FTL_STATE_IDLE //Mr Gaeta, spool up the FTLs.
	var/obj/item/radio/radio //For engineering alerts.
	var/radio_key = /obj/item/encryptionkey/headset_eng
	var/engineering_channel = "Engineering"
	var/active = FALSE
	var/progress = 0 SECONDS
	var/progress_rate = 1 SECONDS
	var/spoolup_time = 1 MINUTES
	var/screen = 1
	var/can_cancel_jump = TRUE //Defaults to true. TODO: Make emagging disable this
	var/max_range = 100 //max jump range. This is _very_ long distance

/obj/machinery/computer/ship/ftl_computer/Initialize()
	. = ..()
	STOP_PROCESSING(SSmachines, src)

/obj/machinery/computer/ship/ftl_computer/process()
	if(!is_operational())
		depower()
		return
	if(progress < spoolup_time)
		icon_state = "ftl_charging"
		use_power = 500 //Eats up a fuckload of power as it takes 2 minutes to spool up.
		progress += progress_rate
		ftl_state = FTL_STATE_SPOOLING
		return
	else
		ready_ftl()
		use_power = 300 //Keeping the FTL spooled requires a fair bit of power
		return PROCESS_KILL

/obj/machinery/computer/ship/ftl_computer/has_overmap()
	. = ..()
	linked.ftl_drive = src

/obj/machinery/computer/ship/ftl_computer/attack_hand(mob/user)
	if(!has_overmap())
		return
	if(!allowed(user))
		var/sound = pick('nsv13/sound/effects/computer/error.ogg','nsv13/sound/effects/computer/error2.ogg','nsv13/sound/effects/computer/error3.ogg')
		playsound(src, sound, 100, 1)
		to_chat(user, "<span class='warning'>Access denied</span>")
		return
	ui_interact(user)

/obj/machinery/computer/ship/ftl_computer/ui_interact(mob/user, ui_key = "main", datum/tgui/ui = null, force_open = 0, datum/tgui/master_ui = null, datum/ui_state/state = GLOB.default_state) // Remember to use the appropriate state.
	ui = SStgui.try_update_ui(user, src, ui_key, ui, force_open)
	if(!ui)
		ui = new(user, src, ui_key, "ftl_computer", name, 560, 350, master_ui, state)
		ui.open()

/obj/machinery/computer/ship/ftl_computer/ui_act(action, params, datum/tgui/ui)
	if(..())
		return
	if(!has_overmap())
		return
	playsound(src, 'nsv13/sound/effects/computer/scroll_start.ogg', 100, 1)
	switch(action)
		if("toggle_power")
			active = !active
			ftl_state = FTL_STATE_IDLE
			progress = 0
			check_active(active)
	//	if("show_systems")
	//		screen = 2
		if("go_back")
			screen = 1
		if("jump")
			if(ftl_state != FTL_STATE_READY)
				visible_message("<span class='warning'>[icon2html(src, viewers(src))] Unable to comply. FTL vector calculation still in progress. 'Blind' FTL jumps are prohibited by the system administrative policy.</span>")
				return
			var/target_name = params["target"]
			for(var/datum/star_system/S in SSstar_system.systems)
				if(S.visitable && S.name == target_name)
					jump(S)
					check_active(FALSE)
					break

/obj/machinery/computer/ship/ftl_computer/ui_data(mob/user)
	var/list/data = list()
	data["powered"] = active
	data["progress"] = progress
	data["goal"] = spoolup_time
	data["ready"] = (ftl_state == FTL_STATE_READY) ? TRUE : FALSE
	data["mode"] = screen
	data["systems"] = list()
	for(var/datum/star_system/S in SSstar_system.systems)
		if(S.visitable && S != linked.current_system)
			data["systems"] += list(list("name" = S.name, "distance" = "2 minutes"))
	return data

/obj/machinery/computer/ship/ftl_computer/proc/check_active(state)
	if(state)
		spoolup()
		START_PROCESSING(SSmachines, src)
	else
		depower()
		STOP_PROCESSING(SSmachines, src)

/obj/machinery/computer/ship/ftl_computer/proc/jump(datum/star_system/target_system)
	if(!target_system)
		radio.talk_into(src, "ERROR. Specified star_system no longer exists.", engineering_channel)
		return
	linked?.begin_jump(target_system)
	say("Initiating FTL jump...")
	radio.talk_into(src, "Initiating FTL jump.", engineering_channel)
	playsound(src, 'nsv13/sound/effects/ship/freespace2/computer/escape.wav', 100, 1)
	visible_message("<span class='notice'>Initiating FTL jump.</span>")
	depower()

/obj/machinery/computer/ship/ftl_computer/proc/ready_ftl()
	ftl_state = FTL_STATE_READY
	progress = 0
	icon_state = "ftl_ready"
	say("FTL vectors calculated. Drive status: READY.")
	radio.talk_into(src, "FTL vectors calculated. Drive status: READY.", engineering_channel)
	playsound(src, 'nsv13/sound/effects/ship/freespace2/computer/escape.wav', 100, 1)

/obj/machinery/computer/ship/ftl_computer/proc/spoolup()
	if(ftl_state == FTL_STATE_IDLE)
		playsound(src, 'nsv13/sound/effects/computer/hum3.ogg', 100, 1)
		say("Calculating bluespace vectors. FTL spoolup initiated.")
		radio.talk_into(src, "Calculating bluespace vectors. FTL spoolup initiated.", engineering_channel)
		icon_state = "ftl_charging"
		ftl_state = FTL_STATE_SPOOLING

/obj/machinery/computer/ship/ftl_computer/Initialize()
	. = ..()
	radio = new(src)
	radio.keyslot = new radio_key
	radio.listening = 0
	radio.recalculateChannels()

/obj/machinery/computer/ship/ftl_computer/update_icon()
	return //Override computer updates

/obj/machinery/computer/ship/ftl_computer/proc/depower()
	icon_state = "ftl_off"
	ftl_state = FTL_STATE_IDLE
	progress = 0
	use_power = 0