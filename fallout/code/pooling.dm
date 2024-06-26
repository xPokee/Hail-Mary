SUBSYSTEM_DEF(pool)
	name = "Pool"
	init_order = 20
	flags = SS_BACKGROUND | SS_FIRE_IN_LOBBY
	var/list/global_pool
	var/list/pool_levels = list()
	var/sum = 0

	var/list/maintained_types = list(
		/obj/item/stack/tile/plasteel = 100
	)

	var/list/stats_placed_in_pool = list()
	var/list/stats_pooled_or_newed = list()
	var/list/stats_reused = list()
	var/list/stats_created_new = list()

/datum/subsystem/pool/New()
	NEW_SS_GLOBAL(SSpool)

/datum/subsystem/pool/Initialize(timeofday)
	global_pool = GlobalPool

/datum/subsystem/pool/stat_entry(msg)
	if(global_pool)
		msg += "Types: [global_pool.len]|Total Pooled Objects: [sum]"
	else
		msg += "NULL POOL"
	..(msg)

/datum/subsystem/pool/fire()
	sum = 0
	for(var/type in global_pool + maintained_types)
		var/list/L = global_pool[type]
		var/required_number = maintained_types[type] || 0

		// Update pool levels and tracker
		var/amount = 0
		if(L)
			amount = L.len
		sum += amount

		// why yes, just inflate the pool at one item per tick
		if(amount < required_number)
			var/diver = new type
			qdel(diver)




/*
/tg/station13 /datum Pool:
---------------------------------
By RemieRichards

Creation/Deletion is laggy, so let's reduce reuse and recycle!

Usage:

To get a object, just call
 - PoolOrNew(type, arg) if you only want to pass one argument to New(), usually loc
 - PoolOrNew(type, list) if you want to pass multiple arguments to New()

To put a object back in the pool, call PlaceInPool(object)
This will call destroy on the object, set its loc to null,
and reset all of its vars to their default

You can override your object's destroy to return QDEL_HINT_PUTINPOOL
to ensure its always placed in this pool (this will only be acted on if qdel calls destroy, and destroy will not get called twice)

For almost all pooling purposes, it is better to use the QDEL hint than to pool it directly with PlaceInPool

*/

var/global/list/GlobalPool = list()

//You'll be using this proc 90% of the time.
//It grabs a type from the pool if it can
//And if it can't, it creates one
//The pool is flexible and will expand to fit
//The new created atom when it eventually
//Goes into the pool

//Second argument can be a single arg
//Or a list of arguments
//Either way it gets passed to new

/proc/PoolOrNew(get_type,second_arg)
	if(islist(second_arg))
		. = new get_type (arglist(second_arg))
	else
		. = new get_type (second_arg)

	return


	if(!get_type)
		return

	if(SSpool)
		INCREMENT_TALLY(SSpool.stats_pooled_or_newed, get_type)

	. = GetFromPool(get_type,second_arg)

	if(!.)
		if(SSpool)
			INCREMENT_TALLY(SSpool.stats_created_new, get_type)
		if(ispath(get_type))
			if(islist(second_arg))
				. = new get_type (arglist(second_arg))
			else
				. = new get_type (second_arg)
	else
		if(SSpool)
			INCREMENT_TALLY(SSpool.stats_reused, get_type)


/proc/GetFromPool(get_type,second_arg)
	if(!get_type)
		return

	if(isnull(GlobalPool[get_type]))
		return

	if(length(GlobalPool[get_type]) == 0)
		return

	var/datum/pooled = pop(GlobalPool[get_type])
	if(pooled)
		pooled.gc_destroyed = null

		var/atom/movable/AM
		if(istype(pooled, /atom/movable))
			AM = pooled

		if(islist(second_arg))
			if(AM)
				AM.forceMove(second_arg[1] )//we need to do loc setting explicetly before even calling New() to replicate new()'s behavior
			pooled.New(arglist(second_arg))

		else
			if(AM)
				AM.forceMove(second_arg)
			pooled.New(second_arg)

		return pooled


/proc/PlaceInPool(datum/diver, destroy = 1)
	qdel(diver)
	return

	if(istype(diver, /obj))
		var/obj/O = diver
		O.forceMove(null)

	if(!istype(diver))
		return

	if(diver in GlobalPool[diver.type])
		return

	if(SSpool)
		INCREMENT_TALLY(SSpool.stats_placed_in_pool, diver.type)

	if(!GlobalPool[diver.type])
		GlobalPool[diver.type] = list()

	GlobalPool[diver.type] |= diver

	if(destroy)
		diver.Destroy()

	diver.gc_destroyed = 1

	diver.ResetVars()

var/list/exclude = list("animate_movement", "contents", "loc", "locs", "parent_type", "vars", "verbs", "type", "gc_destroyed")
var/list/pooledvariables = list()
//thanks to clusterfack @ /vg/station for these two procs
/datum/proc/createVariables()
	pooledvariables[type] = new/list()
	var/list/exclude = global.exclude + args

	for(var/key in vars)
		if(key in exclude)
			continue
		if(!islist(vars[key]))
			pooledvariables[type][key] = initial(vars[key])

/datum/proc/ResetVars()
	if(!pooledvariables[type])
		createVariables(args)

	for(var/key in pooledvariables[type])
		if (!islist(pooledvariables[type][key]))
			vars[key] = pooledvariables[type][key]

/atom/movable/ResetVars()
	..()
	forceMove(null)
	contents = initial(contents) //something is really wrong if this object still has stuff in it by this point

/image/ResetVars()
	..()
	loc = null
