-- Ships utility functions

local generic_proto = {};

-- Disable scuttle while a captured unit is being dropped off by salvage corvettes
function generic_proto:noSalvageScuttle()
	self:canDoAbility(AB_Scuttle, 1 - self:isDoingAbility(AB_Dock));
end

function generic_proto:underAttackReissueDock()
	return SobGroup_UnderAttackReissueDock(self.own_group); -- meh
end

modkit.compose:addBaseProto(generic_proto);
