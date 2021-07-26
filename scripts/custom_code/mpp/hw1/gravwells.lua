-- By: Fear
-- Readable stock code!
-- Also plays glow effect on trapped ships.

--- Stuff for gw generators (hw1)
---@class GravwellProto : Ship
gravwell_proto = {
	effect_range = 3000,
	own_effect = "PowerUp",
	stun_effect = "PowerOff",
	stunnable_ships = {},
	damage_per_cycle = 0.02,
	active = 0,
};

--- Calculates the group of ships which are stunnable (strikecraft and in range).
---
---@return table
function gravwell_proto:calculateStunnables()
	self.stunnable_ships = GLOBAL_SHIPS:filter(
		function (ship)
			local in_range = %self:distanceTo(ship) < %self.effect_range;
			local is_stunnable_type = ship:isFighter() or ship:isCorvette();
			local is_salvette = ship:isSalvager();

			return in_range and is_stunnable_type and not is_salvette;
		end
	);
	return self.stunnable_ships;
end

--- Stuns or unstuns any ships gathered via `self:calculateStunnables`.
---
---@param stunned integer
---@return table
function gravwell_proto:setStunnablesStunned(stunned)
	for _, ship in self.stunnable_ships do
		ship:stunned(stunned);
	end
	return self.stunnable_ships;
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
	self:setStunnablesStunned(0);	-- free any captured if we have any
	self:ownEffects(0);				-- re-enable hyperspace etc.
	self.active = 0;
end

--- Stuff that only AI-controlled gravwells should do.
--- Causes the gravwell to automatically activate under certain conditions.
function gravwell_proto:AIOnly()
	if (self.player():isHuman() == nil) then
		local stunnables = self:calculateStunnables();
		local friendlies = modkit.table.filter(stunnables, function (ship)
			return ship.player():alliedWith(%self.player()) == 1;
		end);
		local enemies = modkit.table.filter(stunnables, function (ship)
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
	self:setStunnablesStunned(0)	-- free previous runs ships
	self:calculateStunnables()		-- calculate new ships to stun
	self:setStunnablesStunned(1)	-- stun those guys
	self:ownEffects(1)				-- play blue glow on self, inflict self damage, disable own hyperspace, etc
end

function gravwell_proto:finish()
	self:cleanUp();
end

modkit.compose:addShipProto("kus_gravwellgenerator", gravwell_proto);
modkit.compose:addShipProto("tai_gravwellgenerator", gravwell_proto);