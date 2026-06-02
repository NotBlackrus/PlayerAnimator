--[[
	┌──────────────────────────────────────────────────────────────────────────┐
	│  NotBlackrus' PlayerAnimator Module                                      │
	├──────────────────────────────────────────────────────────────────────────┤
    │  MIT License                                                             │
	└──────────────────────────────────────────────────────────────────────────┘
--]]

local UGCemotes = script:GetAttribute("UGC_EMOTES")

local IsClient = game:GetService("RunService"):IsClient()
local Players = game:GetService("Players")
local InsertService = game:GetService("InsertService")

local AnimatorModule = {}

local types = require("./playeranimator/types")
local Client = require("./playeranimator/Client")
local Server = require("./playeranimator/Server")
local net = require("./playeranimator/net")
local Janitor = require("./Janitor")

type LocalAnimator = types.LocalAnimator
type ServerAnimator = types.ServerAnimator
type FakeTrack = types.FakeTrack
type TrackArguments = types.TrackArguments

local cache = {} :: {[Humanoid]: LocalAnimator | ServerAnimator}

function AnimatorModule.new(Humanoid)
	if cache[Humanoid] then
		return cache[Humanoid]
	end

	local NewHandler = if IsClient then Client.new(Humanoid) else Server.new(Humanoid)
	local handlerJanitor = Janitor.new()

	handlerJanitor:Add(NewHandler, "Destroy")
    
	handlerJanitor:Add(Humanoid.Destroying:Connect(function()
		cache[Humanoid] = nil
		handlerJanitor:Destroy()
	end), "Disconnect")

	cache[Humanoid] = NewHandler
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

local function getHumanoidFromPlayer(Player: Player?): Humanoid?
	if not Player or not Player.Character then
		return nil
	end

	return Player.Character:FindFirstChildOfClass("Humanoid") or Player.Character:WaitForChild("Humanoid", 3)
end

local function ClientListenCallback(listener, callback: (Animator: LocalAnimator, data: { any }) -> (), dbug: string)
    listener.listen(function(data)
        local player = Players:GetPlayerByUserId(data.player)
        if script:GetAttribute("NETWORK_DEBUG") then
            print(string.format("[PlayerAnimator][Client] Received %s packet for Player %d with data:", dbug, tostring(data.player)), data)
        end
        if not player or not getHumanoidFromPlayer(player) then
            return
        end
        return callback(AnimatorModule.newClient(getHumanoidFromPlayer(player)), data)
    end)
end

local function ServerListenCallback(listener, callback: (data: { any }, Player, Animator: ServerAnimator?) -> ( any ), dbug: string)
    listener.listen(function(data, Player)
        if script:GetAttribute("NETWORK_DEBUG") then
            print(string.format("[PlayerAnimator][Server] Received %s packet from Player %d with data:", dbug, tostring(Player.UserId)), data)
        end
        if not Player or not getHumanoidFromPlayer(Player) then
            return
        end
        return callback(data, Player, AnimatorModule.newServer(getHumanoidFromPlayer(Player)))
    end)
end

local AnimationPriorities = {
    [0] = Enum.AnimationPriority.Idle;
    [1] = Enum.AnimationPriority.Movement;
    [2] = Enum.AnimationPriority.Action;
    [3] = Enum.AnimationPriority.Action2;
    [4] = Enum.AnimationPriority.Action3;
    [5] = Enum.AnimationPriority.Action4;
    [1000] = Enum.AnimationPriority.Core;
}

