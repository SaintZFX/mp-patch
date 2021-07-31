-- By: Fear
-- Readable stock code!
-- Also plays glow effect on trapped ships.

---@class GravwellAttribs
---@field stunnable_ships Ship[]
---@field active '0'|'1'
---@field tumble_index integer

--- Stuff for gw generators (hw1)
---@class GravwellProto : Ship, GravwellAttribs
gravwell_proto = {
	effect_range = 2900,
	own_effect = "PowerUp",
	stun_effect = "PowerOff",
	damage_per_cycle = 0.02,
	random_tumbles = { -- .3 - .8, random signs
		{-0.37, 0.60, 0.60},
		{-0.64, -0.71, -0.60},
		{-0.58, 0.79, 0.36},
		{-0.63, -0.39, -0.45},
		{0.54, 0.75, 0.49},
		{-0.45, 0.79, -0.36},
		{-0.51, -0.66, -0.34},
		{-0.41, -0.60, -0.30},
		{-0.31, 0.55, 0.62},
		{0.34, -0.72, -0.76},
		{-0.51, 0.56, -0.32},
		{-0.67, -0.47, -0.39},
		{-0.60, -0.69, 0.45},
		{-0.54, 0.76, -0.58},
		{0.44, -0.33, -0.72},
		{-0.31, 0.55, -0.38},
	},
	attribs = function ()
		return {
			stunnable_ships = {},
			active = 0,
			tumble_index = 0
		};
	end
};

--- Removes dead references
function gravwell_proto:pruneDeadStunnables()
	for i, ship in self.stunnable_ships do
		if (ship:HP() <= 0 or ship:alive() == nil) then
			self.stunnable_ships[i] = nil;
		end
	end
end

--- Gets the currently indexed tumble vector. Increments the index after.
---
---@return Vec3
function gravwell_proto:nextTumble()
	local tumble = self.random_tumbles[self.tumble_index];
	self.tumble_index = self.tumble_index + 1;
	if (self.tumble_index > modkit.table.length(self.random_tumbles)) then
		self.tumble_index = 1;
	end
	return tumble;
end

--- Calculates the group of ships which are stunnable (strikecraft and in range).
---
---@return Ship[]
function gravwell_proto:calculateNewStunnables()
	local new_stunnables = GLOBAL_SHIPS:strike(function (ship)
		return ship:alive() and ship:isSalvager() == nil and ship:distanceTo(%self) < %self.effect_range;
	end);
	local new_stunnables_count = modkit.table.reduce(new_stunnables, function (acc, ship)
		return acc + (ship:count() / ship:batchSize());
	end, 0);
	local old_stunnables_count = modkit.table.reduce(self.stunnable_ships, function (acc, ship)
		return acc + (ship:count() / ship:batchSize());
	end, 0);
	-- modkit.table.printTbl(modkit.table.map(new_stunnables, function (ship) return ship.own_group; end), "new stunnables");
	-- modkit.table.printTbl(modkit.table.map(self.stunnable_ships, function (ship) return ship.own_group; end), "old stunnables");
	if (old_stunnables_count > new_stunnables_count) then
		local ships_to_unstun = modkit.table.filter(self.stunnable_ships, function (ship)
			return ship:alive() and ship:distanceTo(%self) >= %self.effect_range - 10;
		end);
		self:tumbleStunned(0, ships_to_unstun);
		self:setStunnablesStunned(0, ships_to_unstun);
		self.stunnable_ships = new_stunnables;
	else
		self.stunnable_ships = new_stunnables;
	end
end

--- Stuns or unstuns any ships gathered via `self:calculateStunnables`.
---
---@param stunned '0'|'1'
---@return Ship[]
function gravwell_proto:setStunnablesStunned(stunned, specific_ships)
	for _, ship in (specific_ships or self.stunnable_ships) do
		ship:stunned(stunned);
		if (stunned == 1) then
			ship:speed(0);
		else
			ship:speed(1);
		end
	end
	return self.stunnable_ships;
