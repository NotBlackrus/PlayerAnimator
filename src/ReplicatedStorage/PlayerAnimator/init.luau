--[[
	┌──────────────────────────────────────────────────────────────────────────┐
	│  PlayerAnimator Module                                                   │
	├──────────────────────────────────────────────────────────────────────────┤
	│  Made by @NotBlackrus                                                    │
	├──────────────────────────────────────────────────────────────────────────┤
	│  • Overhauls client-server interaction for the Animator & tracks.        │
	│  • All animations load on the client; the server solely handles network. │
	│  • WARNING: Do not use built-in AnimationTrack methods. All methods      │
	│    have been completely recreated and are accessible via this module.    │
	│  • Includes optional custom player utilizing PreRender for precise       │
	│    timing synchronization.                                               │
	├──────────────────────────────────────────────────────────────────────────┤
	│  MIT License                                                             │
	│  Copyright (c) 2026 @NotBlackrus                                         │
	└──────────────────────────────────────────────────────────────────────────┘
--]]

local UGCemotes = true

local IsClient = game:GetService("RunService"):IsClient()
local Players = game:GetService("Players")
local InsertService = game:GetService("InsertService")
local Initialized = false
local net = require("@self/dependencies/net")
local ugcEmotes = script.ugcEmotes

local AnimatorModule = {}

local Client = require(script.Client)
local Server = require(script.Server)

export type LocalAnimator = Client.LocalAnimator
export type ServerAnimator = Server.ServerAnimator

local cache = {}::{[Humanoid]:LocalAnimator|ServerAnimator}

function AnimatorModule.new(Humanoid: Humanoid): LocalAnimator|ServerAnimator
	if cache[Humanoid] then return cache[Humanoid] end
	local NewHandler = if IsClient then Client.new(Humanoid) else Server.new(Humanoid)
	cache[Humanoid] = NewHandler

	Humanoid.Destroying:Once(function()
		cache[Humanoid] = nil
	end)

	return NewHandler
end

function AnimatorModule.newClient(Humanoid: Humanoid): LocalAnimator
	assert(IsClient, "Can't call newClient() on Server!")
	return AnimatorModule.new(Humanoid) :: LocalAnimator
end

function AnimatorModule.newServer(Humanoid: Humanoid): ServerAnimator
	assert(not IsClient, "Can't call newServer() on Client!")
	return AnimatorModule.new(Humanoid) :: ServerAnimator
end

local AnimationPriorities = {
	[1] = Enum.AnimationPriority.Action4;
	[2] = Enum.AnimationPriority.Action3;
	[3] = Enum.AnimationPriority.Action2;
	[4] = Enum.AnimationPriority.Action;
	[5] = Enum.AnimationPriority.Idle;
	[6] = Enum.AnimationPriority.Movement;
	[7] = Enum.AnimationPriority.Core;
}

