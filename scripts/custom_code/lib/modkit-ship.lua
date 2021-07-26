---@class ShipAttribs : Attribs
---@field _stunned number
---@field _ab_targets table
---@field _current_dmg_mult number
---@field _current_tumble Vec3
---@field _despawned_at_volume string
---@field _reposition_volume string
---@field _default_vol string

---@class Ship : Base, ShipAttribs
modkit_ship = {
	---@param g string
	---@param p integer
	---@param s integer
	---@return ShipAttribs
	attribs = function (g, p, s)
		return {
			_stunned = 0,
			_ab_targets = {},
			_current_dmg_mult = 1,
			_current_tumble = { 0, 0, 0 },
			_despawned_at_volume = "despawn-vol-" .. s,
			_reposition_volume = "reposition-vol-" .. s,
			_default_vol = "vol-default-" .. s,
		};
	end
};

-- === Util ===

function modkit_ship:age()
	return (Universe_GameTime() - self.created_at);
end

function modkit_ship:HP(hp)
	if (hp) then
		SobGroup_SetHealth(self.own_group, hp);
	end
	return SobGroup_GetHealth(self.own_group);
end

function modkit_ship:speed(speed)
	if (speed) then
		SobGroup_SetSpeed(self.own_group, speed);
	end
	return SobGroup_GetSpeed(self.own_group);
end

function modkit_ship:actualSpeed()
	return SobGroup_GetActualSpeed(self.own_group);
end

--- Returns the ship's current position (or the center position of the ship's batch squad).
---
---@param pos Position
---@return Position
function modkit_ship:position(pos)
	if (pos) then
		SobGroup_SetPosition(self.own_group, pos);
	end
	return SobGroup_GetPosition(self.own_group);
end

function modkit_ship:tumble(tumble)
	if (tumble) then
		if (type(tumble) == "table") then
			SobGroup_Tumble(self.own_group, tumble);
			for k, v in tumble do
				self._current_tumble[k] = v;
			end
		elseif (tumble == 0) then -- pass 0 to call _ClearTumble
			SobGroup_ClearTumble(self.own_group);
		end
	end
	return self._current_tumble;
end

function modkit_ship:damageMult(mult)
	if (mult) then
		local restore_mult = (-1 * self._current_dmg_mult) + 2;
		SobGroup_SetDamageMultiplier(self.own_group, restore_mult); -- clear previous
		self._current_dmg_mult = mult;
		SobGroup_SetDamageMultiplier(self.own_group, self._current_dmg_mult);
	end
	return self._current_dmg_mult;
end

function modkit_ship:maxActualHP()
	return SobGroup_MaxHealthTotal(self.own_group);
end

function modkit_ship:currentActualHP()
	return SobGroup_CurrentHealthTotal(self.own_group);
end

function modkit_ship:subsHP(subs_name, HP)
	if (HP) then
		SobGroup_SetHardPointHealth(self.own_group, subs_name, HP);
	end
	return SobGroup_GetHardPointHealth(self.own_group, subs_name);
end

function modkit_ship:distanceTo(other)
	if (type(other.own_group) == "string") then -- assume ship
		return SobGroup_GetDistanceToSobGroup(self.own_group, other.own_group);
	else -- a position
		local a = self:position();
		local b = other;
		return sqrt(
			(b[1] - a[1]) ^ 2 +
			(b[2] - a[2]) ^ 2 +
			(b[3] - a[3]) ^ 2
		);
	end
end

--- Returns the squad (batch) size of the ship, which may be a squadron.
---
---@return integer
function modkit_ship:squadSize()
	return SobGroup_Count(self.own_group);
end

function modkit_ship:buildCost()
	return SobGroup_GetStaticF(self.type_group, "buildCost") / self:squadSize();
end

function modkit_ship:buildTime()
	return SobGroup_GetStaticF(self.type_group, "buildTime");
end

-- === Commands ===

function modkit_ship:customCommand(target)
	if (target) then
		return SobGroup_CustomCommandTargets(self.own_group);
	else
		return SobGroup_CustomCommand(self.own_group);
	end
