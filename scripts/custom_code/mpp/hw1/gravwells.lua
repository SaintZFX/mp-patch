gravwell_proto = {
	effect_range = 3000,
	own_effect = "PowerUp",
	stun_effect = "PowerOff",
	stunnable_ships = {},
	damage_per_cycle = 0.02
};

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

function gravwell_proto:setStunnablesStunned(stunned)
	for _, ship in self.stunnable_ships do
		ship:stunned(stunned);
	end
	return self.stunnable_ships;
end

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

function gravwell_proto:cleanUp()
	self:setStunnablesStunned(0);	-- free any captured if we have any
	self:ownEffects(0);				-- re-enable hyperspace etc.
end

-- === hooks ===

function gravwell_proto:update()
	-- ai only
	if (self.player:isHuman() == nil) then
		local stunnables = self:calculateStunnables();
		
	end
end

function gravwell_proto:destroy()
	self:cleanUp();
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