end


--- Applies a pre-genned tumble vector to stunned ships.
---
---@param override '0'|Vec3
function gravwell_proto:tumbleStunned(override, specific_ships)
	for _, ship in (specific_ships or self.stunnable_ships) do
		if (ship:tumble()[1] == 0) then -- we have no tumble
			ship:tumble(override or self:nextTumble());
		end
	end
end

--- Applies self damage, disables hyperspace, and plays the blue glow.
---
---@param apply integer
function gravwell_proto:ownEffects(apply)
	local ab_enabled = max(apply + 1, 2);
	self:canHyperspace(ab_enabled);
	self:canHyperspaceViaGate(ab_enabled);
	if (apply == 1) then
		self:HP(self:HP() - self.damage_per_cycle);
		self:startEvent(self.own_effect);
	else
		self:stopEvent(self.own_effect);
	end
end

--- Unstuns any ships previously trapped, and undoes any effects lasting from previous `self:ownEffects` calls.
function gravwell_proto:cleanUp()
	self:tumbleStunned(0);
	self:calculateNewStunnables();
	self:setStunnablesStunned(0);	-- free any captured if we have any
	self:ownEffects(0);				-- re-enable hyperspace etc.
	self.active = 0;
end

--- Stuff that only AI-controlled gravwells should do.
--- Causes the gravwell to automatically activate under certain conditions.
function gravwell_proto:AIOnly()
	if (self.player():isHuman() == nil) then
		self:calculateNewStunnables();
		local friendlies = modkit.table.filter(self.stunnable_ships, function (ship)
			return ship.player():alliedWith(%self.player()) == 1;
		end);
		local enemies = modkit.table.filter(self.stunnable_ships, function (ship)
			return ship.player():alliedWith(%self.player()) == 0;
		end);

		if (modkit.table.length(enemies) > 0) then
			-- ru value totals of friendlies and enemies
			local friendlies_value = modkit.table.reduce(friendlies, function (acc, ship)
				return acc + ship:buildCost();
			end, 0);
			local enemies_value = modkit.table.reduce(enemies, function (acc, ship)
				return acc + ship:buildCost();
			end, 0);

			-- if any condition here passes, ability will activate
			local activation_conditions = {
				-- trappable enemies value >= 20% more than friendlies value
				good_value = function ()
					return %enemies_value >= 1.2 * %friendlies_value;
				end,
				-- if nearby two or more collectors (simulating collectors are under threat or attack)
				near_our_collectors = function ()
					local outer_self = %self;
					local our_nearby_collectors = GLOBAL_SHIPS:filter(function (ship)
						return ship.player().id == %outer_self.player().id
							and ship:isResourceCollector()
							and %outer_self:distanceTo(ship) < %outer_self.effect_range * 1.1;
					end);
					return modkit.table.length(our_nearby_collectors) > 2; -- enemies being present is already a given
				end
			};

			local none_passed = 1;
			for name, condition in activation_conditions do
				if (condition() ~= nil) then -- passed
					none_passed = nil;
					if (self.active == 0) then
						self:customCommand();
						break;
					end
				end
			end
			if (none_passed and self.active == 1) then
				self:customCommand();
			end
		end
	end
end

-- === hooks ===

function gravwell_proto:update()
	self:AIOnly();
end

function gravwell_proto:destroy()
	self:cleanUp();
end

function gravwell_proto:start()
	self.active = 1;
end

function gravwell_proto:go()
	self:calculateNewStunnables()	-- calculate new ships to stun
	self:setStunnablesStunned(1)	-- stun those guys
	self:tumbleStunned();
	self:ownEffects(1)				-- play blue glow on self, inflict self damage, disable own hyperspace, etc
end

function gravwell_proto:finish()
	self:cleanUp();
end

function gravwell_proto:destroy()
	self:cleanUp();
end

modkit.compose:addShipProto("kus_gravwellgenerator", gravwell_proto);
modkit.compose:addShipProto("tai_gravwellgenerator", gravwell_proto);