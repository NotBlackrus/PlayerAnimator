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

local Janitor = 		require("../Janitor")
local Signal = 			require("./signalplus")
local net = 			require("./net")
local types = 			require("./types")
local Players = 		game:GetService("Players")
local Http = 			game:GetService("HttpService")
local RunService =		game:GetService("RunService")

type TrackArguments = types.TrackArguments
type ServerAnimator = types.ServerAnimator
type FakeTrack = types.FakeTrack
type Config = types.Config
type ReceivedClientInfo = types.ReceivedClientInfo

local Config = {}:: Config
for key,value in script.Parent:GetAttributes() do
    Config[key] = value
end

local module = {}
module.__index = module

--[[We create a fake Animation playing enviroment so that the server may receive animation-based signals, this isn't 100% accurate as only the clients have the animations.]]
local playingTracks = {}:: {FakeTrack}
RunService.PostSimulation:Connect(function(dT: number)
	for TrackIndex,Track in playingTracks do
		local newTime = Track.TimePosition + dT * Track.Speed
		if Track.WeightTarget ~= Track.WeightCurrent then
			Track._WeightTransitionProgress = math.min(Track._WeightTransitionTime, Track._WeightTransitionProgress + dT)
			Track.WeightCurrent = math.lerp(Track._WeightStartTarget, Track.WeightTarget, Track._WeightTransitionProgress/Track._WeightTransitionTime) --we math dot LARP...
		end
		if not Track._ClientClarified then
			Track.TimePosition = newTime --Save the raw amount of time that has passed before the client has clarified
		elseif Track.Looped then
			Track.TimePosition = newTime%Track.Length
		else
			Track.TimePosition = math.min(newTime, Track.Length)
		end

		if Track._ClientClarified and newTime > Track.Length then
			if Track.Looped then
				for i = 1, math.floor(newTime/Track.Length) do --In case the track has been clarified after 1 or more full cycles (rare but just in case).
					Track.DidLoop:Fire()
					task.wait() --defer one after the other, so that scripts do not exhaust themselves and to hopefully prevent bugs in developers code.
				end
			else
				Track:Stop(nil, true)
			end
		end
	end
end)

--[[Our little makeshift-query for server.]]
local requests = {} :: {[FakeTrack] : {Player}}
local animationCache = {} :: {[string] : {number|boolean}} --[AnimationId] = {[1] = length, [2] = looped}
local function requestTrackInfo(fakeTrack: FakeTrack, owningPlayer: Player, Player: Player)
	if requests[fakeTrack] == nil or fakeTrack.Length ~= 0 then return true end
	if animationCache[fakeTrack.AnimationId] then
		fakeTrack.Length = animationCache[fakeTrack.AnimationId][1]
		fakeTrack._LoopPreference = animationCache[fakeTrack.AnimationId][2]
		fakeTrack.Looped = fakeTrack.Looped or fakeTrack._LoopPreference
		return true
	end
	table.insert(requests[fakeTrack], Player)
	net.Animator.packets.TrackRequest.sendTo( { gUID = fakeTrack._GUID, player = owningPlayer.UserId } , Player)
	local timeOut = 0
	repeat 
		task.wait(0.1)
		timeOut += 0.1
	until animationCache[fakeTrack.AnimationId] ~= nil or requests[fakeTrack] == nil or timeOut > 1
	return requests[fakeTrack] == nil or animationCache[fakeTrack.AnimationId] ~= nil
end

net.Animator.packets.TrackRequest.listen(function(data, Player)
	if not Player then return end
	if Config.NETWORK_DEBUG then
		print(string.format("[PlayerAnimator][Server] Received %s packet from Player %s with data:", "TrackRequest", tostring(Player.UserId)), data)
	end
	assert(data.gUID ~= nil and data.length ~= nil and data.looped ~= nil, "[PlayerAnimator][Server] Missing TrackRequest information from",Player)
	for fakeTrack, players in requests do
		if fakeTrack._GUID == data.gUID and table.find(players, Player) then
			animationCache[fakeTrack.AnimationId] = {[1] = data.length; [2] = data.looped}
			requests[fakeTrack] = nil
			break
		end
	end
end)

local function allExcept(Player: Player, t: {Player}?)
	t = t or Players:GetPlayers()
	table.remove(t, table.find(t, Player))
	return t
end

local FakeTrack = {}
FakeTrack.__index = FakeTrack
function FakeTrack.new(AnimationId: string, TrackArguments: TrackArguments?, ReplicateTo: {Player}?, _clientInfo: ReceivedClientInfo?, ServerAnimator: ServerAnimator): FakeTrack?
	if not ServerAnimator then return nil end
	if not AnimationId or AnimationId == "" then warn("[PlayerAnimator][Server] Invalid AnimationId!",AnimationId,ServerAnimator._humanoid); return nil end
	local self = setmetatable({
		IsPlaying = false;
		TimePosition = 0;
		Length = animationCache[AnimationId] and animationCache[AnimationId][1] or 0;
		Looped = TrackArguments and TrackArguments.Looped or false;
		_LoopPreference = (animationCache[AnimationId] and animationCache[AnimationId][2]) or (TrackArguments and TrackArguments.Looped) or nil;
		Speed = TrackArguments and TrackArguments.Speed or 1;
		WeightCurrent = TrackArguments and TrackArguments.Weight or 1;
		WeightTarget = TrackArguments and TrackArguments.Weight or 1;
		_WeightStartTarget = TrackArguments and TrackArguments.Weight or 1;
		_WeightTransitionTime = 0.1;
		_WeightTransitionProgress = 0;
		Priority = TrackArguments and TrackArguments.AnimationPriority or Enum.AnimationPriority.Action;
		AnimationId = AnimationId;
		_ReplicateTo = ReplicateTo;
		_GUID = _clientInfo ~= nil and _clientInfo._gUID or Http:GenerateGUID();
		_ClientReplicated = _clientInfo ~= nil;
		_ClientClarified = false;
		Ended = Signal();
		DidLoop = Signal();
		Stopped = Signal();
		Destroying = Signal();
	},FakeTrack)
	ServerAnimator.AnimationTracks[self._GUID] = self

	local function NETWORK_DEBUG(Name, Target, Data)
		if Config.NETWORK_DEBUG then
			warn(
				"[PlayerAnimator][Server] Sending "..Name.." packet from "..(self._ClientReplicated and "Client" or "Server").."-based track to ",
				Target or "EVERYONE",
				" with data: ", 
				Data
			)
		end
	end

	local function SendPacket(Packet, Data, dbug)
		NETWORK_DEBUG(dbug, self._ReplicateTo, Data)
		if self._ClientReplicated then
			Packet.sendToList(Data, allExcept(ServerAnimator._player, self._ReplicatedOn))
		elseif self._ReplicateTo == nil then
			if Config.NETWORK_DEBUG then
				warn(string.format("[PlayerAnimator][Server] Sending %s packet to all with data: ", dbug), Data)
			end
			Packet.sendToAll(Data)
		elseif #self._ReplicateTo > 0 then
			Packet.sendToList(Data, self._ReplicateTo)
		end
	end

	if ServerAnimator._player then
		local packet = {
			player = ServerAnimator._player.UserId,
			gUID = self._GUID,
			animationId = AnimationId,
			animationPriority = self.Priority.Value ~= 1000 and self.Priority.Value or nil,
			speed = self.Speed ~= 1 and self.Speed or nil,
			weight = self.Weight ~= 1 and self.Weight or nil,
			looped = self._LoopPreference
		}
		SendPacket(net.Animator.packets.LoadAnimation, packet, "LoadAnimation")
	end
	
	--[[Server stop an animation using the animation track]]
	function self.Stop(self: FakeTrack, fadeTime: number?, _silently: boolean?)
		self.TimePosition = 0
		if self.IsPlaying then
			self.IsPlaying = false
			table.remove(playingTracks, table.find(playingTracks, self))
			self.Stopped:Fire()
			task.delay(fadeTime or 0.1, function()
				self.Ended:Fire()
			end)
		end
		if not _silently then
			SendPacket(net.Animator.packets.Stop, {
				player = ServerAnimator._player.UserId,
				fadeTime = fadeTime,
				gUID = self._GUID
			}, "Stop")
		end
	end
	
	--[[Server play an animation using the animation track]]
	function self.Play(self: FakeTrack, fadeTime: number?, weight: number?, speed: number?, customPlayer: boolean?)
		self.TimePosition = 0
		if not self.IsPlaying then
			self.IsPlaying = true
			table.insert(playingTracks, self)
		end
		SendPacket(net.Animator.packets.Play, {
			player = ServerAnimator._player.UserId,
			gUID = self._GUID,
			fadeTime = fadeTime,
			weight = weight,
			speed = speed,
			customPlayer = customPlayer
		}, "Play")
	end
	
	--[[Adjust the speed of an animation using the animation track]]
	function self.AdjustSpeed(self: FakeTrack, speed: number?)
		self.Speed = speed
		SendPacket(net.Animator.packets.AdjustSpeed, {
			player = ServerAnimator._player.UserId,
			gUID = self._GUID,
			speed = speed
		}, "AdjustSpeed")
	end
	
	--[[Adjust the weight of an animation using the animation track]]
	function self.AdjustWeight(self: FakeTrack, weight: number?, fadeTime: number?)
		self._WeightTransitionProgress = 0
		self._WeightTransitionTime = fadeTime or 0.1
		self.WeightTarget = weight
		SendPacket(net.Animator.packets.AdjustWeight, {
			player = ServerAnimator._player.UserId,
			gUID = self._GUID,
			weight = weight,
			fadeTime = fadeTime
		}, "AdjustWeight")
	end
	
	--[[Replicate the animation track to specific players, if ReplicateTo is nil, it replicates to everyone, if it's an empty table, it replicates to no one.]]
	function self.SetReplicateTo(self: FakeTrack, players: {Player}?)
		local newReplicateTo = players

		if self._ReplicateTo and players then
			local deleteFrom = {}
			for _, player in pairs(self._ReplicatedOn) do
				if not table.find(players, player) then
					table.insert(deleteFrom, player)
				end
			end
			for _, player in pairs(players) do
				if table.find(self._ReplicateTo) then
					table.remove(newReplicateTo, table.find(newReplicateTo, player))
				end
			end
			if #deleteFrom > 0 then
				local destroyPacket = { gUID = self._GUID, player = ServerAnimator._player.UserId }

				NETWORK_DEBUG("Destroy", deleteFrom, destroyPacket)
				net.Animator.packets.Destroy.sendToList(destroyPacket, deleteFrom)
			end
		end

		self._ReplicateTo = players

		if players and #newReplicateTo > 0 then
			local loadPacket = {
				player = ServerAnimator._player.UserId,
				gUID = self._GUID,
				animationId = self.AnimationId,
				animationPriority = self.Priority.Value ~= 1000 and self.Priority.Value or nil,
				speed = self.Speed ~= 1 and self.Speed or nil,
				weight = self.Weight ~= 1 and self.Weight or nil,
				looped = self._LoopPreference
			}

			NETWORK_DEBUG("LoadAnimation", newReplicateTo, loadPacket)
			net.Animator.packets.LoadAnimation.sendToList(loadPacket, newReplicateTo)
		end
	end

	--[[Destroys the fake animation track, _ReplicateToAllExcept is only used internally, don't use it in normal code.]]
	function self.Destroy(self: FakeTrack, _ReplicateToAllExcept: Player?)
		self:Stop()
		ServerAnimator.AnimationTracks[self._GUID] = nil
		if self._ClientReplicated then
			local packetData = { player = ServerAnimator._player.UserId, gUID = self._GUID }
			
			local targets = self._ReplicateTo
			
			if targets == nil or #targets == 0 then targets = Players:GetPlayers() end
			if _ReplicateToAllExcept then
				targets = allExcept(_ReplicateToAllExcept, targets)
			end

			NETWORK_DEBUG("Destroy", targets, packetData)
			net.Animator.packets.Destroy.sendToList(packetData, targets)
		end
		self.Destroying:Fire()
		task.defer(function()
			self.Ended:Destroy()
			self.Stopped:Destroy()
			self.DidLoop:Destroy()
			self.Destroying:Destroy()
			setmetatable(self, nil)
			table.clear(self)
			self = nil
		end)
	end

	--[[time to loop until it finds a suitable client with the proper information needed for the server's fake track!]]
	if animationCache[self.AnimationId] then
		self.Length = animationCache[self.AnimationId][1]
		self._LoopPreference = animationCache[self.AnimationId][2]
		self.Looped = self._LoopPreference or self.Looped
		self._ClientClarified = true
	else --VERY crude implementation of an invoke system, but we make with what we have right
		local success = false
		local attempts = 0
		local function getPlayer()
			local pool = self._ReplicateTo
			if pool == nil or #pool < 1 then pool = Players:GetPlayers() end
			return pool[math.random(1,#pool)]
		end
		local target = nil
		requests[self] = {}
		repeat 
			task.wait(1)
			attempts += 1
			target = getPlayer()
			NETWORK_DEBUG("TrackRequest", target, { gUID = self._GUID })
			success = requestTrackInfo(self, ServerAnimator._player, target) 
		until attempts > 5 or requests[self] == nil
		if animationCache[self.AnimationId] then
			self.Length = animationCache[self.AnimationId][1]
			self._LoopPreference = animationCache[self.AnimationId][2]
			self.Looped = self._LoopPreference or self.Looped
			self._ClientClarified = true
		elseif not self._ClientClarified then
			warn(string.format("[PlayerAnimator][Server] Attempted to receive track information from random clients. Gave up after %s attempts.", attempts))
		end
	end

	return self
end

function module.new(Humanoid: Humanoid): ServerAnimator
	local self = setmetatable({},module)
	self._humanoid = Humanoid :: Humanoid
	task.spawn(function()
		if self._humanoid:FindFirstChildOfClass("Animator") or self._humanoid:WaitForChild("Animator", 3) then
			self._humanoid:FindFirstChildOfClass("Animator"):Destroy()
		end
	end)
	self.AnimationTracks = {} :: {[string]:FakeTrack} --List of GUIDs that are loaded from the server
	self._destroyed = false
	self._jan = Janitor.new()
	self._player = Players:GetPlayerFromCharacter(self._humanoid.Parent) :: Player
	self.Enabled = self._player ~= nil

	--[[
	Server load an animation onto the Character's Animator.
	forceNew for creating a new animation track even if an identical one is already loaded, default is false
	ReplicateTo is a table of players to replicate the animation to, if nil, it replicates to everyone, if empty, it replicates to no one
	]]
	function self.LoadAnimation(self: ServerAnimator, Animation: Animation|string, forceNew: boolean?, TrackArguments: TrackArguments?, ReplicateTo: {Player}?, _clientInfo: ReceivedClientInfo?): FakeTrack?
		local targetID: string
		if type(Animation) == "string" then
			targetID = Animation
		else
			targetID = Animation.AnimationId
		end
		if _clientInfo and self.AnimationTracks[_clientInfo._gUID] then return self.AnimationTracks[_clientInfo._gUID] end
		if forceNew ~= true then
			for guid: string, track: FakeTrack in self.AnimationTracks do
				if (_clientInfo ~= nil) == track._ClientReplicated and track.AnimationId == targetID then
					return track
				end
			end
		end
		local Track = self._jan:Add(FakeTrack.new(targetID, TrackArguments, ReplicateTo, _clientInfo, self))
		self.AnimationTracks[Track._GUID] = Track
		return Track
	end

	function self.Destroy(self: ServerAnimator)
		if not self._destroyed then
			self._destroyed = true
			self._jan:Destroy()
			self._jan = nil
			setmetatable(self,nil)
		end
	end

	function self.GetPlayingAnimationTracks(self: ServerAnimator)
		local playing = {}
		for _,v in self.AnimationTracks do
			if v.IsPlaying then
				table.insert(playing, v)
			end
		end
		return playing
	end

	if self._humanoid.RootPart then
		self._humanoid.RootPart.Destroying:Once(function()
			self:Destroy()
		end)
	else
		self._humanoid.Destroying:Once(function()
			self:Destroy()
		end)
	end

	return self
end

function module:_setConfig(Config: Config)
	Config = Config
end

return module