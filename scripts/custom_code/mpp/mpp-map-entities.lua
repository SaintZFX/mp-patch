-- Proto for any ships which are captured by salcaps via latching and waiting instead of dragging the ship.

---@class DreadnaughtProto : Ship
mpp_dreadnaught_proto = {};

function mpp_dreadnaught_proto:ensureVisible()
	if (self:visibility() ~= VisFull) then
		self:visibility(VisFull);
	end
end

function mpp_dreadnaught_proto:ownerSpecificBehavior()
	if (self.player.id == -1) then 				-- owned by env
		if (self:tumble()[1] == 0) then
			self:tumble({0.45, 0.45, 0.45});
		end
		self:canDoAbility(AB_Targeting, 0);
		self:canDoAbility(AB_Attack, 0);
	else 										-- owned by a player
		if (self:tumble()[1] ~= 0) then
			self:tumble(0);
		end
		self:canDoAbility(AB_Targeting, 1);
		self:canDoAbility(AB_Attack, 1);
	end
end

function mpp_dreadnaught_proto:update()
	-- ensure visible to all
	if (self:tick() == 1) then
		SobGroup_SetCaptureState(self.own_group, 0);
		self:ensureVisible();

		-- modkit.table.printTbl(GLOBAL_SHIPS:all(), "global ships report");
	end
	-- behavior for owners:
	self:ownerSpecificBehavior();
end

modkit.compose:addShipProto("mpp_dreadnaught", mpp_dreadnaught_proto);


--- ====

---@class MoverProto : Ship
---@field dreadnaught DreadnaughtProto
mpp_mover_proto = {};

function mpp_mover_proto:start()
	self:print("hi");

	self.dreadnaught = self.dreadnaught or GLOBAL_SHIPS:find(function (ship)
		return ship.type_group == "mpp_dreadnaught";
	end);


	self.dreadnaught:capturableModifier(1);
	self:canDoAbility(AB_Capture, 1);
	self:capture(self.dreadnaught);
	self:canDoAbility(AB_Capture, 0);
	self.dreadnaught:capturableModifier(0);
end

modkit.compose:addShipProto("mpp_mover", mpp_mover_proto);

-- =====

---@class MoverSpawnerProto : Ship
mpp_mover_spawner_proto = {
	max_movers = 10
};

function mpp_mover_spawner_proto:spawnNewMover()
	local new_mover_group = self:spawnShip("mpp_mover", self:position());
	SobGroup_SetGhost(new_mover_group, 1);
	local move_to = self:position();
	for i, _ in move_to do
		if (i ~= 2) then
			move_to[i] = move_to[i] + 700;
		else
			move_to[i] = move_to[i] - 200;
		end
	end
	SobGroup_Move(self.player.id, new_mover_group, Volume_Fresh("mover-vol-" .. self.id .. "-" .. self:tick(), move_to));
	modkit.scheduler:every(5, function (event)
		if (SobGroup_GetDistanceToSobGroup(%self.own_group, %new_mover_group) > 300) then
			SobGroup_SetGhost(%new_mover_group, 0);
			modkit.scheduler:clear(event.id);
		end
	end);
end

function mpp_mover_spawner_proto:update()
	-- if spawner process not running, set it up for every 30s
	if (self.spawner_proc == nil) then
		self:visibility(VisFull);
		self:print("no spawner proc, let's launch it (interval: " .. 30 / modkit.scheduler.seconds_per_tick .. ")!\t[" .. Universe_GameTime() .. "]");
		self.spawner_proc = modkit.scheduler:every(30 / modkit.scheduler.seconds_per_tick, function ()
			local outer_self = %self;
			local our_movers = modkit.table.filter(GLOBAL_SHIPS:corvettes(), function (ship)
				return ship.type_group == "mpp_mover" and %outer_self.player.id == ship.player.id;
			end);
			if (modkit.table.length(our_movers) < mpp_mover_spawner_proto.max_movers) then
				%self:spawnNewMover();
			end
		end);
	end

	if (self:tick() == 10) then -- wait a second to let gamerule tidy up dead guys...
		-- dirty hack to resolve ownership issues of the second spawner in variable player games
		if (self.player.id ~= 0) then
			---@type Player
			--- the lowest index teammate = ceil(total players / 2)
			--- 2 -> 1, 4 -> 2, 6 -> 3
			local target_player_index = ceil(modkit.table.length(GLOBAL_PLAYERS:alive()) / 2);
			-- if p2 (third player) exists and is alive, swap ownership from p1 to them (its a 4 player game)
			local pN = GLOBAL_PLAYERS:all()[target_player_index];
			if (pN and pN:isAlive() == 1) then
				SobGroup_SwitchOwner(self.own_group, pN.id);
			end
		end
	end
end

modkit.compose:addShipProto("mpp_mover_spawner", mpp_mover_spawner_proto);