end

function modkit_ship:attack(other)
	return SobGroup_Attack(self.player().id, self.own_group, other.own_group);
end

function modkit_ship:attackPlayer(player)
	return SobGroup_AttackPlayer(self.own_group, player.id);
end

function modkit_ship:move(where)
	if (type(where) == "string") then -- a volume
		SobGroup_Move(self.player().id, self.own_group, where);
	else -- a position
		Volume_AddSphere(self._default_vol, where, 1);
		SobGroup_Move(self.player().id, self.own_group, self._default_vol);
		Volume_Delete(self._default_vol);
	end
end

function modkit_ship:guard(other)
	return SobGroup_GuardSobGroup(self.own_group, other.own_group);
end

function modkit_ship:parade(other, mode)
	mode = mode or 0;
	return SobGroup_ParadeSobGroup(self.own_group, other.own_group, mode);
end

function modkit_ship:dock(target, stay_docked)
	if (target == nil) then -- if no target, target = closest ship
		local all_our_production_ships = GLOBAL_SHIPS:filter(function (ship)
			return ship.player().id == %self.player().id and ship:canDoAbility(AB_AcceptDocking);
		end);
		sort(all_our_production_ships, function (ship_a, ship_b)
			return %self:distanceTo(ship_a) < %self:distanceTo(ship_b);
		end);
		target = all_our_production_ships[1];
	end
	if (stay_docked) then
		SobGroup_DockSobGroupAndStayDocked(self.own_group, target.own_group);
	else
		SobGroup_DockSobGroup(self.own_group, target.own_group);
	end
end

--- Launches this ship from another ship, `from`. If `from` is not provided, this function will
--- attempt to find the ship which `ship` is docked with.
---
---@param from? Ship
---@return nil
function modkit_ship:launchFrom(from)
	if (from == nil) then -- need to discover which ship we're docked with
		for _, ship in GLOBAL_SHIPS:all() do
			if (ship.player():alliedWith(self.player())) then
				if (self:docked(ship) == 1) then
					from = ship;
				end
			end
		end
	else
		return SobGroup_Launch(self.own_group, from.own_group);
	end
end

--- Launches this ship from another ship, `docked`. This ship must be docked with `docked`, or nothing happens.
--- If `docked` is not provided, this function attempts to find the ship which this ship is docked with.
---
---@param docked Ship
---@return nil
function modkit_ship:launch(docked)
	if (docked == nil) then
		for _, ship in GLOBAL_TEAMS:all() do
			if (ship.player:alliedWith(self.player())) then
				if (ship:docked(self) == 1) then
					docked = ship;
				end
			end
		end
	end
end

--- Returns the 3-character race string of the ship.
--- **Note: This is the host race of the _ship type_, as opposed to the player's race.**
---
---@return string
function modkit_ship:race()
	return strsub(self.type_group, 0, 3);
end

-- === Attack family queries ===

function modkit_ship:attackFamily()
	if (attackFamily == nil) then
		dofilepath("data:scripts/familylist.lua");
	end
	for i, family in attackFamily do
		if (SobGroup_AreAnyFromTheseAttackFamilies(self.own_group, family.name) == 1) then
			return strlower(family.name);
		end
	end
end

function modkit_ship:isAnyFamilyOf(families)
	for k, v in families do
		if (self:attackFamily() == v) then
			return 1;
		end
	end
end

function modkit_ship:isFighter()
	return self:isAnyFamilyOf({
		"fighter",
		"fighter_hw1"
	});
end

function modkit_ship:isCorvette()
	return self:isAnyFamilyOf({
		"corvette",
		"corvette_hw1"
	});
end

function modkit_ship:isFrigate()
	return self:isAnyFamilyOf({
		"frigate"
	});
end

function modkit_ship:isCapital()
	return self:isAnyFamilyOf({
		"smallcapitalship",
		"bigcapitalship",
		"mothership"
	});
end

-- === Ship type queries ===

