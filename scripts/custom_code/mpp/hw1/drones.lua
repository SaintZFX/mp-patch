-- By: Fear
-- Readable stock code.
-- We only use drone0, since we control the parade positions using vertexes of a pre-computed icosahedron (`parade_positions`).
-- These drones are actually capable of firing since the script only issues soft move commands to reposition the drones,
-- unlike the stock code which issues parade commands (which interrupt anything the drone is doing such as orienting, tracking, attcking, etc...)

---@class drones_proto : Ship
local drones_proto = {
	drone_kill_distance = 950,
	parade_positions = {
		{210, 0, 0+10},
		{-210, 0, 0+10},
		{0, 210, 0+10},
		{0, -210, 0+10},
		{0, 0, 210+10},
		{0, 0, -210+10},
		{120, 120, 120+10},
		{-120, 120, 120+10},
		{120, -120, 120+10},
		{-120, -120, 120+10},
		{120, 120, -120+10},
		{-120, 120, -120+10},
		{120, -120, -120+10},
		{-120, -120, -120+10},
		{1050, -525, 700}
	},
	---@type Ship[]
	live_drones = {}
};

--- Returns `nil` if the frigate is not 'ready', meaning it is not capable of fighting with drones.
---
---@return '1'|'nil'
function drones_proto:frigateReady()
	return self:isDoingAbility(AB_Hyperspace) == 0
		and self:allInRealSpace() == 1
		and self:beingCaptured() == 0
		and self:isDoingAnyAbilities({
			AB_Hyperspace,
			AB_HyperspaceViaGate,
			AB_Dock,
			AB_Retire
		}) == 0;
end

--- Causes the 
---@param drone_index any
---@return Position
function drones_proto:droneParadePos(drone_index)
	local parade_pos = {};
	for i, value in self:position() do
		parade_pos[i] = (value + self.parade_positions[drone_index][i]); -- drone x, y, z pos is frigate pos + offsets in table
	end
	return parade_pos;
end

function drones_proto:getTarget()
	local target = self:attacking();
	
end

function drones_proto:produceMissingDrones()
	local missing_drones_count = modkit.table.length(self.parade_positions) - modkit.table.length(self.live_drones);
	for _ = 0, missing_drones_count do
		self:produceShip("kus_drone0");
	end
end

function drones_proto:launchDockedDrones()
	for _, drone in self.live_drones do
		if (drone:docked(self) == 1) then
			self:launch(drone);
		end
	end
end

function drones_proto:attackWithDrones()
	for _, drone in self.live_drones do
		print("drone " .. _.own_group .. " docked?: " .. drone:docked(self));
		if (drone:docked(self) == 0) then
		
		end
	end
end

function drones_proto:positionLaunchedDrones()
	local position_index = 1;
	for _, drone in self.live_drones do
		if (drone:docked(self) == 0) then
			drone:move(self.parade_positions[position_index]);
			position_index = position_index + 1;
		end
	end
end

-- === hooks ===

function drones_proto:update()
	self:produceMissingDrones();
	self:launchDockedDrones();

	self:positionLaunchedDrones();
end

-- function drones_proto:start()
-- end

-- function drones_proto:go()
	
-- end

-- function drones_proto:finish()
-- end