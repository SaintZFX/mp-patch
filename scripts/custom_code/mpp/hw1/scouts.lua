---@class ScoutAttribs
---@field current_speed number
---@field decay_event_id integer

---@class scouts_proto : Ship, ScoutAttribs
scouts_proto = {
	boost_range = {
		min = 1.05,
		max = 4
	},
	attribs = function ()
		return {
			current_speed = 1,
			decay_event_id = nil
		}
	end
};

function scouts_proto:start()
	self.current_speed = self:speed(4);
	-- FX_PlayEffect("speed_burst_flash", CustomGroup, 1.5)
	self:playEffect("speed_burst_flash", 1.5);
end

function scouts_proto:go()
	self.decay_event_id = modkit.scheduler:every(3, function () -- use this to test if scheduler is responsible for sync
		if (%self.current_speed > %self.boost_range.min) then
			%self.current_speed = %self:speed(max(%self.current_speed - 0.5, %self.boost_range.min));
		end
	end)
end

function scouts_proto:finish()
	self.current_speed = self:speed(1);
	modkit.scheduler:clear(self.decay_event_id);
end

modkit.compose:addShipProto("kus_scout", scouts_proto);
modkit.compose:addShipProto("tai_scout", scouts_proto);