if IsClient then
    ClientListenCallback(net.Animator.packets.LoadAnimation, function(animator, data)
        local priority = data.animationPriority and AnimationPriorities[data.animationPriority] or nil
        animator:LoadAnimationById(data.animationId, false, {
            Looped = data.looped,
            Speed = data.speed,
            Weight = data.weight,
            AnimationPriority = priority,
        }, data.gUID)
    end, "LoadAnimation")

    ClientListenCallback(net.Animator.packets.Play, function(animator, data)
        animator:PlayByGUID(data.gUID, data.fadeTime, data.weight, data.speed, data.customPlayer)
    end, "Play")

    ClientListenCallback(net.Animator.packets.Stop, function(animator, data)
        animator:StopByGUID(data.gUID, data.fadeTime)
    end, "Stop")

    ClientListenCallback(net.Animator.packets.StopAll, function(animator, data)
        animator:StopAll(data.fadeTime, false)
    end, "StopAll")

    ClientListenCallback(net.Animator.packets.Destroy, function(animator, data)
        animator:DestroyAnimationByGUID(data.gUID)
    end, "Destroy")

    ClientListenCallback(net.Animator.packets.AdjustSpeed, function(animator, data)
        animator:AdjustSpeedByGUID(data.gUID, data.speed)
    end, "AdjustSpeed")

    ClientListenCallback(net.Animator.packets.AdjustWeight, function(animator, data)
        animator:AdjustWeightByGUID(data.gUID, data.weight, data.fadeTime)
    end, "AdjustWeight")

    task.spawn(function()
        local Preloads = net.Animator.queries.Init.invoke({ request = true })
        if Preloads then
            for Player,Anims in Preloads.data do
                if not Players:GetPlayerByUserId(Player) then continue end
                local Humanoid = getHumanoidFromPlayer(Players:GetPlayerByUserId(Player))
                if not Humanoid then continue end
                local Animator = AnimatorModule.newClient(Humanoid)
                for GUID,TrackGhost in Anims do
                    local newTrack: AnimationTrack = Animator:LoadAnimationById(TrackGhost[1], false, AnimationPriorities[TrackGhost[2]], GUID)
                    if newTrack then
                        if TrackGhost[3] then Animator:AdjustSpeedByGUID(GUID, TrackGhost[3]) end
                        if TrackGhost[4] then Animator:AdjustWeightByGUID(GUID, TrackGhost[4], 0) end
                        newTrack.Looped = TrackGhost[5] or false
                    end
                end
            end
        end
    end)

    if UGCemotes then
        local Commands = game:GetService("TextChatService"):WaitForChild("TextChatCommands", 5)
        Commands:WaitForChild("RBXEmoteCommand", 5):Destroy()

        local NewCommand = Instance.new("TextChatCommand")
        NewCommand.Name = "RBXEmoteCommand"
        NewCommand.PrimaryAlias = "/emote"
        NewCommand.SecondaryAlias = "/e"
        NewCommand.Parent = Commands

        NewCommand.Triggered:Connect(function(originTextSource: TextSource, unfilteredText: string)
            if originTextSource.UserId ~= Players.LocalPlayer.UserId then
                return
            end

            local Humanoid = getHumanoidFromPlayer(Players.LocalPlayer)
            if not Humanoid then
                return
            end

            local Emotes = Humanoid:GetAppliedDescription():GetEmotes()
            local searchingFor
            if string.sub(unfilteredText, 1, 3) == "/e " then
                searchingFor = string.sub(unfilteredText, 4)
            elseif string.sub(unfilteredText, 1, 7) == "/emote " then
                searchingFor = string.sub(unfilteredText, 8)
            end

            if searchingFor and Emotes[searchingFor] then
                Humanoid:PlayEmoteAsync(Emotes[searchingFor][1])
            end
        end)
    end