function modkit_ship:isAnyTypeOf(ship_types)
	for k, v in ship_types do
		if (self.type_group == v) then
			return v;
		end
	end
end

function modkit_ship:isSalvager()
	return self:isAnyTypeOf({
		"tai_salvagecorvette",
		"kus_salvagecorvette"
	});
end

function modkit_ship:isDestroyer()
	return self:isAnyTypeOf({
		"hgn_destroyer",
		"vgr_destroyer",
		"kus_destroyer",
		"tai_destroyer"
	});
end

function modkit_ship:isCruiser()
	return self:isAnyTypeOf({
		"hgn_battlecruiser",
		"vgr_battlecruiser",
		"kus_heavycruiser",
		"tai_heavycruiser"
	});
end

function modkit_ship:isCarrier()
	return self:isAnyTypeOf({
		"hgn_carrier",
		"vgr_carrier",
		"kus_carrier",
		"tai_carrier"
	});
end

function modkit_ship:isMothership()
	return self:isAnyTypeOf({
		"hgn_mothership",
		"vgr_mothership",
		"kus_mothership",
		"tai_mothership"
	});
end

function modkit_ship:isProbe()
	return self:isAnyTypeOf({
		"hgn_probe",
		"hgn_ecmprobe",
		"hgn_proximitysensor",
		"vgr_probe",
		"vgr_probe_ecm",
		"kus_probe",
		"kus_proximitysensor",
		"tai_probe",
		"tai_proximitysensor"
	});
end

function modkit_ship:isResearchShip()
	return self:isAnyTypeOf({
		"kus_researchship",
		"kus_researchship_1",
		"kus_researchship_2",
		"kus_researchship_3",
		"kus_researchship_4",
		"kus_researchship_5",
		"tai_researchship",
		"tai_researchship_1",
		"tai_researchship_2",
		"tai_researchship_3",
		"tai_researchship_4",
		"tai_researchship_5"
	});
end

function modkit_ship:isResourceCollector()
	return self:isAnyTypeOf({
		"hgn_resourcecollector",
		"vgr_resourcecollector",
		"kus_resourcecollector",
		"tai_resourcecollector"
	});
end

-- === State queries ===

--- Get or set the stunned status of the ship.
-- Returns whether or not the ship should currently be stunned (if stunned previously via :stunned)
function modkit_ship:stunned(stunned)
	if (stunned ~= nil) then
		self._stunned = stunned;
	end
	SobGroup_SetGroupStunned(self.own_group, stunned);
	return self._stunned;
end

--- Returns whether or not this ship is docked with anything. Optionally, checks if this ship is docked with a specific ship.
---@param with Ship
---@return '0'|'1'
function modkit_ship:docked(with)
	if (with) then
		return SobGroup_IsDockedSobGroup(self.own_group, with.own_group);
	end
	return SobGroup_IsDocked(self.own_group);
end

--- Returns 
---@param target Ship
---@return '1'|'nil'|Ship[]
function modkit_ship:attacking(target)
	local targets_group = SobGroup_Fresh("targets-group-" .. self.id .. "-" .. COMMAND_Attack);
	SobGroup_GetCommandTargets(targets_group, self.own_group, COMMAND_Attack);
	if (target) then
		return SobGroup_GroupInGroup(target.own_group, targets_group) == 1;
	else
		local targets = {};
		for _, ship in GLOBAL_SHIPS:all() do
			if (self:attacking(ship)) then
				targets[ship.id] = ship;
			end
		end
		return targets;
	end
end

function modkit_ship:beingCaptured()
	return SobGroup_AnyBeingCaptured(self.own_group);
end

function modkit_ship:allInRealSpace()
	return SobGroup_AreAllInRealSpace(self.own_group);
end

function modkit_ship:allInHyperSpace()
	return SobGroup_AreAllInHyperspace(self.own_group);
end

-- === Ability stuff ===

function modkit_ship:canDoAbility(ability, enable)
	enable = enable or SobGroup_CanDoAbility(self.own_group, ability);
	SobGroup_AbilityActivate(self.own_group, ability, enable);
	return SobGroup_CanDoAbility(self.own_group, ability);
