#define COMSIG_LOOPINGSOUND_PLAYED "loop_played"
#define COMSIG_FTL_STATE_CHANGE "ftl_state_change"
#define COMSIG_MOB_ITEM_EQUIPPED "mob_item_equipped" //Used for aiming component, tells you when a mob equips ANY item
#define COMSIG_MOB_ITEM_DROPPED "mob_item_dropped"

// Ship targeting signals
#define COMSIG_TARGET_PAINTED "target_painted" //! from base of /obj/structure/overmap/proc/finish_lockon: (target, data_link_origin)
#define COMSIG_TARGET_LOCKED "target_locked" //! from base of /obj/structure/overmap/proc/select_target: (target)
#define COMSIG_LOCK_LOST "lock_lost" //! from base of /obj/structure/overmap/proc/dump_lock: (target)

#define COMSIG_SHIP_RELEASE_BOARDING "release_boarding"
	#define COMSIG_SHIP_BLOCKS_RELEASE_BOARDING 1