if IsClient and not Initialized then
	Initialized = true

	local function GetHumanoidFromPlayer(Player: Player?): Humanoid?
		if not Player or not Player.Character or not Player.Character:FindFirstChildOfClass("Humanoid") then
			return nil
		end

		return Player.Character:FindFirstChildOfClass("Humanoid")
	end
	
	net.Animator.packets.LoadAnimation.listen(function(data)
		local Humanoid = GetHumanoidFromPlayer(data.player)
		if not Humanoid then warn("No humanoid for",data.player) return end
		local Animator = AnimatorModule.newClient(Humanoid)
		local priority = data.animationPriority and AnimationPriorities[data.animationPriority] or nil
		Animator:LoadAnimationById(data.animationId, false, priority, data.gUID)
	end)

	net.Animator.packets.Play.listen(function(data)
		local Humanoid = GetHumanoidFromPlayer(data.player)
		if not Humanoid then warn("No humanoid for",data.player) return end
		local Animator = AnimatorModule.newClient(Humanoid)
		Animator:PlayByGUID(data.gUID, data.fadeTime, data.weight, data.speed, data.customPlayer)
	end)

	net.Animator.packets.Stop.listen(function(data)
		local Humanoid = GetHumanoidFromPlayer(data.player)
		if not Humanoid then warn("No humanoid for",data.player) return end
		local Animator = AnimatorModule.newClient(Humanoid)
		Animator:StopByGUID(data.gUID, data.fadeTime)
	end)

	net.Animator.packets.StopAll.listen(function(data)
		local Humanoid = GetHumanoidFromPlayer(data.player)
		if not Humanoid then warn("No humanoid for",data.player) return end
		local Animator = AnimatorModule.newClient(Humanoid)
		Animator:StopAll(data.fadeTime, false)
	end)

	net.Animator.packets.Destroy.listen(function(data)
		local Humanoid = GetHumanoidFromPlayer(data.player)
		if not Humanoid then warn("No humanoid for",data.player) return end
		local Animator = AnimatorModule.newClient(Humanoid)
		Animator:DestroyAnimationByGUID(data.gUID)
	end)

	net.Animator.packets.AdjustSpeed.listen(function(data)
		local Humanoid = GetHumanoidFromPlayer(data.player)
		if not Humanoid then warn("No humanoid for",data.player) return end
		local Animator = AnimatorModule.newClient(Humanoid)
		Animator:AdjustSpeedByGUID(data.gUID, data.speed)
	end)

	net.Animator.packets.AdjustWeight.listen(function(Player: Player, AnimationId: string, weight: number?, fadeTime: number?)
		local Humanoid = GetHumanoidFromPlayer(Player)
		if not Humanoid then warn("No humanoid for",Player) return end
		local Animator = AnimatorModule.newClient(Humanoid)
		Animator:AdjustWeightById(AnimationId, weight, fadeTime)
	end)
	
	AnimatorModule.init = function() --module hangs on return if this isn't a function???
		local Preloads = net.Animator.queries.Init.invoke({ request = true })
		if Preloads then
			for Player,Anims in Preloads.data do
				local Humanoid = GetHumanoidFromPlayer(Player)
				if not Humanoid then warn("No humanoid for",Player) continue end
				local Animator = AnimatorModule.newClient(Humanoid)
				for GUID,AnimationId in Anims do
					Animator:LoadAnimationById(AnimationId, false, GUID)
				end
			end
		end
	end

	if UGCemotes then
		local Commands = game:GetService("TextChatService"):WaitForChild("TextChatCommands",5)
		Commands:WaitForChild("RBXEmoteCommand",5):Destroy()
		local NewCommand = Instance.new("TextChatCommand")
		NewCommand.Name = "RBXEmoteCommand"
		NewCommand.PrimaryAlias = "/emote"
		NewCommand.SecondaryAlias = "/e"
		NewCommand.Parent = Commands
		NewCommand.Triggered:Connect(function(originTextSource: TextSource, unfilteredText: string)
			if Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("Humanoid") then
				local Humanoid = Players.LocalPlayer:FindFirstChildOfClass("Humanoid")
				local Emotes = Humanoid:GetAppliedDescription():GetEmotes()
				local searchingFor
				if (string.sub(unfilteredText, 1, 3) == "/e ") then
					searchingFor = string.sub(unfilteredText, 4)
				elseif (string.sub(unfilteredText, 1, 7) == "/emote ") then
					searchingFor = string.sub(unfilteredText, 8)
				end
				if searchingFor and Emotes[searchingFor] then
					Humanoid:PlayEmote(Emotes[searchingFor][1])
				end
			end
		end)
	end
