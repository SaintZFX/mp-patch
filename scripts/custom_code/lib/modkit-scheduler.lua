
---@class SchedulerAttribs
---@field init 'nil'|'1'

---@class modkit_scheduler_proto : Ship, SchedulerAttribs
modkit_scheduler_proto = {
	update_globals_interval = 5, -- .5 seconds

	---@alias FilterFn fun(): Ship[]

	---@class SheduledFilters
	---@field corvettes FilterFn
	---@field drones FilterFn
	---@field strike FilterFn

	filters = {
		builders = function (ship)
			return ship:canBuild();
		end,
		fighters = function (ship)
			return ship:isFighter();
		end,
		corvettes = function (ship)
			return ship:isCorvette();
		end,
		frigates = function (ship)
			return ship:isFrigate();
		end,
		capitals = function (ship)
			return ship:isCapital();
		end,
		drones = function (ship)
			return ship:isDrone();
		end,
		strike = function (ship)
			return ship:isFighter() or ship:isCorvette();
		end
	}
};

function modkit_scheduler_proto:collectShips()
	-- print("[" .. Universe_GameTime() .."]: update global lists (refresh is: " .. modkit_scheduler_proto.update_globals_interval .. ")");
	-- loop just once to collect all these
	for _, ship in GLOBAL_SHIPS.cache.newly_created do
		for collection, predicate in modkit_scheduler_proto.filters do
			if (predicate(ship)) then
				GLOBAL_SHIPS.cache[collection][ship.id] = ship;
			end
		end
	end
	GLOBAL_SHIPS.cache.newly_created = {};
end

function modkit_scheduler_proto:beginGlobalLists()
	if (GLOBAL_SHIPS.cache == nil) then
		GLOBAL_SHIPS.cache = {};
	end

	for collection, _ in modkit_scheduler_proto.filters do
		GLOBAL_SHIPS.cache[collection] = {};
		GLOBAL_SHIPS[collection] = function (self, filter_predicate)
			-- print("cached " .. %collection .. ": " .. modkit.table.length(self.cache[%collection]));
			-- print("all drones: " .. modkit.table.length(self:filter(function (ship)
			-- 	return ship:isDrone();
			-- end)))
			if (filter_predicate) then
				-- print("filtered: " .. modkit.table.length(modkit.table.filter(self.cache[%collection], filter_predicate)));
				return modkit.table.filter(self.cache[%collection], filter_predicate);
			end
			return self.cache[%collection];
		end
	end

	-- controls the poll rate for ship collection event
	modkit_scheduler_proto.init_event = modkit_scheduler_proto.init_event or modkit.scheduler:every(
		50,
		function ()
			local global_count = SobGroup_Count(Universe_GetAllActiveShips());
			local new_interval = min(10, ceil(2 + 2 * (global_count / 125))); -- every 125 ships, increase delay by 0.2s, max 1s
			if (new_interval ~= modkit_scheduler_proto.update_globals_interval) then
				modkit_scheduler_proto.update_globals_interval = new_interval;
				if (modkit_scheduler_proto.collect_event) then
					modkit.scheduler:clear(modkit_scheduler_proto.collect_event);
				end
				modkit_scheduler_proto.collect_event = modkit.scheduler:every(
					modkit_scheduler_proto.update_globals_interval,
					modkit_scheduler_proto.collectShips
				);
			end
		end
	);

end

function modkit_scheduler_proto:init()
	if (self._init == nil) then
		self:spawn(0); -- hide the scheduler

		self:beginGlobalLists();

		self._init = 1;
	end
end

-- Called every 0.1 seconds, events subscribed to `modkit.scheduler` can use this to run code faster than their native update rate
function modkit_scheduler_proto:update()
	self:init();
	modkit.scheduler:update();
end

modkit.compose:addShipProto("modkit_scheduler", modkit_scheduler_proto);
