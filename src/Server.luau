local Janitor = require("../Janitor")
local net = require("./net")
local types = require("./types")
local Players = game:GetService("Players")
local Http = game:GetService("HttpService")

type TrackArguments = types.TrackArguments
type ServerAnimator = types.ServerAnimator
type FakeTrack = types.FakeTrack

local module = {}
module.__index = module

local function allExcept(Player: Player, t: {Player}?)
	t = t or Players:GetPlayers()
	table.remove(t, table.find(t, Player))
	return t
end

local FakeTrack = {}
FakeTrack.__index = FakeTrack
function FakeTrack.new(AnimationId: string, TrackArguments: TrackArguments?, ReplicateTo: {Player}?, _clientGUID: string?, ServerAnimator: ServerAnimator): FakeTrack?
	if not ServerAnimator then return nil end
	if not AnimationId or AnimationId == "" then warn("Invalid AnimationId!",AnimationId,ServerAnimator._humanoid); return nil end
	local self = setmetatable({
		IsPlaying = false;
		TimePosition = 0;
		Length = 0;
		Looped = TrackArguments and TrackArguments.Looped or false;
		_LoopPreference = TrackArguments and TrackArguments.Looped or nil;
		Speed = TrackArguments and TrackArguments.Speed or 1;
		Weight = TrackArguments and TrackArguments.Weight or 1;
		Priority = TrackArguments and TrackArguments.AnimationPriority or Enum.AnimationPriority.Action;
		AnimationId = AnimationId;
		_ReplicateTo = ReplicateTo;
		_GUID = _clientGUID or Http:GenerateGUID();
		_ClientReplicated = _clientGUID ~= nil;
	},FakeTrack)
	ServerAnimator.AnimationTracks[self._GUID] = self

	local function SendPacket(Packet, Data)
		if self._ClientReplicated then
			Packet.sendToList(Data, allExcept(ServerAnimator._player, self._ReplicatedOn))
		elseif self._ReplicateTo == nil then
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
		SendPacket(net.Animator.packets.LoadAnimation, packet)
	end
	
	--[[Server stop an animation using the animation track]]
	function self.Stop(self: FakeTrack, fadeTime: number?)
		SendPacket(net.Animator.packets.Stop, {
			player = ServerAnimator._player.UserId,
			fadeTime = fadeTime,
			gUID = self._GUID
		})
	end
	
	--[[Server play an animation using the animation track]]
	function self.Play(self: FakeTrack, fadeTime: number?, weight: number?, speed: number?, customPlayer: boolean?)
		SendPacket(net.Animator.packets.Play, {
			player = ServerAnimator._player.UserId,
			gUID = self._GUID,
			fadeTime = fadeTime,
			weight = weight,
			speed = speed,
			customPlayer = customPlayer
		})
	end
	
	--[[Adjust the speed of an animation using the animation track]]
	function self.AdjustSpeed(self: FakeTrack, speed: number?)
		SendPacket(net.Animator.packets.AdjustSpeed, {
			player = ServerAnimator._player.UserId,
			gUID = self._GUID,
			speed = speed
		})
	end
	
	--[[Adjust the weight of an animation using the animation track]]
	function self.AdjustWeight(self: FakeTrack, weight: number?, fadeTime: number?)
		SendPacket(net.Animator.packets.AdjustWeight, {
			player = ServerAnimator._player.UserId,
			gUID = self._GUID,
			weight = weight,
			fadeTime = fadeTime
		})
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
			net.Animator.packets.Destroy.sendToList({ gUID = self._GUID, player = ServerAnimator._player.UserId }, deleteFrom)
		end

		self._ReplicateTo = players

		if players and #newReplicateTo > 0 then
			SendPacket(net.Animator.packets.LoadAnimation.sendToList({
				player = ServerAnimator._player.UserId,
				gUID = self._GUID,
				animationId = self.AnimationId,
				animationPriority = self.Priority.Value ~= 1000 and self.Priority.Value or nil,
				speed = self.Speed ~= 1 and self.Speed or nil,
				weight = self.Weight ~= 1 and self.Weight or nil,
				looped = self._LoopPreference
			}, newReplicateTo))
		end
	end

	--[[Destroys the fake animation track, _replicateToAllExcept is only used internally, don't use it in normal code.]]
	function self.Destroy(self: FakeTrack, _replicateToAllExcept: Player?)
		self:Stop()
		ServerAnimator.AnimationTracks[self._GUID] = nil
		if self._ClientReplicated then
			local packetData = { player = ServerAnimator._player.UserId, gUID = self._GUID }
			if _replicateToAllExcept then
				net.Animator.packets.Destroy.sendToList(packetData, allExcept(_replicateToAllExcept, self._ReplicatedOn))
			elseif self._ReplicateTo ~= nil then
				net.Animator.packets.Destroy.sendToList(packetData, self._ReplicateTo)
			else
				net.Animator.packets.Destroy.sendToAll(packetData)
			end
		end
		setmetatable(self, nil)
		table.clear(self)
		self = nil
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
	function self.LoadAnimation(self: ServerAnimator, Animation: Animation|string, forceNew: boolean?, TrackArguments: TrackArguments?, ReplicateTo: {Player}?, _clientGUID: string?): FakeTrack?
		local targetID: string
		if type(Animation) == "string" then
			targetID = Animation
		else
			targetID = Animation.AnimationId
		end
		if _clientGUID and self.AnimationTracks[_clientGUID] then return self.AnimationTracks[_clientGUID] end
		if forceNew ~= true then
			for guid: string, track: FakeTrack in self.AnimationTracks do
				if (_clientGUID ~= nil) == track._ClientReplicated and track.AnimationId == targetID then
					return track
				end
			end
		end
		local Track = self._jan:Add(FakeTrack.new(targetID, TrackArguments, ReplicateTo, _clientGUID, self))
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

return module