local PlayerAnimator = require(game:GetService("ReplicatedStorage").PlayerAnimator)

local function clicker(whoClicked: Player, Play: boolean)
	if whoClicked and whoClicked.Character and whoClicked.Character:FindFirstChildOfClass("Humanoid") then
		local Humanoid = whoClicked.Character:FindFirstChildOfClass("Humanoid")
		local Animator = PlayerAnimator.newServer(Humanoid)
		local Track = Animator:LoadAnimation(script.Parent.dance, Enum.AnimationPriority.Action4, true)
		if Play then
			Track:Play(nil, nil, nil, true)
		else
			Track:Stop()
		end
	end
end

script.Parent.server.ClickDetector.MouseClick:Connect(function(whoClicked: Player)
	clicker(whoClicked, true)
end)

script.Parent.stop.ClickDetector.MouseClick:Connect(function(whoClicked: Player)
	clicker(whoClicked, false)
end)