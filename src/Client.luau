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

local net = require("./net")
local types = require("./types")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Http = game:GetService("HttpService")
local RunService = game:GetService("RunService")

type TrackArguments = types.TrackArguments
type LocalAnimator = types.LocalAnimator
type TrackGhost = types.TrackGhost
type Config = types.Config

local Config = {}:: Config
for key,value in script.Parent:GetAttributes() do
    Config[key] = value
end

local module = {}
module.__index = module

function module.new(Humanoid: Humanoid): LocalAnimator
	local self = setmetatable({},module)
	self._humanoid = Humanoid :: Humanoid
	self.AnimationTracks = {} :: {[string]:AnimationTrack|string} --indexed by GUID, string is encoded json data for the server-replicated unused animation for recovery purposes- and to save some memory
	self.LastUse = {} :: {[AnimationTrack]: number} --tracking the last use of an animation track, this will be used to garbage collect unused (but loaded) animations until they're used again
	self.Animator = Instance.new("Animator", self._humanoid) :: Animator
	self._destroyed = false
	self.Player = Players:GetPlayerFromCharacter(self._humanoid.Parent)
	self.customPlayer = {} :: {[AnimationTrack]: {speed: number, timePosition: number}}
	self._customConnection = RunService.PreRender:Connect(function(dT)
		for a,b in self.customPlayer do
			local updatedTime = b.timePosition + (dT * b.speed)

			a.TimePosition = a.Looped and updatedTime%a.Length or math.min(updatedTime, a.Length)
			if updatedTime >= a.Length then
				if a.Looped then
					updatedTime = updatedTime - a.Length
				else
					self.customPlayer[a] = nil
					a:Stop()
				end
			end
			if a and self.customPlayer[a] then
				self.customPlayer[a].timePosition = updatedTime
			end
		end
		if Config.GARBAGE_TIMER == -1 then return end -- if the timer is set to -1, garbage collection is disabled
		for guid, track in self.AnimationTracks do
			if type(track) ~= "string" and track:GetAttribute("Replicated") == false then
				if self.LastUse[track] and os.time() - self.LastUse[track] >= Config.GARBAGE_TIMER then
					if track.IsPlaying then
						if Config.GARBAGE_DEBUG then
							warn("Animation track with GUID: "..guid.." is inactive but currently playing, resetting last use time instead of garbage collecting.")
						end
						self.LastUse[track] = os.time() -- if the track is currently playing, reset its last use time instead of garbage collecting it
					else
						if Config.GARBAGE_DEBUG then
							warn("Garbage collecting animation track with GUID: "..guid.." due to inactivity.")
						end
						self.LastUse[track] = nil
						self.AnimationTracks[guid] = Http:JSONEncode({
							AnimationId = track:GetAttribute("AnimationId"),
							Speed = track.Speed,
							Weight = track.WeightTarget or track.WeightCurrent,
							Looped = track.Looped,
							Priority = track.Priority
						})
						track:Destroy()
					end
				end
			end
		end
	end)
	
	--[[Locally play an animation using only the animation's unique GUID
	Generally discouraged to regularly use, this function only exists for calls from the server.
	customPlayer adds the track to a PreRender connection's table to progress the animation's TimePosition by framerate, may result in markers being missed, result is reliable for audio synchronizing.]]
	function self.PlayByGUID(self: LocalAnimator, GUID: string, fadeTime: number?, weight: number?, speed: number?, customPlayer: boolean?): AnimationTrack?
		local track = self.AnimationTracks[GUID]
		if not track then return nil end
		if type(track) == "string" and self._humanoid and self.Animator then --begin animation recovery
			if Config.GARBAGE_DEBUG then
				warn("Recovering animation track with GUID: "..GUID.." from encoded data: "..track)
			end
			local revivalAnim = Instance.new("Animation")
			local revivalData: TrackGhost = Http:JSONDecode(track)
			revivalAnim.AnimationId = revivalData.AnimationId
			local revivalTrack = self:LoadAnimation(revivalAnim)
			if not revivalTrack then return nil end
			revivalTrack:SetAttribute("Replicated", false)
			revivalTrack:SetAttribute("GUID", GUID)
			revivalTrack:SetAttribute("AnimationId", revivalData.AnimationId)
			revivalTrack:AdjustSpeed(revivalData.Speed)
			revivalTrack:AdjustWeight(revivalData.Weight, 0)
			revivalTrack.Priority = revivalData.Priority
			self.AnimationTracks[GUID] = revivalTrack
			track = revivalTrack
		end
		track:Play(fadeTime, weight, speed)
		self.LastUse[track] = os.time()
		if Config.DEFAULT_CUSTOM_PLAYER == true and customPlayer ~= false or customPlayer == true then
			track:AdjustSpeed(0)
			if speed == nil then speed = 1 end
			self.customPlayer[track] = {speed = speed, timePosition = 0}
		end
		return track
	end
	
	--[[Locally play an animation using the animation track, with autonomous replication (if replication enabled)
	customPlayer adds the track to a PreRender connection's table to progress the animation's TimePosition by framerate, may result in markers being missed, result is reliable for audio synchronizing.]]
	function self.Play(self: LocalAnimator, AnimationTrack: AnimationTrack, fadeTime: number?, weight: number?, speed: number?, customPlayer: boolean?)
		if AnimationTrack:GetAttribute("Replicated") == true and self.Player == LocalPlayer then
			net.Animator.packets.Play.send({gUID = AnimationTrack:GetAttribute("GUID"), fadeTime = fadeTime, weight = weight, speed = speed})
		end
		
		AnimationTrack:Play(fadeTime,weight,speed)
		self.LastUse[AnimationTrack] = os.time()
		if Config.DEFAULT_CUSTOM_PLAYER == true and customPlayer ~= false or customPlayer == true then
			AnimationTrack:AdjustSpeed(0)
			if speed == nil then speed = 1 end
			self.customPlayer[AnimationTrack] = {speed = speed, timePosition = 0}
		end
	end
	
	--[[Locally stop an animation using only the animation's unique ID
	Generally discouraged to regularly use, this function only exists for calls from the server.]]
	function self.StopByGUID(self: LocalAnimator, GUID: string, fadeTime: number?): AnimationTrack?
		local track = self.AnimationTracks[GUID]
		if not track then return nil end
		track:Stop(fadeTime)
		self.LastUse[track] = os.time()
		return track
	end
	
	--[[Locally stop an animation using the animation track, with autonomous replication (if replication enabled)]]
	function self.Stop(self: LocalAnimator, AnimationTrack: AnimationTrack, fadeTime: number?)
		if AnimationTrack:GetAttribute("Replicated") == true and self.Player == LocalPlayer then
			net.Animator.packets.Stop.send({gUID = AnimationTrack:GetAttribute("GUID"), fadeTime = fadeTime})
		end
		self.customPlayer[AnimationTrack] = nil
		AnimationTrack:Stop(fadeTime)
		self.LastUse[AnimationTrack] = os.time()
	end
	
	--[[Forcefully stop all playing animations]]
	function self.StopAll(self: LocalAnimator, fadeTime: number?, replicate: boolean?)
		if self.Animator then
			for i,v: AnimationTrack in self.Animator:GetPlayingAnimationTracks() do
				if replicate == true then
					self:Stop(v, fadeTime)
				else
					v:Stop(fadeTime)
					self.LastUse[v] = os.time()
				end
			end
		end
	end
	
	--[[Locally load an animation onto the Character's Animator using only the animation's unique ID
	Automatically deletes the Animation instance after 8 seconds
	
	Replicated makes the animation load on all clients. Once played on the main client, the animation track will play on all clients.
	REPLICATED IS INPUT-SENSITIVE, SET TO NIL IF YOU DON'T WANT REPLICATION.
	True - This current client will send a message to all other clients to replicate with False
	False - This current client is receiving a replicated animation
	Nil - This current client will be the only one with this animation]]
	function self.LoadAnimationById(self: LocalAnimator, AnimationId: string, Replicate: true|false|nil, TrackArguments: TrackArguments?, _serverGUID: string?)
		local Animation = Instance.new("Animation")
		Animation.AnimationId = AnimationId
		game:GetService("Debris"):AddItem(Animation, 8)

		return self:LoadAnimation(Animation, Replicate, TrackArguments, _serverGUID)
	end

	--[[Locally unloads an animation
	
	Generally discouraged.]]
	function self.DestroyAnimationByGUID(self: LocalAnimator, GUID: string)
		local track = self.AnimationTracks[GUID]
		if track then
			if self.LastUse[track] then
				self.LastUse[track] = nil
			end
			track:Destroy()
		end
	end

	--[[Locally load an animation onto the Character's Animator
	
	Replicated makes the animation load on all clients. Once played on the main client, the animation track will play on all clients.
	REPLICATED IS A 3-VALUE ARGUMENT, SET TO NIL IF YOU DON'T WANT REPLICATION.
	True - This current client will send a message to all other clients to replicate with False
	False - This current client is receiving a replicated animation
	Nil - This current client will be the only one with this animation]]
	function self.LoadAnimation(self: LocalAnimator, Animation: Animation, Replicate: true|false|nil, TrackArguments: TrackArguments?, _serverGUID: string?): AnimationTrack
		assert(self.Animator,"No animator to load the animation onto!")

		local NewTrack = self.Animator:LoadAnimation(Animation) :: AnimationTrack
		NewTrack.Priority = TrackArguments and TrackArguments.AnimationPriority or Enum.AnimationPriority.Action
		if TrackArguments.Looped ~= nil then
			NewTrack.Looped = TrackArguments.Looped
		end
		NewTrack:SetAttribute("Replicated",Replicate ~= nil)
		local GUID = Replicate == false and _serverGUID ~= nil and _serverGUID or Http:GenerateGUID()
		NewTrack:SetAttribute("GUID",GUID)
		self.AnimationTracks[GUID] = NewTrack
		NewTrack:SetAttribute("AnimationId", Animation.AnimationId)
		NewTrack:AdjustSpeed(TrackArguments and TrackArguments.Speed or 1)
		NewTrack:AdjustWeight(TrackArguments and TrackArguments.Weight or 1, 0)
		
		if Replicate == true and self.Player == LocalPlayer then
			net.Animator.packets.LoadAnimation.send({ 
				animationId = Animation.AnimationId, 
				AnimationPriority = NewTrack.Priority.Value ~= 1000 and NewTrack.Priority.Value or nil, 
				looped = NewTrack.Looped == true and NewTrack.Looped or nil,
				speed = TrackArguments and TrackArguments.Speed ~= nil and TrackArguments.Speed ~= 1 and TrackArguments.Speed or nil,
				weight = TrackArguments and TrackArguments.Weight ~= nil and TrackArguments.Weight ~= 1 and TrackArguments.Weight or nil,
				gUID = GUID
			})
			NewTrack.Destroying:Once(function()
				net.Animator.packets.Destroy.send({ gUID = GUID })
			end)
		end
		
		return NewTrack
	end
	
	function self.AdjustSpeed(self: LocalAnimator, AnimationTrack: AnimationTrack, speed: number?)
		if self.customPlayer[AnimationTrack] then
			if speed == nil then speed = 1 end
			self.customPlayer[AnimationTrack].speed = speed
		else
			AnimationTrack:AdjustSpeed(speed)
		end
		if AnimationTrack:GetAttribute("Replicated") == true and self.Player == LocalPlayer then
			net.Animator.packets.AdjustSpeed.send({ gUID = AnimationTrack:GetAttribute("GUID"), speed = speed })
		end
	end
	
	function self.AdjustWeight(self: LocalAnimator, AnimationTrack: AnimationTrack, weight: number?, fadeTime: number?)
		AnimationTrack:AdjustWeight(weight, fadeTime)
		if AnimationTrack:GetAttribute("Replicated") == true and self.Player == LocalPlayer then
			net.Animator.packets.AdjustWeight.send({ gUID = AnimationTrack:GetAttribute("GUID"), weight = weight, fadeTime = fadeTime })
		end
	end
	
	function self.AdjustSpeedByGUID(self: LocalAnimator, GUID: string, speed: number?)
		local AnimationTrack = self.AnimationTracks[GUID] :: AnimationTrack?
		if AnimationTrack then
			if speed == nil then speed = 1 end
			if type(AnimationTrack) == "string" then
				local decodedData: TrackGhost = Http:JSONDecode(AnimationTrack)
				decodedData.Speed = speed
				self.AnimationTracks[GUID] = Http:JSONEncode(decodedData)
			else
				if self.customPlayer[AnimationTrack] then
					self.customPlayer[AnimationTrack].speed = speed
				else
					AnimationTrack:AdjustSpeed(speed)
				end
				if AnimationTrack:GetAttribute("Replicated") == true and self.Player == LocalPlayer then
					net.Animator.packets.AdjustSpeed.send({ gUID = GUID, speed = speed })
				end
			end
		end
	end
	
	function self.AdjustWeightByGUID(self: LocalAnimator, GUID: string, weight: number?, fadeTime: number?)
		local AnimationTrack = self.AnimationTracks[GUID] :: AnimationTrack?
		if AnimationTrack then
			if weight == nil then weight = 1 end
			if type(AnimationTrack) == "string" then
				local decodedData: TrackGhost = Http:JSONDecode(AnimationTrack)
				decodedData.Weight = weight
				self.AnimationTracks[GUID] = Http:JSONEncode(decodedData)
			else
				AnimationTrack:AdjustWeight(weight, fadeTime)
				if AnimationTrack:GetAttribute("Replicated") == true and self.Player == LocalPlayer then
					net.Animator.packets.AdjustWeight.send({ gUID = GUID, weight = weight, fadeTime = fadeTime })
				end
			end
		end
	end
	
	function self.Destroy(self: LocalAnimator)
		if not self._destroyed then
			self._destroyed = true
			table.clear(self.customPlayer)
			self._customConnection:Disconnect()
			setmetatable(self,nil)
			table.clear(self)
			self = nil
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