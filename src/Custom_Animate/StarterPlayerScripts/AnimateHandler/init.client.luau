--[[
	┌──────────────────────────────────────────────────────────────────────────┐
    │  MIT License                                                             │
    │  Copyright (c) 2026 @NotBlackrus                                         │
    │  Permission is hereby granted, free of charge, to any person obtaining   │
    │  a copy of this software and associated documentation files              │
    │  (the "Software"), to deal in the Software without restriction,          │
    │  including without limitation the rights to use, copy, modify, merge,    │
    │  publish, distribute, sublicense, and/or sell copies of the Software,    │
    │  and to permit persons to whom the Software is furnished to do so,       │
    │  subject to the following conditions:                                    │
    │  The above copyright notice and this permission notice shall be included │
    │  in all copies or substantial portions of the Software.                  │
    │  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS │
    │  OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF              │
    │  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  │
    │  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY    │
    │  CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,    │
    │  TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE       │
    │  SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                  │
	└──────────────────────────────────────────────────────────────────────────┘
]]

local Players = game:GetService("Players")

local module = script.Parent.Parent.Parent --REPLACE WITH MODULE PATH
local net = require(module:WaitForChild("net"))
local PlayerAnimator = require(module)
PlayerAnimator.init()

local Config = module:GetAttributes():: PlayerAnimator.Config

