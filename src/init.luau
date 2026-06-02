--[[
	┌──────────────────────────────────────────────────────────────────────────┐
	│  NotBlackrus' PlayerAnimator Module                                      │
    ├──────────────────────────────────────────────────────────────────────────┤
    │  If you have any trouble with understanding how the module works, after  │
    │  reviewing the source code's commentation, feel free to contact me on    │
    │  Github, or the Roblox Developer Forum.                                  │
    │  @NotBlackrus on all platforms                                           │
    │  https://github.com/NotBlackrus/PlayerAnimator                           │
    │  https://devforum.roblox.com/t/notblackrus-player-animator/4658388       │
    └──────────────────────────────────────────────────────────────────────────┘
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
--]]

local IsClient = game:GetService("RunService"):IsClient()
local Players = game:GetService("Players")
local InsertService = game:GetService("InsertService")

local types =       require("@self/types")
local Client =      require("@self/Client")
local Server =      require("@self/Server")
local net =         require("@self/net")
local Janitor =     require("./Janitor")

export type LocalAnimator =     types.LocalAnimator
export type ServerAnimator =    types.ServerAnimator
export type FakeTrack =         types.FakeTrack
export type TrackArguments =    types.TrackArguments
export type Config =            types.Config
export type AnimatorModule =    types.AnimatorModule

local AnimatorModule = {
    cache = {}          :: {[Humanoid]: LocalAnimator | ServerAnimator},
    Initialized = false,
}

--[[Main constructor for custom Animators, but not very reliable for type checking.]]
function AnimatorModule.new(Humanoid: Humanoid): LocalAnimator | ServerAnimator
    assert(Humanoid and Humanoid:IsA("Humanoid"), "Expected Humanoid, got "..typeof(Humanoid))
    assert(AnimatorModule.Initialized, "AnimatorModule not initialized! Call AnimatorModule.init() before creating any animators.")
	if AnimatorModule.cache[Humanoid] then
		return AnimatorModule.cache[Humanoid]
	end

	local NewHandler = if IsClient then Client.new(Humanoid) else Server.new(Humanoid)
	local handlerJanitor = Janitor.new()

	handlerJanitor:Add(NewHandler, "Destroy")
    
	handlerJanitor:Add(Humanoid.Destroying:Connect(function()
		AnimatorModule.cache[Humanoid] = nil
		handlerJanitor:Destroy()
	end), "Disconnect")

	AnimatorModule.cache[Humanoid] = NewHandler
	return NewHandler
end

--[[Calls AnimatorModule.new, but asserts the RunService enviroment for the LSP to type check the specific Animator handler]]
function AnimatorModule.newClient(Humanoid: Humanoid): LocalAnimator
	assert(IsClient, "Can't call newClient() on Server!")
	return AnimatorModule.new(Humanoid)
end

--[[Calls AnimatorModule.new, but asserts the RunService enviroment for the LSP to type check the specific Animator handler]]
function AnimatorModule.newServer(Humanoid: Humanoid): ServerAnimator
	assert(not IsClient, "Can't call newServer() on Client!")
	return AnimatorModule.new(Humanoid) :: ServerAnimator
end

