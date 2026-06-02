export type TrackArguments = {
	Looped: boolean?,
	Speed: number?,
	Weight: number?,
	AnimationPriority: Enum.AnimationPriority?,
}

export type LocalAnimator = {
	__index: LocalAnimator,
	_humanoid: Humanoid,
	AnimationTracks: {[string]: AnimationTrack},
	LastUse: {[AnimationTrack]: number},
	Animator: Animator,
	_destroyed: boolean,
	Player: Player?,
	customPlayer: {[AnimationTrack]: {speed: number, timePosition: number}},
	_customConnection: RBXScriptConnection,
	PlayByGUID: (self: LocalAnimator, GUID: string, fadeTime: number?, weight: number?, speed: number?, customPlayer: boolean?) -> AnimationTrack?,
	Play: (self: LocalAnimator, Animation: Animation, fadeTime: number?, weight: number?, speed: number?, customPlayer: boolean?) -> AnimationTrack?,
	StopByGUID: (self: LocalAnimator, GUID: string, fadeTime: number?) -> (),
	Stop: (self: LocalAnimator, Animation: Animation, fadeTime: number?) -> (),
	StopAll: (self: LocalAnimator, fadeTime: number?, replicate: boolean?) -> (),
	AdjustSpeedByGUID: (self: LocalAnimator, GUID: string, speed: number) -> (),
	AdjustWeightByGUID: (self: LocalAnimator, GUID: string, weight: number, fadeTime: number?) -> (),
	AdjustSpeed: (self: LocalAnimator, Animation: AnimationTrack, speed: number) -> (),
	AdjustWeight: (self: LocalAnimator, AnimationTrack: AnimationTrack, weight: number, fadeTime: number?) -> (),
	LoadAnimationById: (self: LocalAnimator, AnimationId: string, Replicate: boolean?, TrackArguments: TrackArguments?, _serverGUID: string?) -> AnimationTrack?,
	LoadAnimation: (self: LocalAnimator, Animation: Animation, Replicate: boolean?, TrackArguments: TrackArguments?, _serverGUID: string?) -> AnimationTrack?,
	Destroy: (self: LocalAnimator) -> (),
}

export type ServerAnimator = {
	__index : ServerAnimator,
	_humanoid : Humanoid,
	AnimationTracks : {[string]: FakeTrack},
	_destroyed: boolean,
	_jan : any,
	_player : Player,
	Enabled: boolean,
	
	LoadAnimation : (self: ServerAnimator, Animation: Animation|string, forceNew: boolean, TrackArguments: TrackArguments?, ReplicateTo: {Player}?, _clientGUID: string?) -> FakeTrack?,
	Destroy : (self: ServerAnimator) -> (),
}

export type FakeTrack = {
	__index : FakeTrack,
	IsPlaying : boolean,
	TimePosition : number,
	Length : number,
	Looped : boolean,
	Speed : number,
	Weight : number,
	Priority : Enum.AnimationPriority,
	_GUID : string,
	_ClientReplicated : boolean,
	AnimationId : string,
	_ReplicateTo: {Player}?,
	
	Stop : (self: FakeTrack, fadeTime: number?) -> (),
	Play : (self: FakeTrack, fadeTime: number?, weight: number?, speed: number?, customPlayer: boolean?) -> (),
	AdjustSpeed : (self: FakeTrack, speed: number) -> (),
	AdjustWeight : (self: FakeTrack, weight: number, fadeTime: number?) -> (),
	Destroy : (self: FakeTrack, _replicateToAllExcept: Player?) -> (),
	
	new : (AnimationId: string, TrackArguments: TrackArguments?, ReplicateTo: {Player}?, _clientGUID: string?, ServerAnimator: ServerAnimator) -> FakeTrack?
}

export type TrackGhost = {
	AnimationId: string;
	Speed: number;
	Weight: number;
	Looped: boolean;
	Priority: Enum.AnimationPriority;
}

export type AnimatorModule = {
	Initialized: boolean|nil,
	cache: {[Humanoid]: LocalAnimator | ServerAnimator},

	init: (args: Config?) -> AnimatorModule,
	new: (Humanoid: Humanoid) -> ServerAnimator|LocalAnimator,
	newClient: (Humanoid: Humanoid) -> LocalAnimator,
	newServer: (Humanoid: Humanoid) -> ServerAnimator
}

export type Config = {
	GARBAGE_TIMER: number?;
    GARBAGE_DEBUG: boolean?;
    NETWORK_DEBUG: boolean?;
    DEFAULT_CUSTOM_PLAYER: boolean?;
    UGC_EMOTES: boolean?;
}

return nil