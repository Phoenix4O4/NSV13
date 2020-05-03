/**

How this works:
Pick a system to scan that's in range
Scan it (takes scan_goal minutes)
Once you have performed an initial scan, you gain information about what anomalies are in that system, and can collect a few research points from them by doing yet another scan, but to get the full whack, you need to probe them with a science probe that
you build.

*/

/obj/machinery/computer/ship/navigation/astrometrics
	var/max_range = 40 //In light years, the range at which we can scan systems for data. This is quite short.
	var/scan_progress = 0
	var/scan_goal = 2 MINUTES
	var/datum/star_system/scan_target = null
	var/list/scanned = list()
	var/datum/techweb/linked_techweb = null
	var/obj/item/radio/radio //For engineering alerts.
	var/radio_key = /obj/item/encryptionkey/headset_sci
	var/channel = "Science"

/obj/machinery/computer/ship/navigation/astrometrics/Initialize()
	. = ..()
	radio = new(src)
	radio.keyslot = new radio_key
	radio.listening = 0
	radio.recalculateChannels()
	linked_techweb = SSresearch.science_tech

/obj/machinery/computer/ship/navigation/astrometrics/ui_interact(mob/user, ui_key = "main", datum/tgui/ui = null, force_open = 0, datum/tgui/master_ui = null, datum/ui_state/state = GLOB.default_state) // Remember to use the appropriate state.
	ui = SStgui.try_update_ui(user, src, ui_key, ui, force_open)
	if(!ui)
		var/datum/asset/assets = get_asset_datum(/datum/asset/simple/starmap)
		assets.send(user)
		ui = new(user, src, ui_key, "astrometrics", name, 800, 660, master_ui, state)
		ui.open()

/**
Clean override of the navigation computer to provide scan functionality.
*/

/obj/machinery/computer/ship/navigation/astrometrics/ui_data(mob/user)
	var/list/data = ..()
	var/list/info = SSstar_system.ships[linked]
	var/datum/star_system/current_system = info["current_system"]
	if(scan_target)
		data["scan_target"] = scan_target.name
	if(screen == 2) // Here's where the magic happens.
		data["star_id"] = "\ref[selected_system]"
		data["star_name"] = selected_system.name
		data["alignment"] = capitalize(selected_system.alignment)
		data["scanned"] = FALSE
		if(info["current_system"])
			data["star_dist"] = info["current_system"].dist(selected_system)
			data["can_scan"] = is_in_range(current_system, selected_system)
			data["can_cancel"] = (scan_target) ? TRUE : FALSE
		if(LAZYFIND(scanned, selected_system.name)) //If we've scanned this one before, get me the list of its anomalies.
			data["anomalies"] = selected_system.get_info()
			data["scanned"] = TRUE
	data["scan_progress"] = scan_progress
	data["scan_goal"] = scan_goal
	return data

/obj/machinery/computer/ship/navigation/astrometrics/is_in_range(datum/star_system/current_system, datum/star_system/system)
	return current_system && current_system.dist(system) <= max_range

/obj/machinery/computer/ship/navigation/astrometrics/is_visited(datum/star_system/system)
	return LAZYFIND(scanned, system.name)

/obj/machinery/computer/ship/navigation/astrometrics/ui_act(action, params, datum/tgui/ui)
	if(..())
		return
	if(!has_overmap())
		return
	switch(action)
		if("scan")
			scan_target = selected_system
			radio.talk_into(src, "Commencing scan of: [scan_target]", channel)
		if("scan_anomaly")
			var/obj/effect/overmap_anomaly/target = locate(params["anomaly_id"])
			if(!istype(target))
				return
			scan_target = target
			radio.talk_into(src, "Commencing scan of: [scan_target]", channel)
		if("cancel_scan")
			radio.talk_into(src, "Scan of [scan_target] halted!", channel)
			scan_progress = 0
			scan_target = null

/obj/machinery/computer/ship/navigation/astrometrics/process()
	if(scan_target)
		scan_progress += 1 SECONDS
		if(scan_progress >= scan_goal)
			radio.talk_into(src, "Scan of [scan_target] complete!", channel)
			scanned += scan_target.name
			if(istype(scan_target, /obj/effect/overmap_anomaly))
				var/obj/effect/overmap_anomaly/OA = scan_target
				var/reward = OA.research_points/2
				OA.research_points -= reward
				OA.scanned = TRUE
				linked_techweb.add_point_type(TECHWEB_POINT_TYPE_DEFAULT, reward)
			scan_target = null
			scan_progress = 0
			return