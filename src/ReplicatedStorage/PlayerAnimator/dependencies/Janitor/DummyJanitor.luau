local dummy = {
	Destroy = function()

	end;

	Add = function()
		-- TODO: auto clean up anything here to prevent weird situations
	end;
}

dummy.__index = dummy

return dummy