--[[Initializes the module, this only exists as a function for the Config, as Wally packages don't work well with Attribute configurations when they're consistently-reloaded dependencies.]]
function AnimatorModule.init(Config: Config?): AnimatorModule
    assert(not AnimatorModule.Initialized, "AnimatorModule has already been initialized.")
    AnimatorModule.Initialized = true

    if Config then
        if IsClient then
            warn("Initialization arguments are only used on the server.")
        else
            for key, value in Config do
                script:SetAttribute(key, value)
            end
        end
    end

    Config = {}:: Config
    for key,value in script:GetAttributes() do
        Config[key] = value
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
            if Config.NETWORK_DEBUG then
                print(string.format("[PlayerAnimator][Client] Received %s packet for Player %s with data:", dbug, tostring(data.player)), data)
            end
            if not player or not getHumanoidFromPlayer(player) then
                return
            end
            return callback(AnimatorModule.newClient(getHumanoidFromPlayer(player)), data)
        end)
    end

    local function ServerListenCallback(listener, callback: (data: { any }, Player, Animator: ServerAnimator?) -> ( any ), dbug: string)
        listener.listen(function(data, Player)
            if Config.NETWORK_DEBUG then
                print(string.format("[PlayerAnimator][Server] Received %s packet from Player %s with data:", dbug, tostring(Player.UserId)), data)
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
        --Establishing network connections

        ClientListenCallback(net.Animator.packets.LoadAnimation, function(animator, data)
            local priority = data.animationPriority ~= nil and AnimationPriorities[data.animationPriority] or Enum.AnimationPriority.Core
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

        task.spawn(function() --When testing my module, it would (for some reason) always hang on this function, and I could never figure out why.
            --Wrapping it in a callable method worked, but I also wrapped it in a new thread for extra safety... if anyone has answers for me I'd love to learn.
            local Preloads = net.Animator.queries.Init.invoke({ request = true })
            if Preloads then
                for Player,Anims in Preloads.data do
                    if not Players:GetPlayerByUserId(Player) then continue end
                    local Humanoid = getHumanoidFromPlayer(Players:GetPlayerByUserId(Player))
                    if not Humanoid then continue end
                    local Animator = AnimatorModule.newClient(Humanoid)
                    for GUID,TrackGhost in Anims do
                        local newTrack: AnimationTrack = Animator:LoadAnimationById(TrackGhost[1], 
                            false, 
                            AnimationPriorities[TrackGhost[2] ~= nil and TrackGhost[2] or 1000],
                            --we don't include Core AnimationPriority because 1000 is a big number and I only had this support uint8... it assumes nil means Core.
                            GUID)
                        if newTrack then
                            if TrackGhost[3] then Animator:AdjustSpeedByGUID(GUID, TrackGhost[3]) end
                            if TrackGhost[4] then Animator:AdjustWeightByGUID(GUID, TrackGhost[4], 0) end
                            newTrack.Looped = TrackGhost[5] or false
                        end
                    end
                end
            end
        end)

        if Config.UGC_EMOTES then
            local Commands = game:GetService("TextChatService"):WaitForChild("TextChatCommands", 10)
            if Commands and Commands:WaitForChild("RBXEmoteCommand", 5) then
                Commands:FindFirstChild("RBXEmoteCommand"):Destroy()

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
                        Humanoid:PlayEmoteAsync(Emotes[searchingFor][1]) --Invokes BindableFunction Character.Animate.PlayEmote, which is utilized in this package's AnimateHandler.
                    end
                end)
            else
                warn("[PlayerAnimator][Client] FAILED to start UGC_EMOTES initialization because of missing children.",
                    "[TextChatService.TextChatCommands]:",Commands,
                    "[TextChatCommands.RBXEmoteCommand]:",Commands:WaitForChild("RBXEmoteCommand", 5))
            end
        end
    else
        local function allExcept(Player: Player)
            local list = Players:GetPlayers()
            table.remove(list, table.find(list, Player))
            return list
        end

        if Config.UGC_EMOTES then
            local EmoteCache = {} :: {[number]: Animation}
            local PlayerEmotes = {} :: {[number]: {[string]: {number}}}
            local emotesFolder = Instance.new("Folder")
            emotesFolder.Name = "ugcEmotes"
            emotesFolder.Parent = script

            local function cleanupOwner(anim: Animation, userId: number, emoteId: number)
                local owners = string.split(anim:GetAttribute("Owners"), ",")
                local ownerIndex = table.find(owners, tostring(userId))
                if ownerIndex then
                    table.remove(owners, ownerIndex)
                    if #owners == 0 then
                        anim:Destroy()
                        EmoteCache[emoteId] = nil
                    else
                        anim:SetAttribute("Owners", table.concat(owners, ","))
                    end
                end
            end

            local function countEmotes(Emotes: {[string]:{number}})
                local count = 0
                for _,array in Emotes do
                    count += #array
                end
                return count
            end

            --[[
                You may be wondering, "Blackrus, why would you use InsertService:LoadAsset for UGC emotes? Doesn't that disqualify the module for the Roblox Marketplace?"
                And you'd be right, it does! But, Roblox's built-in emote wheel uses a RobloxScriptSecurity method called "Humanoid:PlayEmoteAndGetAnimTrackById()", this 
                is their way to get the sanitized animation ID on the client. As for how other players see this client-loaded emote, they automatically replicate it through 
                their Animator instance! InsertService is the loophole through this replication-less issue, except there are now extra steps to prevent weird exploits.

                "But Blackrus, how do you know Roblox used a RobloxScriptSecurity method in the first place?" I wouldn't have without MaximumADHD's Roblox-Client-Tracker repository.
                Here's the exact line that they use to sudo-load sanitized Roblox animation IDs on the client.
                https://github.com/MaximumADHD/Roblox-Client-Tracker/blob/roblox/scripts/CoreScripts/Modules/EmotesMenu/Thunks/PlayEmote.lua#L60
            ]]
            local function cacheEmotesForPlayer(player: Player)
                local LoadedEmotes = -1

                local function CacheEmotes(Character: Model)
                    local Humanoid = Character:WaitForChild("Humanoid", 3) :: Humanoid
                    if not Humanoid then
                        warn("Could not find Humanoid for", Character); return
                    end

                    local Description = Humanoid:GetAppliedDescription()
                    local Emotes = Description:GetEmotes()
                    local EmoteCount = countEmotes(Emotes)
                    if LoadedEmotes ~= EmoteCount then
                        PlayerEmotes[player.UserId] = Emotes
                        for _, Animations in Emotes do
                            for _, EmoteId in Animations do
                                if EmoteCache[EmoteId] then
                                    local anim = EmoteCache[EmoteId]
                                    if not string.find(anim:GetAttribute("Owners"), tostring(player.UserId)) then
                                        anim:SetAttribute("Owners", anim:GetAttribute("Owners")..","..tostring(player.UserId))
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
                                    continue
                                end
                            end
                        end
                        LoadedEmotes = EmoteCount
                    end
                end

                CacheEmotes(player.Character or player.CharacterAdded:Wait())
                player.CharacterAdded:Connect(CacheEmotes)
            end

            local function onPlayerRemoving(player: Player)
                for emoteId, anim in pairs(EmoteCache) do
                    if anim and anim:GetAttribute("Owners") then
                        cleanupOwner(anim, player.UserId, emoteId)
                    end
                end
                PlayerEmotes[player.UserId] = nil
            end

            Players.PlayerAdded:Connect(cacheEmotesForPlayer)
            Players.PlayerRemoving:Connect(onPlayerRemoving)

            for _, player in Players:GetPlayers() do
                cacheEmotesForPlayer(player)
            end

            --[[
                This is how the loophole in question works. Since I can't change how Roblox's CoreGUI scripts work, the player's emote will load and play on their client
                no matter what. Except it'll *only* play on their client, very similarly to how an AnimationTrack with Replicate set to false. One thing the developer CAN
                change is the player's StarterCharacterScripts, one of those being Roblox's Animate script. This is where their emote system gets weird, because the Animate
                script comes with a BindableFunction called PlayEmote. After some testing, I've found that Humanoid:PlayEmote() automatically fires the BindableFunction in 
                question, and I soon after discovered Humanoid:PlayEmoteAndGetAnimTrackById() does as well. The invoke passes through the Emote's name, as for why it only
                passes the name, I've forgotten!
            ]]
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

        --[[This is to ensure that initializing clients receive the information they need regardless of developer preference]]
        Players.PlayerAdded:Connect(function(Player)
            Player.CharacterAdded:Connect(function(Character)
                local Humanoid = Character:FindFirstChildOfClass("Humanoid") or Character:WaitForChild("Humanoid", 10)
                if not Humanoid then return end
                AnimatorModule.newServer(Humanoid)
            end)
        end)
        
        local InitializedPlayers = {} :: {[Player]: number}

        --[[I like to think of this as returning a bunch of TrackGhosts for the client animator to start with.]]
        net.Animator.queries.Init.listen(function(req, Player)
            assert(Player and not InitializedPlayers[Player])
            InitializedPlayers[Player] = os.clock()

            local totalReplicating = {}
            for _, animator in AnimatorModule.cache do
                if not animator or animator._destroyed or not animator._player or totalReplicating[animator._player.UserId] then
                    continue
                end
                totalReplicating[animator._player.UserId] = {}
                for GUID: string, FakeTrack: FakeTrack in animator.AnimationTracks do
                    if FakeTrack._ReplicateTo == nil then
                        totalReplicating[animator._player.UserId][GUID] = {
                            [1] = FakeTrack.AnimationId,
                            [2] = FakeTrack.Priority.Value ~= 1000 and FakeTrack.Priority.Value or nil, 
                            [3] = FakeTrack.Speed ~= 1 and FakeTrack.Speed or nil,
                            [4] = FakeTrack.Weight ~= 1 and FakeTrack.Weight or nil,
                            [5] = FakeTrack.Looped or nil
                        }
                    end
                end
            end

            return { data = totalReplicating }
        end)

        --Establishing network connections

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
end

return AnimatorModule:: AnimatorModule