end

function modkit_ship:canHyperspace(enable)
	return self:canDoAbility(AB_Hyperspace, enable);
end

function modkit_ship:canHyperspaceViaGate(enable)
	return self:canDoAbility(AB_HyperspaceViaGate, enable);
end

function modkit_ship:canBuild(enable)
	return self:canDoAbility(AB_Builder, enable);
end

--- Returns `1` is this ship is performing `ability` (one of the `AB_` global ability codes).
---
---@param ability integer
---@return '0'|'1'
function modkit_ship:isDoingAbility(ability)
	return SobGroup_IsDoingAbility(self.own_group, ability);
end

--- Returns `1` if this ship is performing any ability in `abilities`, else `0`.
---
---@param abilities table
---@return '0'|'1'
function modkit_ship:isDoingAnyAbilities(abilities)
	return modkit.table.any(abilities, function (ability)
		return %self:isDoingAbility(ability) == 1;
	end) or 0;
end

function modkit_ship:isDocking()
	return self:isDoingAbility(AB_Dock);
end

function modkit_ship:isBuilding(ship_type)
	return SobGroup_IsBuilding(self.own_group, ship_type);
end

-- === FX stuff ===

function modkit_ship:startEvent(which)
	FX_StartEvent(self.own_group, which);
end

function modkit_ship:stopEvent(which)
	FX_StopEvent(self.own_group, which);
end

function modkit_ship:playEffect(name)
	FX_PlayEffect(name, self.own_group, 1);
end

function modkit_ship:madState(animation_name)
	SobGroup_SetMadState(self.own_group, animation_name);
end

-- === Spawning ===

--- Causes this previously despawned ship to respawn at the last place it despawned, unless a new volume is given.
--- You can pass a position instead of a volume, in which case a new volume is created at that position.
--- Returns the name of the despawn volume 
---
---@param spawn integer
---@param volume? string | table
---@return string
function modkit_ship:spawn(spawn, volume)
	volume = volume or self._despawned_at_volume;
	if (type(volume) == "table") then -- if 'volume' is a {x, y, z} position
		volume = Volume_Fresh(self._despawned_at_volume, volume); -- create a volume from it
	end
	if (spawn == 1) then
		SobGroup_Spawn(self.own_group, volume);
		Volume_Delete(self._despawned_at_volume);
	elseif (spawn == 0) then
		self._despawned_at_volume = Volume_Fresh(volume, self:position());
		SobGroup_Despawn(self.own_group);
	end
	return self._despawned_at_volume;
end

--- Spawns a new ship at `position`
---@param type any
---@param position? any
---@param spawn_group? string
---@return string
function modkit_ship:spawnShip(type, position, spawn_group)
	position = position or self:position();
	spawn_group = spawn_group or SobGroup_Fresh("spawner-group-" .. self.id);
	local volume_name = Volume_Fresh("spawner-vol-" .. self.id, position);
	SobGroup_SpawnNewShipInSobGroup(self.player().id, type, "-", spawn_group, volume_name);
	Volume_Delete(volume_name);
	return spawn_group;
end

--- Causes this ship to produce a new ship of the given `type`, if it can do so.
--- The created ship is available through a temporary group (`spawn_group`).
--- **Note: The temporary group returned should be functionally equivalent to `own_group` of a more typically
--- available ship, but is _not_ the same group (it should only contain the same ships).**
---
---@param type string
---@param spawn_group? string
---@return string
function modkit_ship:produceShip(type, spawn_group)
	spawn_group = spawn_group or SobGroup_Fresh("spawner-group-" .. self.id);
	local mixed = SobGroup_Fresh(self.own_group .. "-temp-spawner-group");
	SobGroup_Create(mixed, type);
	SobGroup_FillSubstract(spawn_group, mixed, self.own_group);
	return spawn_group;
end

modkit.compose:addBaseProto(modkit_ship);

print("go fancy");