else
    local function allExcept(Player: Player)
        local list = Players:GetPlayers()
        table.remove(list, table.find(list, Player))
        return list
    end

    if UGCemotes then
        local EmoteCache = {} :: {[number]: Animation}
        local PlayerEmotes = {} :: {[number]: {[string]: {number}}}
        local emotesFolder = Instance.new("Folder")
        emotesFolder.Name = "ugcEmotes"
        emotesFolder.Parent = script

        local function cleanupOwner(anim: Animation, userId: number)
            local owners = string.split(anim:GetAttribute("Owners"), ",")
            local ownerIndex = table.find(owners, tostring(userId))
            if ownerIndex then
                table.remove(owners, ownerIndex)
                if #owners == 0 then
                    anim:Destroy()
                else
                    anim:SetAttribute("Owners", table.concat(owners, ","))
                end
            end
        end

        local function matchTables(tableA: {[string]: {number}}, tableB: {[string]: {number}}, userId: number)
            local match = true
            for name, values in tableA do
                for index, id in values do
                    if not tableB[name] or tableB[name][index] ~= id then
                        match = false
                        if EmoteCache[id] and EmoteCache[id]:GetAttribute("Owners") then
                            cleanupOwner(EmoteCache[id], tonumber(userId))
                        end
                    end
                end
            end
            for name, values in tableB do
                for index, id in values do
                    if not tableA[name] or tableA[name][index] ~= id then
                        match = false
                        if EmoteCache[id] and EmoteCache[id]:GetAttribute("Owners") then
                            cleanupOwner(EmoteCache[id], tonumber(userId))
                        end
                    end
                end
            end
            return match
        end

        local function cacheEmotesForPlayer(player: Player)
            local function CacheEmotes(Character: Model)
                local Humanoid = Character:WaitForChild("Humanoid", 3) :: Humanoid
                if not Humanoid then
                    warn("Could not find Humanoid for", Character); return
                end

                local Description = Humanoid:GetAppliedDescription()
                local Emotes = Description:GetEmotes()
                if not PlayerEmotes[player.UserId] or not matchTables(Emotes, PlayerEmotes[player.UserId], player.UserId) then
                    PlayerEmotes[player.UserId] = Emotes
                    for _, Animations in Emotes do
                        for _, EmoteId in Animations do
                            if EmoteCache[EmoteId] then
                                local anim = EmoteCache[EmoteId]
                                if not string.find(anim:GetAttribute("Owners"), tostring(player.UserId)) then
                                    local owners = string.split(anim:GetAttribute("Owners"), ",")
                                    table.insert(owners, tostring(player.UserId))
                                    anim:SetAttribute("Owners", table.concat(owners, ","))
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
                                EmoteAnimation:SetAttribute("Owners", tostring(player.UserId))
                                EmoteAnimation.Parent = emotesFolder
                            end
                        end
                    end
                end
            end

            CacheEmotes(player.Character or player.CharacterAdded:Wait())
            player.CharacterAdded:Connect(CacheEmotes)
        end

        local function onPlayerRemoving(player: Player)
            for emoteId, anim in pairs(EmoteCache) do
                if anim and anim:GetAttribute("Owners") then
                    cleanupOwner(anim, player.UserId)
                end
            end
            PlayerEmotes[player.UserId] = nil
        end

        Players.PlayerAdded:Connect(cacheEmotesForPlayer)
        Players.PlayerRemoving:Connect(onPlayerRemoving)

        for _, player in Players:GetPlayers() do
            cacheEmotesForPlayer(player)
        end


        ServerListenCallback(net.Animator.packets.Emote, function(data, Player, Animator)
            if not Animator then
                return
            end

            local emoteEntry = emotesFolder:FindFirstChild(data.emoteId)
            if emoteEntry and string.find(emoteEntry:GetAttribute("Owners"), tostring(Player.UserId)) then
                net.Animator.packets.Emote.sendToList({ emoteId = data.emoteId, player = data.player }, allExcept(Player))
                return
            end

            for _, anim in emotesFolder:GetChildren() do
                if anim.AnimationId == data.userId and string.find(anim:GetAttribute("Owners"), tostring(Player.UserId)) then
                    net.Animator.packets.Emote.sendToList({ emoteId = data.emoteId, player = data.player }, allExcept(Player))
                    break
                end
            end
        end)
    end

    Players.PlayerAdded:Connect(function(Player)
		Player.CharacterAdded:Connect(function(Character)
			local Humanoid = Character:FindFirstChildOfClass("Humanoid") or Character:WaitForChild("Humanoid", 10)
			if not Humanoid then return end
			AnimatorModule.newServer(Humanoid)
		end)
	end)
    
    local InitializedPlayers = {} :: {[Player]: number}

	net.Animator.queries.Init.listen(function(req, Player)
		assert(Player and not InitializedPlayers[Player])
		InitializedPlayers[Player] = os.clock()

		local totalReplicating = {}
		for _, animator in cache do
			if not animator or animator._destroyed or not animator._player or totalReplicating[animator._player.UserId] then
				continue
			end
            totalReplicating[animator._player.UserId] = {}
            for GUID: string, FakeTrack: FakeTrack in animator.AnimationTracks do
                if FakeTrack._ReplicateTo == nil then
                    totalReplicating[animator._player.UserId][GUID] = {
                        FakeTrack.AnimationId,
                        FakeTrack.Priority.Value ~= 1000 and FakeTrack.Priority.Value or nil,
                        FakeTrack.Speed ~= 1 and FakeTrack.Speed or nil,
                        FakeTrack.Weight ~= 1 and FakeTrack.Weight or nil,
                        FakeTrack.Looped or nil
                    }
                end
            end
		end

		return { data = totalReplicating }
	end)

	ServerListenCallback(net.Animator.packets.LoadAnimation, function(data, Player, Animator)
		if not Animator then
			return
		end

		local track = Animator:LoadAnimation(data.animationId, true, {
            Looped = data.looped,
            Speed = data.speed ~= nil and data.speed or 1,
            Weight = data.weight ~= nil and data.weight or 1,
            AnimationPriority = data.animationPriority ~= nil and AnimationPriorities[data.animationPriority] or nil,
        }, nil, data.gUID)
		track.Speed = data.speed or 1
		track.Weight = data.weight or 1
		track.Looped = data.looped or false
	end, "LoadAnimation")

	ServerListenCallback(net.Animator.packets.Play, function(data, Player, Animator)
		if Animator and Animator.AnimationTracks[data.gUID] then
			Animator.AnimationTracks[data.gUID]:Play(data.fadeTime, data.weight, data.speed)
		end
	end, "Play")

	ServerListenCallback(net.Animator.packets.Stop, function(data, Player, Animator)
		if Animator and Animator.AnimationTracks[data.gUID] then
            Animator.AnimationTracks[data.gUID]:Stop(data.fadeTime)
		end
	end, "Stop")

	ServerListenCallback(net.Animator.packets.AdjustSpeed, function(data, Player, Animator)
		if Animator and Animator.AnimationTracks[data.gUID] then
			Animator.AnimationTracks[data.gUID]:AdjustSpeed(data.speed)
		end
	end, "AdjustSpeed")

	ServerListenCallback(net.Animator.packets.AdjustWeight, function(data, Player, Animator)
		if Animator and Animator.AnimationTracks[data.gUID] then
			Animator.AnimationTracks[data.gUID]:AdjustWeight(data.weight, data.fadeTime)
		end
	end, "AdjustWeight")

	ServerListenCallback(net.Animator.packets.Destroy, function(data, Player, Animator)
		if Animator and Animator.AnimationTracks[data.gUID] then
			Animator.AnimationTracks[data.gUID]:Destroy(Player)
		end
	end, "Destroy")
end

return AnimatorModule