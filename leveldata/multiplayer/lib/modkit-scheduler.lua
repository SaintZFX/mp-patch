dofilepath("data:scripts/modkit/sobgroup.lua");

function modkit_scheduler_update()
	print("WRAPPER CALL");
	local group = SobGroup_Fresh("modkit__scheduler_controller");
	local volume = Volume_Fresh("modkit__scheduler_controller_vol");
	SobGroup_SpawnNewShipInSobGroup(-1, "modkit_scheduler", group, group, volume);
	print("donezo");
	print(SobGroup_Count(group));
	Rule_Remove("modkit_scheduler_update");
end