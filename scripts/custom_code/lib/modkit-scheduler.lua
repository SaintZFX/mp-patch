modkit_scheduler_proto = {};

function modkit_scheduler_proto:update()
	modkit.scheduler:update();
end

modkit.compose:addShipProto("modkit_scheduler", modkit_scheduler_proto);