elseif not IsClient and not Initialized then
	Initialized = true
	local Initialized = {}::{[Player]:number}

	--[EmoteId] = Animation
	local EmoteCache = {}::{[number]:Animation}
	--[Player.UserId] = Description:GetEmotes()
	local PlayerEmotes = {}::{[number]:{[string]:{number}}}

	local function EmoteHandler(player: Player)
		local function CacheEmotes(Character: Model)
			local Humanoid = Character:WaitForChild("Humanoid", 3) :: Humanoid
			if not Humanoid then return warn("Could not find Humanoid for",Character) end
			if UGCemotes then
				local function MatchTables(Table1:{[string]:{number}}, Table2:{[string]:{number}})
					local Match = true
					for i,v in Table1 do
						for z,id in v do
							if not Table2[i] or not Table2[i][z] or Table2[i][z] ~= id then
								Match = false
								if EmoteCache[id] and EmoteCache[id]:GetAttribute("Owners") then
									local anim = EmoteCache[id]
									local owners = string.split(anim:GetAttribute("Owners"),",")
									if table.find(owners,tostring(player.UserId)) then
										table.remove(owners,table.find(owners,tostring(player.UserId)))
										if #owners == 0 then
											anim:Destroy()
										else
											anim:SetAttribute("Owners",table.concat(owners,","))
										end
									end
								end
							end
						end
					end
					for i,v in Table2 do
						for z,id in v do
							if not Table1[i] or not Table1[i][z] or Table1[i][z] ~= id then
								Match = false
								if EmoteCache[id] and EmoteCache[id]:GetAttribute("Owners") then
									local anim = EmoteCache[id]
									local owners = string.split(anim:GetAttribute("Owners"),",")
									if table.find(owners,tostring(player.UserId)) then
										table.remove(owners,table.find(owners,tostring(player.UserId)))
										if #owners == 0 then
											anim:Destroy()
										else
											anim:SetAttribute("Owners",table.concat(owners,","))
										end
									end
								end
							end
						end
					end
					return Match
				end

				local Description = (Humanoid::Humanoid):GetAppliedDescription()
				local Emotes = Description:GetEmotes()
				if not PlayerEmotes[player.UserId] or not MatchTables(Emotes, PlayerEmotes[player.UserId]) then
					PlayerEmotes[player.UserId] = Emotes
					for EmoteName: string, Animations: {number} in Emotes do
						for i,EmoteId in Animations do
							if EmoteCache[EmoteId] then
								local anim = EmoteCache[EmoteId]
								if not string.find(anim:GetAttribute("Owners"),tostring(player.UserId)) then
									local owners = string.split(anim:GetAttribute("Owners"),",")
									table.insert(owners,tostring(player.UserId))
									anim:SetAttribute("Owners",table.concat(owners,","))
								end
								continue
							end
							local success, EmoteModel = pcall(function()
								return InsertService:LoadAsset(EmoteId)
							end)
							if success and EmoteModel then
								local EmoteAnimation = EmoteModel:FindFirstChildOfClass("Animation")
								EmoteCache[EmoteId] = EmoteAnimation
								EmoteAnimation.Name = EmoteId
								EmoteAnimation:SetAttribute("Owners",tostring(player.UserId))
								EmoteAnimation.Parent = ugcEmotes
							end
						end
					end
				end
			end
		end
		CacheEmotes(player.Character or player.CharacterAdded:Wait())
		player.CharacterAdded:Connect(CacheEmotes)
	end

	for i,v in Players:GetPlayers() do
		EmoteHandler(v)
	end
	Players.PlayerAdded:Connect(EmoteHandler)
	Players.PlayerRemoving:Connect(function(v)
		if Initialized[v] then Initialized[v] = nil end
		for i,v: ServerAnimator in cache do
			if v._player == v then
				v:Destroy()
				cache[i] = nil
			end
		end
		if PlayerEmotes[v.UserId] then
			for EmoteName: string, Animations: {number} in PlayerEmotes[v.UserId] do
				for i,EmoteId in Animations do
					if EmoteCache[EmoteId] then
						local owners = string.split(EmoteCache[EmoteId]:GetAttribute("Owners"),",")
						if table.find(owners,tostring(v.UserId)) then
							table.remove(owners,table.find(owners,tostring(v.UserId)))
							if #owners == 0 then 
								EmoteCache[EmoteId]:Destroy()
							else
								EmoteCache[EmoteId]:SetAttribute("Owners",table.concat(owners,","))
							end
						end
					end
				end
			end
		end
	end)
	
	local function getAnimator(Player: Player) : ServerAnimator
		local Character = Player.Character
		if not Character then return nil end
		local Humanoid = Character:WaitForChild("Humanoid", 3) :: Humanoid
		if not Humanoid then return nil end
		return AnimatorModule.new(Humanoid)
	end
	
	net.Animator.queries.Init.listen(function( req, Player )
		assert(Player and not Initialized[Player])
		Initialized[Player] = os.clock()
		local totalReplicating = {}
		for i: Humanoid,v: ServerAnimator in cache do
			if not v or v._destroyed or not v._player then continue end
			totalReplicating[v._player.UserId] = v.ReplicatedAnims
		end
		return { data = totalReplicating }
	end)

	net.Animator.packets.LoadAnimation.listen(function( data, Player )
		local Animator = getAnimator(Player)
		local track = Animator:LoadAnimation(data.animationId, false, data.gUID)
		if data.speed then
			track.Speed = data.speed
		end
		if data.weight then
			track.Weight = data.weight
		end
		track.Looped = data.loop or false
		net.Animator.packets.LoadAnimation.sendToAllExcept({ animationId = data.animationId, gUID = data.gUID, speed = data.speed, weight = data.weight, player = Player }, Player )
	end)
	
	net.Animator.packets.Play.listen(function( data, Player )
		local Animator = getAnimator(Player)
		if Animator.AnimationTracks[data.gUID] then
			net.Animator.packets.Play.sendToAllExcept({ gUID = data.gUID, fadeTime = data.fadeTime, weight = data.weight, speed = data.speed, player = Player }, Player)
		end
	end)
	
	net.Animator.packets.Stop.listen(function( data, Player )
		local Animator = getAnimator(Player)
		if Animator.AnimationTracks[data.gUID] then
			net.Animator.packets.Play.sendToAllExcept({ gUID = data.gUID, fadeTime = data.fadeTime, weight = data.weight, speed = data.speed, player = Player }, Player)
		end
	end)
	
	net.Animator.packets.AdjustSpeed.listen(function( data, Player )
		local Animator = getAnimator(Player)
		if Animator.AnimationTracks[data.gUID] then
			net.Animator.packets.AdjustSpeed.sendToAllExcept({ gUID = data.gUID, speed = data.speed, player = Player }, Player)
		end
	end)
	
	net.Animator.packets.AdjustWeight.listen(function( data, Player )
		local Animator = getAnimator(Player)
		if Animator.AnimationTracks[data.gUID] then
			net.Animator.packets.AdjustWeight.sendToAllExcept({ gUID = data.gUID, weight = data.weight, fadeTime = data.fadeTime, player = Player }, Player)
		end
	end)
	
	net.Animator.packets.Destroy.listen(function( data, Player )
		local Animator = getAnimator(Player)
		if Animator.AnimationTracks[data.gUID] then
			Animator.AnimationTracks[data.gUID]:Destroy(Player)
		end
	end)

	net.Animator.packets.Emote.listen(function( data, Player )
		if not Player.Character or not Player.Character:FindFirstChildOfClass("Humanoid") then return end
		local Humanoid = Player.Character:FindFirstChildOfClass("Humanoid")
		if ugcEmotes:FindFirstChild(data.emoteId) then
			if string.find(ugcEmotes:FindFirstChild(data.emoteId):GetAttribute("Owners"),tostring(Player.UserId)) then
				net.Animator.packets.Emote.sendToAllExcept({ emoteId = data.emoteId, player = data.player }, Player)
			end
		else
			for i,v in ugcEmotes:GetChildren()::{Animation} do
				if v.AnimationId == data.userId then
					local EmoteId = v.Name
					if string.find(v:GetAttribute("Owners"),tostring(Player.UserId)) then
						net.Animator.packets.Emote.sendToAllExcept({ emoteId = data.emoteId, player = data.player }, Player)
					end
					break
				end
			end
		end
	end)
end

return AnimatorModule