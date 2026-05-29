local PlayerAnimator = require(game:GetService("ReplicatedStorage"):WaitForChild("PlayerAnimator"))
local Humanoid = script.Parent:WaitForChild("Humanoid",3)
local Animator = PlayerAnimator.newClient(Humanoid)
local TestSite = workspace:WaitForChild("AnimatorTest",3)

local ReplicatedTrack = Animator:LoadAnimation(workspace.AnimatorTest.dance, true, nil)
local Track = Animator:LoadAnimation(workspace.AnimatorTest.dance, nil, nil)

local function clicker(whoClicked: Player, Play: boolean, Replicate: boolean?)
	if whoClicked ~= game:GetService("Players").LocalPlayer then return end
	if Play then
		if Replicate then
			Animator:Play(ReplicatedTrack, nil, nil, nil, true)
		else
			Animator:Play(Track, nil, nil, nil, true)
		end
	else
		if Replicate then
			Animator:Stop(ReplicatedTrack)
		else
			Animator:Stop(Track)
		end
	end
end

TestSite:WaitForChild("client"):WaitForChild("ClickDetector").MouseClick:Connect(function(whoClicked: Player)
	clicker(whoClicked, true, true)
end)
TestSite:WaitForChild("clientER"):WaitForChild("ClickDetector").MouseClick:Connect(function(whoClicked: Player)
	clicker(whoClicked, true)
end)

TestSite:WaitForChild("stop"):WaitForChild("ClickDetector").MouseClick:Connect(function(whoClicked: Player)
	clicker(whoClicked, false)
	clicker(whoClicked, false, true)
end)