local ugcEmotes = Config.UGC_EMOTES and module:WaitForChild("ugcEmotes", 5) or nil
local function setupCharacterAnimations(Character)
	local Humanoid = Character:WaitForChild("Humanoid") :: Humanoid
	local Animator = PlayerAnimator.newClient(Humanoid)
	local DummyScript = Character:WaitForChild("Animate",3) :: LocalScript
	if not DummyScript then warn("No dummy animate script!") return end
	
	if Humanoid.RigType == Enum.HumanoidRigType.R15 then
		-- humanoidAnimateR15Moods.lua
		local pose = "Standing"

		local userNoUpdateOnLoopSuccess, userNoUpdateOnLoopValue = pcall(function() return UserSettings():IsUserFeatureEnabled("UserNoUpdateOnLoop") end)
		local userNoUpdateOnLoop = userNoUpdateOnLoopSuccess and userNoUpdateOnLoopValue

		local userAnimateScaleRunSuccess, userAnimateScaleRunValue = pcall(function() return UserSettings():IsUserFeatureEnabled("UserAnimateScaleRun") end)
		local userAnimateScaleRun = userAnimateScaleRunSuccess and userAnimateScaleRunValue

		local function getRigScale()
			if userAnimateScaleRun then
				return Character:GetScale()
			else
				return 1
			end
		end

		local AnimationSpeedDampeningObject = DummyScript:FindFirstChild("ScaleDampeningPercent")
		local HumanoidHipHeight = 2

		local EMOTE_TRANSITION_TIME = 0.1

		local currentAnim = ""
		local currentAnimInstance = nil
		local currentAnimTrack = nil
		local currentAnimKeyframeHandler = nil
		local currentAnimSpeed = 1.0

		local runAnimTrack = nil
		local runAnimKeyframeHandler = nil
		
		local PreloadedAnims = {}
		local animTable = {}
		local animNames = { 
			idle = 	{	
				{ id = "http://www.roblox.com/asset/?id=507766666", weight = 1 },
				{ id = "http://www.roblox.com/asset/?id=507766951", weight = 1 },
				{ id = "http://www.roblox.com/asset/?id=507766388", weight = 9 }
			},
			walk = 	{ 	
				{ id = "http://www.roblox.com/asset/?id=507777826", weight = 10 } 
			}, 
			run = 	{
				{ id = "http://www.roblox.com/asset/?id=507767714", weight = 10 } 
			}, 
			swim = 	{
				{ id = "http://www.roblox.com/asset/?id=507784897", weight = 10 } 
			}, 
			swimidle = 	{
				{ id = "http://www.roblox.com/asset/?id=507785072", weight = 10 } 
			}, 
			jump = 	{
				{ id = "http://www.roblox.com/asset/?id=507765000", weight = 10 } 
			}, 
			fall = 	{
				{ id = "http://www.roblox.com/asset/?id=507767968", weight = 10 } 
			}, 
			climb = {
				{ id = "http://www.roblox.com/asset/?id=507765644", weight = 10 } 
			}, 
			sit = 	{
				{ id = "http://www.roblox.com/asset/?id=2506281703", weight = 10 } 
			},	
			toolnone = {
				{ id = "http://www.roblox.com/asset/?id=507768375", weight = 10 } 
			},
			toolslash = {
				{ id = "http://www.roblox.com/asset/?id=522635514", weight = 10 } 
			},
			toollunge = {
				{ id = "http://www.roblox.com/asset/?id=522638767", weight = 10 } 
			},
			wave = {
				{ id = "http://www.roblox.com/asset/?id=507770239", weight = 10 } 
			},
			point = {
				{ id = "http://www.roblox.com/asset/?id=507770453", weight = 10 } 
			},
			dance = {
				{ id = "http://www.roblox.com/asset/?id=507771019", weight = 10 }, 
				{ id = "http://www.roblox.com/asset/?id=507771955", weight = 10 }, 
				{ id = "http://www.roblox.com/asset/?id=507772104", weight = 10 } 
			},
			dance2 = {
				{ id = "http://www.roblox.com/asset/?id=507776043", weight = 10 }, 
				{ id = "http://www.roblox.com/asset/?id=507776720", weight = 10 }, 
				{ id = "http://www.roblox.com/asset/?id=507776879", weight = 10 } 
			},
			dance3 = {
				{ id = "http://www.roblox.com/asset/?id=507777268", weight = 10 }, 
				{ id = "http://www.roblox.com/asset/?id=507777451", weight = 10 }, 
				{ id = "http://www.roblox.com/asset/?id=507777623", weight = 10 } 
			},
			laugh = {
				{ id = "http://www.roblox.com/asset/?id=507770818", weight = 10 } 
			},
			cheer = {
				{ id = "http://www.roblox.com/asset/?id=507770677", weight = 10 } 
			},
		}

		-- Existance in this list signifies that it is an emote, the value indicates if it is a looping emote
		local emoteNames = { wave = false, point = false, dance = true, dance2 = true, dance3 = true, laugh = false, cheer = false}

		math.randomseed(tick())

		local function findExistingAnimationInSet(set, anim)
			if set == nil or anim == nil then
				return 0
			end

			for idx = 1, set.count, 1 do 
				if set[idx].anim.AnimationId == anim.AnimationId then
					return idx
				end
			end

			return 0
		end
		
		local function CleanupAnimTable(name: string?)
			if name and animTable then
				if (animTable[name] ~= nil) then
					for _, connection in pairs(animTable[name].connections) do
						connection:disconnect()
					end
					animTable[name].connections = nil
					animTable[name].totalWeight = nil
					animTable[name].count = nil
					for idx,animData in animTable[name] do
						if animData.anim then
							-- this is already handled by the "noCharacterMemoryLeak" script which brute force destroys all instances under a character when they unload
							-- animData.anim:Destroy()
						end
						animData.weight = nil
						animTable[name][idx] = nil
					end
					animTable[name] = nil
				end
			elseif animTable then
				for name, _ in animTable do
					CleanupAnimTable(name)
				end
				animTable = nil
			end
		end
		
		local function configureAnimationSet(name, fileList)
			CleanupAnimTable(name)
			animTable[name] = {}
			animTable[name].count = 0
			animTable[name].totalWeight = 0	
			animTable[name].connections = {}

			local allowCustomAnimations = true

			local success, msg = pcall(function() allowCustomAnimations = game:GetService("StarterPlayer").AllowCustomAnimations end)
			if not success then
				allowCustomAnimations = true
			end

			-- check for config values
			local config = DummyScript:FindFirstChild(name)
			if (allowCustomAnimations and config ~= nil) then
				table.insert(animTable[name].connections, config.ChildAdded:Connect(function(child) configureAnimationSet(name, fileList) end))
				table.insert(animTable[name].connections, config.ChildRemoved:Connect(function(child) configureAnimationSet(name, fileList) end))
				local idx = 0
				for _, childPart in pairs(config:GetChildren()) do
					if (childPart:IsA("Animation")) then
						local newWeight = 1
						local weightObject = childPart:FindFirstChild("Weight")
						if (weightObject ~= nil) then
							newWeight = weightObject.Value
						end
						animTable[name].count = animTable[name].count + 1
						idx = animTable[name].count
						animTable[name][idx] = {}
						animTable[name][idx].anim = childPart
						animTable[name][idx].weight = newWeight
						animTable[name].totalWeight = animTable[name].totalWeight + animTable[name][idx].weight
						table.insert(animTable[name].connections, childPart.Changed:Connect(function(property) configureAnimationSet(name, fileList) end))
						table.insert(animTable[name].connections, childPart.ChildAdded:Connect(function(property) configureAnimationSet(name, fileList) end))
						table.insert(animTable[name].connections, childPart.ChildRemoved:Connect(function(property) configureAnimationSet(name, fileList) end))
					end
				end
			end

			-- fallback to defaults
			if (animTable[name].count <= 0) then
				for idx, anim in pairs(fileList) do
					animTable[name][idx] = {}
					animTable[name][idx].anim = Instance.new("Animation", script)
					animTable[name][idx].anim.Name = name
					animTable[name][idx].anim.AnimationId = anim.id
					animTable[name][idx].weight = anim.weight
					animTable[name].count = animTable[name].count + 1
					animTable[name].totalWeight = animTable[name].totalWeight + anim.weight
				end
			end
			
			for i, animType in pairs(animTable) do
				for idx = 1, animType.count, 1 do
					if PreloadedAnims[animType[idx].anim.AnimationId] == nil and Animator._destroyed ~= true then
						Animator:LoadAnimation(animType[idx].anim, nil, { AnimationPriority = Enum.AnimationPriority.Core }, nil)
						PreloadedAnims[animType[idx].anim.AnimationId] = true
					end
				end
			end
		end

		------------------------------------------------------------------------------------------------------------

		local function configureAnimationSetOld(name, fileList)
			CleanupAnimTable(name)
			animTable[name] = {}
			animTable[name].count = 0
			animTable[name].totalWeight = 0	
			animTable[name].connections = {}

			local allowCustomAnimations = true

			local success, msg = pcall(function() allowCustomAnimations = game:GetService("StarterPlayer").AllowCustomAnimations end)
			if not success then
				allowCustomAnimations = true
			end

			-- check for config values
			local config = DummyScript:FindFirstChild(name)
			if (allowCustomAnimations and config ~= nil) then
				table.insert(animTable[name].connections, config.ChildAdded:Connect(function(child) configureAnimationSet(name, fileList) end))
				table.insert(animTable[name].connections, config.ChildRemoved:Connect(function(child) configureAnimationSet(name, fileList) end))
				local idx = 1
				for _, childPart in pairs(config:GetChildren()) do
					if (childPart:IsA("Animation")) then
						table.insert(animTable[name].connections, childPart.Changed:Connect(function(property) configureAnimationSet(name, fileList) end))
						animTable[name][idx] = {}
						animTable[name][idx].anim = childPart
						local weightObject = childPart:FindFirstChild("Weight")
						if (weightObject == nil) then
							animTable[name][idx].weight = 1
						else
							animTable[name][idx].weight = weightObject.Value
						end
						animTable[name].count = animTable[name].count + 1
						animTable[name].totalWeight = animTable[name].totalWeight + animTable[name][idx].weight
						idx = idx + 1
					end
				end
			end

			-- fallback to defaults
			if (animTable[name].count <= 0) then
				for idx, anim in pairs(fileList) do
					animTable[name][idx] = {}
					animTable[name][idx].anim = Instance.new("Animation", script)
					animTable[name][idx].anim.Name = name
					animTable[name][idx].anim.AnimationId = anim.id
					animTable[name][idx].weight = anim.weight
					animTable[name].count = animTable[name].count + 1
					animTable[name].totalWeight = animTable[name].totalWeight + anim.weight
					-- print(name .. " [" .. idx .. "] " .. anim.id .. " (" .. anim.weight .. ")")
				end
			end
			
			for i, animType in pairs(animTable) do
				for idx = 1, animType.count, 1 do
					Animator:LoadAnimation(animType[idx].anim, nil, { AnimationPriority = Enum.AnimationPriority.Core }, nil)
				end
			end
		end

		-- Setup animation objects
		local function scriptChildModified(child)
			local fileList = animNames[child.Name]
			if (fileList ~= nil) then
				configureAnimationSet(child.Name, fileList)
			end	
		end

		local connections = {
			DummyScript.ChildAdded:Connect(scriptChildModified);
			DummyScript.ChildRemoved:Connect(scriptChildModified);
		}

		-- Clear any existing animation tracks
		-- Fixes issue with characters that are moved in and out of the Workspace accumulating tracks
		local animator = if Humanoid then Humanoid:FindFirstChildOfClass("Animator") else nil
		if animator then
			local animTracks = animator:GetPlayingAnimationTracks()
			for i,track in ipairs(animTracks) do
				Animator:Stop(track,0)
				track:Destroy()
			end
		end

		local function setup()
			for name, fileList in pairs(animNames) do 
				configureAnimationSet(name, fileList)
			end
		end

		setup()

		-- ANIMATION

		-- declarations
		local toolAnim = "None"
		local toolAnimTime = 0

		local jumpAnimTime = 0
		local jumpAnimDuration = 0.31

		local toolTransitionTime = 0.1
		local fallTransitionTime = 0.2

		local currentlyPlayingEmote = false

		-- functions

		local function stopAllAnimations()
			local oldAnim = currentAnim

			-- return to idle if finishing an emote
			if (emoteNames[oldAnim] ~= nil and emoteNames[oldAnim] == false) then
				oldAnim = "idle"
			end

			if currentlyPlayingEmote then
				oldAnim = "idle"
				currentlyPlayingEmote = false
			end

			currentAnim = ""
			currentAnimInstance = nil
			if (currentAnimKeyframeHandler ~= nil) then
				currentAnimKeyframeHandler:disconnect()
			end

			if (currentAnimTrack ~= nil) then
				Animator:Stop(currentAnimTrack)
				currentAnimTrack:Destroy()
				currentAnimTrack = nil
			end

			-- clean up walk if there is one
			if (runAnimKeyframeHandler ~= nil) then
				runAnimKeyframeHandler:disconnect()
			end

			if (runAnimTrack ~= nil) then
				Animator:Stop(runAnimTrack)
				runAnimTrack:Destroy()
				runAnimTrack = nil
			end

			return oldAnim
		end

		local function getHeightScale()
			if Humanoid then
				if not Humanoid.AutomaticScalingEnabled then
					-- When auto scaling is not enabled, the rig scale stands in for
					-- a computed scale.
					return getRigScale()
				end

				local scale = Humanoid.HipHeight / HumanoidHipHeight
				if AnimationSpeedDampeningObject == nil then
					AnimationSpeedDampeningObject = DummyScript:FindFirstChild("ScaleDampeningPercent")
				end
				if AnimationSpeedDampeningObject ~= nil then
					scale = 1 + (Humanoid.HipHeight - HumanoidHipHeight) * AnimationSpeedDampeningObject.Value / HumanoidHipHeight
				end
				return scale
			end	
			return getRigScale()
		end

		local function rootMotionCompensation(speed)
			local speedScaled = speed * 1.25
			local heightScale = getHeightScale()
			local runSpeed = speedScaled / heightScale
			return runSpeed
		end

		local smallButNotZero = 0.0001
		local function setRunSpeed(speed)
			local normalizedWalkSpeed = 0.5 -- established empirically using current `913402848` walk animation
			local normalizedRunSpeed  = 1
			local runSpeed = rootMotionCompensation(speed)

			local walkAnimationWeight = smallButNotZero
			local runAnimationWeight = smallButNotZero
			local walkAnimationTimewarp = runSpeed/normalizedWalkSpeed
			local runAnimationTimerwarp = runSpeed/normalizedRunSpeed

			if runSpeed <= normalizedWalkSpeed then
				walkAnimationWeight = 1
			elseif runSpeed < normalizedRunSpeed then
				local fadeInRun = (runSpeed - normalizedWalkSpeed)/(normalizedRunSpeed - normalizedWalkSpeed)
				walkAnimationWeight = 1 - fadeInRun
				runAnimationWeight  = fadeInRun
				walkAnimationTimewarp = 1
				runAnimationTimerwarp = 1
			else
				runAnimationWeight = 1
			end
			Animator:AdjustWeight(currentAnimTrack, walkAnimationWeight)
			Animator:AdjustWeight(runAnimTrack, runAnimationWeight)
			Animator:AdjustSpeed(currentAnimTrack, walkAnimationTimewarp)
			Animator:AdjustSpeed(runAnimTrack, runAnimationTimerwarp)
		end

		local function setAnimationSpeed(speed)
			if currentAnim == "walk" then
				setRunSpeed(speed)
			else
				if speed ~= currentAnimSpeed then
					currentAnimSpeed = speed
					Animator:AdjustSpeed(currentAnimTrack, currentAnimSpeed)
				end
			end
		end

		local function rollAnimation(animName)
			local roll = if animTable[animName] then math.random(1, animTable[animName].totalWeight) else 1 
			local origRoll = roll
			local idx = 1
			local weight = if animTable[animName] then animTable[animName][idx].weight else 1
			while (roll > weight) do
				roll = roll - weight
				idx = idx + 1
				weight = if animTable[animName] then animTable[animName][idx].weight else 1
			end
			return idx
		end

		local function switchToAnim(anim, animName, transitionTime, humanoid)
			-- switch animation		
			if (anim ~= currentAnimInstance) then

				if (currentAnimTrack ~= nil) then
					Animator:Stop(currentAnimTrack, transitionTime)
					currentAnimTrack:Destroy()
				end

				if (runAnimTrack ~= nil) then
					Animator:Stop(runAnimTrack, transitionTime)
					runAnimTrack:Destroy()
				end

				currentAnimSpeed = 1.0

				-- load it to the humanoid; get AnimationTrack
				currentAnimTrack = Animator:LoadAnimation(anim, nil, { AnimationPriority = Enum.AnimationPriority.Core }, nil)

				-- play the animation
				Animator:Play(currentAnimTrack,transitionTime, nil, nil, true)
				currentAnim = animName
				currentAnimInstance = anim

				-- set up keyframe name triggers
				if (currentAnimKeyframeHandler ~= nil) then
					currentAnimKeyframeHandler:disconnect()
				end
				if currentAnimTrack then
					currentAnimKeyframeHandler = currentAnimTrack.KeyframeReached:Connect(function(frameName)
						if (frameName == "End") then
							if currentAnim == "walk" then
								if userNoUpdateOnLoop == true then
									if runAnimTrack.Looped ~= true then
										runAnimTrack.TimePosition = 0.0
									end
									if currentAnimTrack.Looped ~= true then
										currentAnimTrack.TimePosition = 0.0
									end
								else
									runAnimTrack.TimePosition = 0.0
									currentAnimTrack.TimePosition = 0.0
								end
							else
								local repeatAnim = currentAnim
								-- return to idle if finishing an emote
								if (emoteNames[repeatAnim] ~= nil and emoteNames[repeatAnim] == false) then
									repeatAnim = "idle"
								end

								if currentlyPlayingEmote then
									if currentAnimTrack.Looped then
										-- Allow the emote to loop
										return
									end

									repeatAnim = "idle"
									currentlyPlayingEmote = false
								end

								local animSpeed = currentAnimSpeed

								local idx = rollAnimation(repeatAnim)
								local anim = if animTable[repeatAnim] and animTable[repeatAnim][idx] then animTable[repeatAnim][idx].anim else animTable[repeatAnim][1].anim
								switchToAnim(anim, repeatAnim, 0.2, Humanoid)
								currentlyPlayingEmote = false
								setAnimationSpeed(animSpeed)
							end
						end
					end)
				end
				-- check to see if we need to blend a walk/run animation
				if animName == "walk" then
					local runAnimName = "run"
					local runIdx = rollAnimation(runAnimName)

					runAnimTrack = Animator:LoadAnimation(animTable[runAnimName][runIdx].anim, nil, { AnimationPriority = Enum.AnimationPriority.Core }, nil)
					Animator:Play(runAnimTrack, transitionTime, nil, nil, true)		

					if (runAnimKeyframeHandler ~= nil) then
						runAnimKeyframeHandler:disconnect()
					end
					if runAnimTrack then
						runAnimKeyframeHandler = runAnimTrack.KeyframeReached:Connect(function(frameName)
							if (frameName == "End") then
								if currentAnim == "walk" then
									if userNoUpdateOnLoop == true then
										if runAnimTrack.Looped ~= true then
											runAnimTrack.TimePosition = 0.0
										end
										if currentAnimTrack.Looped ~= true then
											currentAnimTrack.TimePosition = 0.0
										end
									else
										runAnimTrack.TimePosition = 0.0
										currentAnimTrack.TimePosition = 0.0
									end
								else
									local repeatAnim = currentAnim
									-- return to idle if finishing an emote
									if (emoteNames[repeatAnim] ~= nil and emoteNames[repeatAnim] == false) then
										repeatAnim = "idle"
									end

									if currentlyPlayingEmote then
										if currentAnimTrack.Looped then
											-- Allow the emote to loop
											return
										end

										repeatAnim = "idle"
										currentlyPlayingEmote = false
									end

									local animSpeed = currentAnimSpeed

									local idx = rollAnimation(repeatAnim)
									local anim = if animTable[repeatAnim] and animTable[repeatAnim][idx] then animTable[repeatAnim][idx].anim else animTable[repeatAnim][1].anim
									switchToAnim(anim, repeatAnim, 0.15, Humanoid)
									currentlyPlayingEmote = false
									setAnimationSpeed(animSpeed)
								end
							end
						end)	
					end
				end
			end
		end

		local function playAnimation(animName, transitionTime, humanoid) 	
			local idx = rollAnimation(animName)
			local anim = if animTable[animName] and animTable[animName][idx] then animTable[animName][idx].anim else animTable[animName][1].anim

			switchToAnim(anim, animName, transitionTime, humanoid)
			currentlyPlayingEmote = false
		end

		local function playEmote(emoteAnim, transitionTime, humanoid)
			switchToAnim(emoteAnim, emoteAnim.Name, transitionTime, humanoid)
			currentlyPlayingEmote = true
		end

		-------------------------------------------------------------------------------------------
		-------------------------------------------------------------------------------------------

		local toolAnimName = ""
		local toolAnimTrack = nil
		local toolAnimInstance = nil
		local currentToolAnimKeyframeHandler = nil


		local function playToolAnimation(animName, transitionTime, humanoid, priority)	 		
			local idx = rollAnimation(animName)
			local anim = animTable[animName][idx].anim

			if (toolAnimInstance ~= anim) then

				if (toolAnimTrack ~= nil) then
					Animator:Stop(toolAnimTrack)
					toolAnimTrack:Destroy()
					transitionTime = 0
				end

				-- load it to the humanoid; get AnimationTrack
				toolAnimTrack = Animator:LoadAnimation(anim, nil, { AnimationPriority = priority }, nil)

				-- play the animation
				Animator:Play(toolAnimTrack, transitionTime, nil, nil, true)
				toolAnimName = animName
				toolAnimInstance = anim

				if toolAnimTrack then
					currentToolAnimKeyframeHandler = toolAnimTrack.KeyframeReached:Connect(function(frameName)
						if (frameName == "End") then
							playToolAnimation(toolAnimName, 0.0, Humanoid)
						end
					end)
				end
			end
		end

		local function stopToolAnimations()
			local oldAnim = toolAnimName

			if (currentToolAnimKeyframeHandler ~= nil) then
				currentToolAnimKeyframeHandler:disconnect()
			end

			toolAnimName = ""
			toolAnimInstance = nil
			if (toolAnimTrack ~= nil) then
				Animator:Stop(toolAnimTrack)
				toolAnimTrack:Destroy()
				toolAnimTrack = nil
			end

			return oldAnim
		end

		-------------------------------------------------------------------------------------------
		-------------------------------------------------------------------------------------------
		-- STATE CHANGE HANDLERS

		local function onRunning(speed)
			local heightScale = if userAnimateScaleRun then getHeightScale() else 1

			local movedDuringEmote = currentlyPlayingEmote and Humanoid.MoveDirection == Vector3.new(0, 0, 0)
			local speedThreshold = movedDuringEmote and (Humanoid.WalkSpeed / heightScale) or 0.75
			if speed > speedThreshold * heightScale then
				local scale = 16.0
				playAnimation("walk", 0.2, Humanoid)
				setAnimationSpeed(speed / scale)
				pose = "Running"
			else
				if emoteNames[currentAnim] == nil and not currentlyPlayingEmote then
					playAnimation("idle", 0.2, Humanoid)
					pose = "Standing"
				end
			end
		end

		local function onDied()
			pose = "Dead"
		end

		local function onRagdoll()
			pose = "Ragdoll"
		end

		local function onJumping()
			playAnimation("jump", 0.1, Humanoid)
			jumpAnimTime = jumpAnimDuration
			pose = "Jumping"
		end

		local function onClimbing(speed)
			if userAnimateScaleRun then
				speed /= getHeightScale()
			end
			local scale = 5.0
			playAnimation("climb", 0.1, Humanoid)
			setAnimationSpeed(speed / scale)
			pose = "Climbing"
		end

		local function onGettingUp()
			pose = "GettingUp"
		end

		local function onFreeFall()
			if (jumpAnimTime <= 0) then
				playAnimation("fall", fallTransitionTime, Humanoid)
			end
			pose = "FreeFall"
		end

		local function onFallingDown()
			pose = "FallingDown"
		end

		local function onSeated()
			pose = "Seated"
		end

		local function onPlatformStanding()
			pose = "PlatformStanding"
		end

		-------------------------------------------------------------------------------------------
		-------------------------------------------------------------------------------------------

		local function onSwimming(speed)
			if userAnimateScaleRun then
				speed /= getHeightScale()
			end
			if speed > 1.00 then
				local scale = 10.0
				playAnimation("swim", 0.4, Humanoid)
				setAnimationSpeed(speed / scale)
				pose = "Swimming"
			else
				playAnimation("swimidle", 0.4, Humanoid)
				pose = "Standing"
			end
		end

		local function animateTool()
			if (toolAnim == "None") then
				playToolAnimation("toolnone", toolTransitionTime, Humanoid, Enum.AnimationPriority.Idle)
				return
			end

			if (toolAnim == "Slash") then
				playToolAnimation("toolslash", 0, Humanoid, Enum.AnimationPriority.Action)
				return
			end

			if (toolAnim == "Lunge") then
				playToolAnimation("toollunge", 0, Humanoid, Enum.AnimationPriority.Action)
				return
			end
		end

		local function getToolAnim(tool)
			for _, c in ipairs(tool:GetChildren()) do
				if c.Name == "toolanim" and c.className == "StringValue" then
					return c
				end
			end
			return nil
		end

		local lastTick = 0

		local function stepAnimate(currentTime)
			local amplitude = 1
			local frequency = 1
			local deltaTime = currentTime - lastTick
			lastTick = currentTime

			local climbFudge = 0
			local setAngles = false

			if (jumpAnimTime > 0) then
				jumpAnimTime = jumpAnimTime - deltaTime
			end

			if (pose == "FreeFall" and jumpAnimTime <= 0) then
				playAnimation("fall", fallTransitionTime, Humanoid)
			elseif (pose == "Seated") then
				playAnimation("sit", 0.5, Humanoid)
				return
			elseif (pose == "Running") then
				playAnimation("walk", 0.2, Humanoid)
			elseif (pose == "Dead" or pose == "GettingUp" or pose == "FallingDown" or pose == "Seated" or pose == "PlatformStanding" or pose == "Ragdoll") then
				stopAllAnimations()
				amplitude = 0.1
				frequency = 1
				setAngles = true
			end

			-- Tool Animation handling
			local tool = Character:FindFirstChildOfClass("Tool")
			if tool and tool:FindFirstChild("Handle") then
				local animStringValueObject = getToolAnim(tool)

				if animStringValueObject then
					toolAnim = animStringValueObject.Value
					-- message recieved, delete StringValue
					animStringValueObject.Parent = nil
					toolAnimTime = currentTime + .3
				end

				if currentTime > toolAnimTime then
					toolAnimTime = 0
					toolAnim = "None"
				end

				animateTool()		
			else
				stopToolAnimations()
				toolAnim = "None"
				toolAnimInstance = nil
				toolAnimTime = 0
			end
		end

		-- connect events
		table.insert(connections, Humanoid.Died:Connect(onDied))
		table.insert(connections, Humanoid.Running:Connect(onRunning))
		table.insert(connections, Humanoid.Jumping:Connect(onJumping))
		table.insert(connections, Humanoid.Climbing:Connect(onClimbing))
		table.insert(connections, Humanoid.GettingUp:Connect(onGettingUp))
		table.insert(connections, Humanoid.FreeFalling:Connect(onFreeFall))
		table.insert(connections, Humanoid.FallingDown:Connect(onFallingDown))
		table.insert(connections, Humanoid.Seated:Connect(onSeated))
		table.insert(connections, Humanoid.PlatformStanding:Connect(onPlatformStanding))
		table.insert(connections, Humanoid.Swimming:Connect(onSwimming))
		table.insert(connections, Humanoid.Ragdoll:Connect(onRagdoll))

		-- setup emote chat hook
		if game:GetService("Players"):GetPlayerFromCharacter(Character) then
			table.insert(connections, game:GetService("Players"):GetPlayerFromCharacter(Character).Chatted:Connect(function(msg)
				local emote = ""
				if (string.sub(msg, 1, 3) == "/e ") then
					emote = string.sub(msg, 4)
				elseif (string.sub(msg, 1, 7) == "/emote ") then
					emote = string.sub(msg, 8)
				end

				if (pose == "Standing" and emoteNames[emote] ~= nil) then
					playAnimation(emote, EMOTE_TRANSITION_TIME, Humanoid)
				end
			end))
		end
		-- emote bindable hook
		local function EmoteInvoke(emote, fromNetwork: boolean?)
			-- Only play emotes when idling
			if pose ~= "Standing" then
				return
			end

			if emoteNames[emote] ~= nil then
				-- Default emotes
				playAnimation(emote, EMOTE_TRANSITION_TIME, Humanoid)

				return true, currentAnimTrack
			elseif typeof(emote) == "Instance" and emote:IsA("Animation") then
				-- Non-default emotes

				playEmote(emote, EMOTE_TRANSITION_TIME, Humanoid)

				if not fromNetwork then
					net.Animator.packets.Emote.send({ emoteId = emote.AnimationId })
				end

				return true, currentAnimTrack
			end

			-- Return false to indicate that the emote could not be played
			return false
		end

		local playEmote = DummyScript:WaitForChild("PlayEmote")
		playEmote.OnInvoke = EmoteInvoke

		if Character.Parent ~= nil then
			-- initialize to idle
			playAnimation("idle", 0.1, Humanoid)
			pose = "Standing"
		end

		-- loop to handle timed state transitions and tool animations
		while Character.Parent ~= nil do
			task.wait()
			stepAnimate(tick())
		end
		
		--disconnection
		if playEmote then
			playEmote.OnInvoke = nil
		end
		for i,v: RBXScriptConnection in connections do
			v:Disconnect()
		end
		if currentAnimKeyframeHandler then currentAnimKeyframeHandler:Disconnect() end
		if currentAnimTrack then
			currentAnimTrack:Destroy()
		end
		if runAnimTrack then
			runAnimTrack:Destroy()
		end
		if toolAnimTrack then
			toolAnimTrack:Destroy()
		end
		if runAnimKeyframeHandler then runAnimKeyframeHandler:Disconnect() end
		if currentToolAnimKeyframeHandler then currentToolAnimKeyframeHandler:Disconnect() end
		PreloadedAnims = nil
		CleanupAnimTable()
		Animator:Destroy()
		Animator = nil
		Humanoid = nil
		DummyScript = nil
	elseif Humanoid.RigType == Enum.HumanoidRigType.R6 then
		-- humanoidAnimatePlayEmote.lua
		local Torso = Character:WaitForChild("Torso")
		local RightShoulder = Torso:WaitForChild("Right Shoulder")
		local LeftShoulder = Torso:WaitForChild("Left Shoulder")
		local RightHip = Torso:WaitForChild("Right Hip")
		local LeftHip = Torso:WaitForChild("Left Hip")
		local Neck = Torso:WaitForChild("Neck")
		local pose = "Standing"

		local EMOTE_TRANSITION_TIME = 0.1

		local userAnimateScaleRunSuccess, userAnimateScaleRunValue = pcall(function() return UserSettings():IsUserFeatureEnabled("UserAnimateScaleRun") end)
		local userAnimateScaleRun = userAnimateScaleRunSuccess and userAnimateScaleRunValue

		local function getRigScale()
			if userAnimateScaleRun then
				return Character:GetScale()
			else
				return 1
			end
		end

		local currentAnim = ""
		local currentAnimInstance = nil
		local currentAnimTrack = nil
		local currentAnimKeyframeHandler = nil
		local currentAnimSpeed = 1.0
		local animTable = {}
		local animNames = { 
			idle = 	{	
				{ id = "http://www.roblox.com/asset/?id=180435571", weight = 9 },
				{ id = "http://www.roblox.com/asset/?id=180435792", weight = 1 }
			},
			walk = 	{ 	
				{ id = "http://www.roblox.com/asset/?id=180426354", weight = 10 } 
			}, 
			run = 	{
				{ id = "run.xml", weight = 10 } 
			}, 
			jump = 	{
				{ id = "http://www.roblox.com/asset/?id=125750702", weight = 10 } 
			}, 
			fall = 	{
				{ id = "http://www.roblox.com/asset/?id=180436148", weight = 10 } 
			}, 
			climb = {
				{ id = "http://www.roblox.com/asset/?id=180436334", weight = 10 } 
			}, 
			sit = 	{
				{ id = "http://www.roblox.com/asset/?id=178130996", weight = 10 } 
			},	
			toolnone = {
				{ id = "http://www.roblox.com/asset/?id=182393478", weight = 10 } 
			},
			toolslash = {
				{ id = "http://www.roblox.com/asset/?id=129967390", weight = 10 } 
				--				{ id = "slash.xml", weight = 10 } 
			},
			toollunge = {
				{ id = "http://www.roblox.com/asset/?id=129967478", weight = 10 } 
			},
			wave = {
				{ id = "http://www.roblox.com/asset/?id=128777973", weight = 10 } 
			},
			point = {
				{ id = "http://www.roblox.com/asset/?id=128853357", weight = 10 } 
			},
			dance1 = {
				{ id = "http://www.roblox.com/asset/?id=182435998", weight = 10 }, 
				{ id = "http://www.roblox.com/asset/?id=182491037", weight = 10 }, 
				{ id = "http://www.roblox.com/asset/?id=182491065", weight = 10 } 
			},
			dance2 = {
				{ id = "http://www.roblox.com/asset/?id=182436842", weight = 10 }, 
				{ id = "http://www.roblox.com/asset/?id=182491248", weight = 10 }, 
				{ id = "http://www.roblox.com/asset/?id=182491277", weight = 10 } 
			},
			dance3 = {
				{ id = "http://www.roblox.com/asset/?id=182436935", weight = 10 }, 
				{ id = "http://www.roblox.com/asset/?id=182491368", weight = 10 }, 
				{ id = "http://www.roblox.com/asset/?id=182491423", weight = 10 } 
			},
			laugh = {
				{ id = "http://www.roblox.com/asset/?id=129423131", weight = 10 } 
			},
			cheer = {
				{ id = "http://www.roblox.com/asset/?id=129423030", weight = 10 } 
			},
		}
		local dances = {"dance1", "dance2", "dance3"}

		-- Existance in this list signifies that it is an emote, the value indicates if it is a looping emote
		local emoteNames = { wave = false, point = false, dance1 = true, dance2 = true, dance3 = true, laugh = false, cheer = false}

		local function configureAnimationSet(name, fileList)
			if (animTable[name] ~= nil) then
				for _, connection in pairs(animTable[name].connections) do
					connection:disconnect()
				end
			end
			animTable[name] = {}
			animTable[name].count = 0
			animTable[name].totalWeight = 0	
			animTable[name].connections = {}

			-- check for config values
			local config = DummyScript:FindFirstChild(name)
			if (config ~= nil) then
				--		print("Loading anims " .. name)
				table.insert(animTable[name].connections, config.ChildAdded:Connect(function(child) configureAnimationSet(name, fileList) end))
				table.insert(animTable[name].connections, config.ChildRemoved:Connect(function(child) configureAnimationSet(name, fileList) end))
				local idx = 1
				for _, childPart in pairs(config:GetChildren()) do
					if (childPart:IsA("Animation")) then
						table.insert(animTable[name].connections, childPart.Changed:Connect(function(property) configureAnimationSet(name, fileList) end))
						animTable[name][idx] = {}
						animTable[name][idx].anim = childPart
						local weightObject = childPart:FindFirstChild("Weight")
						if (weightObject == nil) then
							animTable[name][idx].weight = 1
						else
							animTable[name][idx].weight = weightObject.Value
						end
						animTable[name].count = animTable[name].count + 1
						animTable[name].totalWeight = animTable[name].totalWeight + animTable[name][idx].weight
						--			print(name .. " [" .. idx .. "] " .. animTable[name][idx].anim.AnimationId .. " (" .. animTable[name][idx].weight .. ")")
						idx = idx + 1
					end
				end
			end

			-- fallback to defaults
			if (animTable[name].count <= 0) then
				for idx, anim in pairs(fileList) do
					animTable[name][idx] = {}
					animTable[name][idx].anim = Instance.new("Animation", script)
					animTable[name][idx].anim.Name = name
					animTable[name][idx].anim.AnimationId = anim.id
					animTable[name][idx].weight = anim.weight
					animTable[name].count = animTable[name].count + 1
					animTable[name].totalWeight = animTable[name].totalWeight + anim.weight
					--			print(name .. " [" .. idx .. "] " .. anim.id .. " (" .. anim.weight .. ")")
				end
			end
		end

		-- Setup animation objects
		local function scriptChildModified(child)
			local fileList = animNames[child.Name]
			if (fileList ~= nil) then
				configureAnimationSet(child.Name, fileList)
			end	
		end

		local connections = {
			DummyScript.ChildAdded:Connect(scriptChildModified);
			DummyScript.ChildRemoved:Connect(scriptChildModified);
		}

		-- Clear any existing animation tracks
		-- Fixes issue with characters that are moved in and out of the Workspace accumulating tracks
		local animator = if Humanoid then Humanoid:FindFirstChildOfClass("Animator") else nil
		if animator then
			local animTracks = animator:GetPlayingAnimationTracks()
			for i,track in ipairs(animTracks) do
				Animator:Stop(track,0)
				track:Destroy()
			end
		end

		local function setup()
			for name, fileList in pairs(animNames) do 
				configureAnimationSet(name, fileList)
			end
		end

		setup()

		-- ANIMATION

		-- declarations
		local toolAnim = "None"
		local toolAnimTime = 0

		local jumpAnimTime = 0
		local jumpAnimDuration = 0.3

		local toolTransitionTime = 0.1
		local fallTransitionTime = 0.3
		local jumpMaxLimbVelocity = 0.75

		-- functions

		local function stopAllAnimations()
			local oldAnim = currentAnim

			-- return to idle if finishing an emote
			if (emoteNames[oldAnim] ~= nil and emoteNames[oldAnim] == false) then
				oldAnim = "idle"
			end

			currentAnim = ""
			currentAnimInstance = nil
			if (currentAnimKeyframeHandler ~= nil) then
				currentAnimKeyframeHandler:disconnect()
			end

			if (currentAnimTrack ~= nil) then
				Animator:Stop(currentAnimTrack)
				currentAnimTrack:Destroy()
				currentAnimTrack = nil
			end
			return oldAnim
		end

		local function setAnimationSpeed(speed)
			if speed ~= currentAnimSpeed then
				currentAnimSpeed = speed
				Animator:AdjustSpeed(currentAnimTrack, currentAnimSpeed)
			end
		end

		-- Preload animations
		local function playAnimation(animName, transitionTime, humanoid) 

			local roll = math.random(1, animTable[animName].totalWeight) 
			local origRoll = roll
			local idx = 1
			while (roll > animTable[animName][idx].weight) do
				roll = roll - animTable[animName][idx].weight
				idx = idx + 1
			end
			--		print(animName .. " " .. idx .. " [" .. origRoll .. "]")
			local anim = animTable[animName][idx].anim

			-- switch animation		
			if (anim ~= currentAnimInstance) then

				if (currentAnimTrack ~= nil) then
					Animator:Stop(currentAnimTrack, transitionTime)
					currentAnimTrack:Destroy()
				end

				currentAnimSpeed = 1.0

				-- load it to the humanoid; get AnimationTrack
				currentAnimTrack = Animator:LoadAnimation(anim, nil, { AnimationPriority = Enum.AnimationPriority.Core }, nil)

				-- play the animation
				Animator:Play(currentAnimTrack, transitionTime, nil, nil, true)
				currentAnim = animName
				currentAnimInstance = anim

				-- set up keyframe name triggers
				if (currentAnimKeyframeHandler ~= nil) then
					currentAnimKeyframeHandler:disconnect()
				end
				if currentAnimTrack then
					currentAnimKeyframeHandler = currentAnimTrack.KeyframeReached:Connect(function(frameName)
						if (frameName == "End") then

							local repeatAnim = currentAnim
							-- return to idle if finishing an emote
							if (emoteNames[repeatAnim] ~= nil and emoteNames[repeatAnim] == false) then
								repeatAnim = "idle"
							end

							local animSpeed = currentAnimSpeed
							playAnimation(repeatAnim, 0.0, Humanoid)
							setAnimationSpeed(animSpeed)
						end
					end)
				end
			end

		end

		-------------------------------------------------------------------------------------------
		-------------------------------------------------------------------------------------------

		local toolAnimName = ""
		local toolAnimTrack = nil
		local toolAnimInstance = nil
		local currentToolAnimKeyframeHandler = nil


		local function playToolAnimation(animName, transitionTime, humanoid, priority)	 

			local roll = math.random(1, animTable[animName].totalWeight) 
			local origRoll = roll
			local idx = 1
			while (roll > animTable[animName][idx].weight) do
				roll = roll - animTable[animName][idx].weight
				idx = idx + 1
			end
			--		print(animName .. " * " .. idx .. " [" .. origRoll .. "]")
			local anim = animTable[animName][idx].anim

			if (toolAnimInstance ~= anim) then

				if (toolAnimTrack ~= nil) then
					Animator:Stop(toolAnimTrack)
					toolAnimTrack:Destroy()
					transitionTime = 0
				end

				-- load it to the humanoid; get AnimationTrack
				toolAnimTrack = Animator:LoadAnimation(anim, nil, { AnimationPriority = priority }, nil)

				-- play the animation
				Animator:Play(toolAnimTrack, transitionTime, nil, nil, true)
				toolAnimName = animName
				toolAnimInstance = anim

				if toolAnimTrack then
					currentToolAnimKeyframeHandler = toolAnimTrack.KeyframeReached:Connect(function(frameName)
						if (frameName == "End") then
							--		print("Keyframe : ".. frameName)	
							playToolAnimation(toolAnimName, 0.0, Humanoid)
						end
					end)
				end
			end
		end

		local function stopToolAnimations()
			local oldAnim = toolAnimName

			if (currentToolAnimKeyframeHandler ~= nil) then
				currentToolAnimKeyframeHandler:disconnect()
			end

			toolAnimName = ""
			toolAnimInstance = nil
			if (toolAnimTrack ~= nil) then
				Animator:Stop(toolAnimTrack)
				toolAnimTrack:Destroy()
				toolAnimTrack = nil
			end


			return oldAnim
		end

		-------------------------------------------------------------------------------------------
		-------------------------------------------------------------------------------------------


		local function onRunning(speed)
			speed /= getRigScale()

			if speed > 0.01 then
				playAnimation("walk", 0.1, Humanoid)
				if currentAnimInstance and currentAnimInstance.AnimationId == "http://www.roblox.com/asset/?id=180426354" then
					setAnimationSpeed(speed / 14.5)
				end
				pose = "Running"
			else
				if emoteNames[currentAnim] == nil then
					playAnimation("idle", 0.1, Humanoid)
					pose = "Standing"
				end
			end
		end

		local function onDied()
			pose = "Dead"
		end

		local function onRagdoll()
			pose = "Ragdoll"
		end

		local function onJumping()
			playAnimation("jump", 0.1, Humanoid)
			jumpAnimTime = jumpAnimDuration
			pose = "Jumping"
		end

		local function onClimbing(speed)
			speed /= getRigScale()

			playAnimation("climb", 0.1, Humanoid)
			setAnimationSpeed(speed / 12.0)
			pose = "Climbing"
		end

		local function onGettingUp()
			pose = "GettingUp"
		end

		local function onFreeFall()
			if (jumpAnimTime <= 0) then
				playAnimation("fall", fallTransitionTime, Humanoid)
			end
			pose = "FreeFall"
		end

		local function onFallingDown()
			pose = "FallingDown"
		end

		local function onSeated()
			pose = "Seated"
		end

		local function onPlatformStanding()
			pose = "PlatformStanding"
		end

		local function onSwimming(speed)
			if speed > 0 then
				pose = "Running"
			else
				pose = "Standing"
			end
		end

		local function getTool()	
			for _, kid in ipairs(Character:GetChildren()) do
				if kid.className == "Tool" then return kid end
			end
			return nil
		end

		local function getToolAnim(tool)
			for _, c in ipairs(tool:GetChildren()) do
				if c.Name == "toolanim" and c.className == "StringValue" then
					return c
				end
			end
			return nil
		end

		local function animateTool()

			if (toolAnim == "None") then
				playToolAnimation("toolnone", toolTransitionTime, Humanoid, Enum.AnimationPriority.Idle)
				return
			end

			if (toolAnim == "Slash") then
				playToolAnimation("toolslash", 0, Humanoid, Enum.AnimationPriority.Action)
				return
			end

			if (toolAnim == "Lunge") then
				playToolAnimation("toollunge", 0, Humanoid, Enum.AnimationPriority.Action)
				return
			end
		end

		local function moveSit()
			RightShoulder.MaxVelocity = 0.15
			LeftShoulder.MaxVelocity = 0.15
			RightShoulder:SetDesiredAngle(3.14 /2)
			LeftShoulder:SetDesiredAngle(-3.14 /2)
			RightHip:SetDesiredAngle(3.14 /2)
			LeftHip:SetDesiredAngle(-3.14 /2)
		end

		local lastTick = 0

		local function move(time)
			local amplitude = 1
			local frequency = 1
			local deltaTime = time - lastTick
			lastTick = time

			local climbFudge = 0
			local setAngles = false

			if (jumpAnimTime > 0) then
				jumpAnimTime = jumpAnimTime - deltaTime
			end

			if (pose == "FreeFall" and jumpAnimTime <= 0) then
				playAnimation("fall", fallTransitionTime, Humanoid)
			elseif (pose == "Seated") then
				playAnimation("sit", 0.5, Humanoid)
				return
			elseif (pose == "Running") then
				playAnimation("walk", 0.1, Humanoid)
			elseif (pose == "Dead" or pose == "GettingUp" or pose == "FallingDown" or pose == "Seated" or pose == "PlatformStanding" or pose == "Ragdoll") then
				--		print("Wha " .. pose)
				stopAllAnimations()
				amplitude = 0.1
				frequency = 1
				setAngles = true
			end

			if (setAngles) then
				local desiredAngle = amplitude * math.sin(time * frequency)

				RightShoulder:SetDesiredAngle(desiredAngle + climbFudge)
				LeftShoulder:SetDesiredAngle(desiredAngle - climbFudge)
				RightHip:SetDesiredAngle(-desiredAngle)
				LeftHip:SetDesiredAngle(-desiredAngle)
			end

			-- Tool Animation handling
			local tool = getTool()
			if tool and tool:FindFirstChild("Handle") then

				local animStringValueObject = getToolAnim(tool)

				if animStringValueObject then
					toolAnim = animStringValueObject.Value
					-- message recieved, delete StringValue
					animStringValueObject.Parent = nil
					toolAnimTime = time + .3
				end

				if time > toolAnimTime then
					toolAnimTime = 0
					toolAnim = "None"
				end

				animateTool()		
			else
				stopToolAnimations()
				toolAnim = "None"
				toolAnimInstance = nil
				toolAnimTime = 0
			end
		end

		-- connect events
		table.insert(connections, Humanoid.Died:Connect(onDied))
		table.insert(connections, Humanoid.Running:Connect(onRunning))
		table.insert(connections, Humanoid.Jumping:Connect(onJumping))
		table.insert(connections, Humanoid.Climbing:Connect(onClimbing))
		table.insert(connections, Humanoid.GettingUp:Connect(onGettingUp))
		table.insert(connections, Humanoid.FreeFalling:Connect(onFreeFall))
		table.insert(connections, Humanoid.FallingDown:Connect(onFallingDown))
		table.insert(connections, Humanoid.Seated:Connect(onSeated))
		table.insert(connections, Humanoid.PlatformStanding:Connect(onPlatformStanding))
		table.insert(connections, Humanoid.Swimming:Connect(onSwimming))
		table.insert(connections, Humanoid.Ragdoll:Connect(onRagdoll))

		---- setup emote chat hook
		if game:GetService("Players"):GetPlayerFromCharacter(Character) then
			table.insert(connections, game:GetService("Players"):GetPlayerFromCharacter(Character).Chatted:Connect(function(msg: string)
				local emote = ""
				if msg == "/e dance" then
					emote = dances[math.random(1, #dances)]
				elseif (string.sub(msg, 1, 3) == "/e ") then
					emote = string.sub(msg, 4)
				elseif (string.sub(msg, 1, 7) == "/emote ") then
					emote = string.sub(msg, 8)
				end

				if (pose == "Standing" and emoteNames[emote] ~= nil) then
					playAnimation(emote, 0.1, Humanoid)
				end

			end))
		end

		-- emote bindable hook
		DummyScript:WaitForChild("PlayEmote").OnInvoke = function(emote)

			-- Only play emotes when idling
			if pose ~= "Standing" then
				return
			end
			if emoteNames[emote] ~= nil then
				-- Default emotes
				playAnimation(emote, EMOTE_TRANSITION_TIME, Humanoid)

				return true, currentAnimTrack
			end

			-- Return false to indicate that the emote could not be played
			return false
		end
		-- main program

		-- initialize to idle
		playAnimation("idle", 0.1, Humanoid)
		pose = "Standing"

		while Character.Parent ~= nil do
			task.wait()
			move(tick())
		end
		
		for i,v: RBXScriptConnection in connections do
			v:Disconnect()
		end
		if currentAnimKeyframeHandler then currentAnimKeyframeHandler:disconnect() end
		if currentAnimTrack then
			currentAnimTrack:Destroy()
		end
		if toolAnimTrack then
			toolAnimTrack:Destroy()
		end
		Animator = nil
		Humanoid = nil
		DummyScript = nil
	end
end

if Config.UGC_EMOTES then
	net.Animator.packets.Emote.listen(function(data)
		local Player = game:GetService("Players"):GetPlayerByUserId(data.userId)
		if not Player or not Player.Character or not ugcEmotes:FindFirstChild(data.emoteId) then return end
		local Animation = ugcEmotes:FindFirstChild(data.emoteId) :: Animation
		local Animate = Player.Character:FindFirstChild("Animate")
		if not Animation or not Animate then return end
		Animate:FindFirstChildOfClass("BindableFunction"):Invoke(Animation, true)
	end)
end

game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, Config.UGC_EMOTES)

for _, player in pairs(Players:GetPlayers()) do
	if player.Character then
		task.spawn(setupCharacterAnimations, player.Character)
	end
	player.CharacterAdded:Connect(setupCharacterAnimations)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(setupCharacterAnimations)
end)