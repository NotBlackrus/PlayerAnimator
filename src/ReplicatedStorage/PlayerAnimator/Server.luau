local Janitor = require("./dependencies/Janitor")
local net = require("./dependencies/net")
local Players = game:GetService("Players")
local Http = game:GetService("HttpService")

local module = {}
module.__index = module

export type FakeTrack = {
	__index : FakeTrack,
	IsPlaying : boolean,
	TimePosition : number,
	Length : number,
	Looped : boolean,
	Speed : number,
	Weight : number,
	AnimationPriority : Enum.AnimationPriority,
	_GUID : string,
	_ClientReplicated : boolean,
	AnimationId : string,
	
	Stop : (self: FakeTrack, fadeTime: number?) -> (),
	Play : (self: FakeTrack, fadeTime: number?, weight: number?, speed: number?, customPlayer: boolean?) -> (),
	AdjustSpeed : (self: FakeTrack, speed: number) -> (),
	AdjustWeight : (self: FakeTrack, weight: number, fadeTime: number?) -> (),
	Destroy : (self: FakeTrack, _replicateToAllExcept: Player?) -> (),
	
	new : (AnimationId: string, AnimationPriority: Enum.AnimationPriority?, _clientGUID: string?, ServerAnimator: ServerAnimator) -> FakeTrack?
}

export type ServerAnimator = {
	__index : ServerAnimator,
	_humanoid : Humanoid,
	AnimationTracks : {[string]: FakeTrack},
	_destroyed: boolean,
	_jan : Janitor.Janitor,
	_player : Player,
	Enabled: boolean,
	
	LoadAnimation : (self: ServerAnimator, Animation: Animation|string, AnimationPriority: Enum.AnimationPriority?, recycleAnim: boolean, _clientGUID: string?) -> FakeTrack?,
	Destroy : (self: ServerAnimator) -> (),
}

local FakeTrack = {}
FakeTrack.__index = FakeTrack
function FakeTrack.new(AnimationId: string, AnimationPriority: Enum.AnimationPriority?, _clientGUID: string?, ServerAnimator: ServerAnimator): FakeTrack?
	if not ServerAnimator then return nil end
	if not AnimationId or AnimationId == "" then warn("Invalid AnimationId!",AnimationId,ServerAnimator._humanoid) return nil end
	AnimationPriority = AnimationPriority or Enum.AnimationPriority.Core
	local self = setmetatable({
		IsPlaying = false;
		TimePosition = 0;
		Length = 0;
		Looped = false;
		Speed = 1;
		Weight = 1;
		AnimationPriority = AnimationPriority;
		AnimationId = AnimationId;
		_GUID = _clientGUID or Http:GenerateGUID();
		_ClientReplicated = _clientGUID ~= nil;
	},FakeTrack)
	ServerAnimator.AnimationTracks[self._GUID] = self
	if not _clientGUID and ServerAnimator and ServerAnimator._player then
		net.Animator.packets.LoadAnimation.sendToAll({ player = ServerAnimator._player, animationPriority = AnimationPriority.Value, animationId = AnimationId, gUID = self._GUID })
	end
	
	--[[Server stop an animation using the animation track]]
	function self.Stop(self: FakeTrack, fadeTime: number?)
		net.Animator.packets.Stop.sendToAll({ player = ServerAnimator._player, fadeTime = fadeTime, gUID = self._GUID })
	end
	
	--[[Server play an animation using the animation track]]
	function self.Play(self: FakeTrack, fadeTime: number?, weight: number?, speed: number?, customPlayer: boolean?)
		net.Animator.packets.Play.sendToAll({player = ServerAnimator._player, gUID = self._GUID, fadeTime = fadeTime, weight = weight, speed = speed, customPlayer = customPlayer})
	end
	
	--[[Adjust the speed of an animation using the animation track]]
	function self.AdjustSpeed(self: FakeTrack, speed: number?)
		net.Animator.packets.AdjustSpeed.sendToAll({player = ServerAnimator._player, gUID = self._GUID , speed = speed})
	end
	
	--[[Adjust the weight of an animation using the animation track]]
	function self.AdjustWeight(self: FakeTrack, weight: number?, fadeTime: number?)
		net.Animator.packets.AdjustWeight.sendToAll({player = ServerAnimator._player, gUID = self._GUID, weight = weight, fadeTime = fadeTime})
	end
	
	--[[Destroys the fake animation track, _replicateToAllExcept is only used internally, don't use it in normal code.]]
	function self:Destroy(_replicateToAllExcept: Player?)
		local self = self :: FakeTrack
		self:Stop()
		ServerAnimator.AnimationTracks[self._GUID] = nil
		if self._ClientReplicated then
			if _replicateToAllExcept then
				net.Animator.packets.Destroy.sendToAllExcept({ player = ServerAnimator._player, gUID = self._GUID }, _replicateToAllExcept)
			else
				net.Animator.packets.Destroy.sendToAll({ player = ServerAnimator._player, gUID = self._GUID })
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
	if self._humanoid:FindFirstChildOfClass("Animator") then
		self._humanoid:FindFirstChildOfClass("Animator"):Destroy()
	end
	self.AnimationTracks = {} :: {[string]:FakeTrack} --List of GUIDs that are loaded from the server
	self._destroyed = false
	self._jan = Janitor.new()
	self._player = Players:GetPlayerFromCharacter(self._humanoid.Parent) :: Player
	self.Enabled = self._player ~= nil

	--[[
	Server load an animation onto the Character's Animator.
	recycleAnim for reuse of an already loaded animation track, default is false
	]]
	function self.LoadAnimation(self: ServerAnimator, Animation: Animation|string, AnimationPriority: Enum.AnimationPriority?, recycleAnim: boolean?, _clientGUID: string?): FakeTrack?
		local targetID: string
		if type(Animation) == "string" then
			targetID = Animation
		else
			targetID = Animation.AnimationId
		end
		if _clientGUID and self.AnimationTracks[_clientGUID] then return self.AnimationTracks[_clientGUID] end
		if recycleAnim ~= false then
			for guid: string, track: FakeTrack in self.AnimationTracks do
				if track.AnimationId == targetID then
					return track
				end
			end
		end
		local Track = self._jan:Add(FakeTrack.new(targetID, AnimationPriority, _clientGUID, self))
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