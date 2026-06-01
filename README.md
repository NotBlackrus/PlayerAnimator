> [!IMPORTANT]
> This repository is open to contributions, improvements with new and/or existing code are welcomed and encouraged!

<div align="center">

# NotBlackrus' PlayerAnimator
### ! A WORKAROUND TO ROBLOX'S BUILT-IN ANIMATION REPLICATION !
<small>with some extra features for animations</small>

</div>

----

## Getting Started
To build the place from scratch, use:

```bash
rojo build -o "PlayerAnimator.rbxlx"
```

If you plan to contribute to the repository (or simply use your IDE for Roblox development), open `PlayerAnimator.rbxlx` in Roblox Studio and start the Rojo server:

```bash
rojo serve
```

For more help, check out [the Rojo documentation](https://rojo.space/docs).

---

## Why use this?
I had created a crude version of this module when designing my emote system for [Unnatural Disasters Survival](https://www.roblox.com/games/7233282897/Unnatural-Disaster-Survival), because it was the first idea that came to mind when I had thought about **emote synchronizing**. The result was an emote system seemingly *perfect* to the individualistic client. Emotes synced, audio synced, emotes synced with audios, and it was a very satisfying sight. The cost however was rather heavy, I had to rewrite how a lot of disasters worked and how they interacted with the player's animations. I had to rewrite just about how everything interacted with player animations. But honestly, it was a sacrifice I think was worth its payoff. As someone who loves Roblox emotes with a passion, I believe this to be the perfect tool for emote-focused games, and for any game using emotes for that matter.
<small>foolishly, I also wanted UGC emotes to be usable alongside UDS' emote system...</small>

---

## Documentation
While most of the functionalities of this module are indistinguishable from normal Animators, there are some major differences and features that have to be addressed.
> [!WARNING]
> This documentation may be paraphrased, and/or incomplete. There will likely be more information via comments made in the source code.

- #### Setting up your animator

Once you have both a server and a client script set to require the PlayerAnimator module (and run their respective .newClient(Humanoid) and .newServer(Humanoid) functions on your character's Humanoid), you'll come to find out that the Animator instance does not exist when you toggle the Server View of your place. This is intentional as Roblox's default engine forces all client-sided animations to replicate to the server. (Hence why you can load and play animations on a client script in a normal place, and have it seen by other players.)
This doesn't mean that your server cannot control animations, it just cannot see them! The server controller of your animator sends tables representing fake "animation tracks" that network the necessary information for the clients to run.
> [!IMPORTANT]
> Servers cannot see animations, and thus cannot see animations. Any server-sided code made related to tools- or anything similar- must accomodate for this. (My personal solution was invoking the client to return their handle's disposition for the server to use when the tool is used, but that wouldn't help with hitboxes.)

> [!NOTE]
> While they are labeled ".newClient" and ".newServer", you can reuse them to recall the same Animator object.

- #### ClientAnimator
- **:LoadAnimation(Animation, Replicate, TrackArguments)**
For the method :LoadAnimation(), Replicate is a **3-INPUT** argument, here's what each input means:
> **True**: The animation originates from this client (via your code), and should be replicated to other clients.

> **False**: The animation originates from the server (or another client), and should not be replicated to other clients.
<span style="color:red">This value makes the animation track loaded prone to the module's automatic garbage collection. DO NOT USE IN CODE THAT KEEPS REFERENCE OF THE ANIMATION TRACK.</span>

> [!NOTE]
> The system's automatic garbage collection can be disabled by setting the module's GARBAGE_TIMER attribute to -1.

> **nil**: The animation originates from this client (via your code), but should not be replicated to other clients.

The method also has a Priority argument, this is your *only chance* to apply animation priority to replicated animations. (I do not personally care much for this property.)

- **:Play(AnimationTrack, fadeTime, weight, speed, customPlayer)**
AnimationTrack: The AnimationTrack.
fadeTime: The duration of time that the animation's weight should be faded in for. (Default: 0.100000001)
weight: The weight the animation is to be played at. (Default: 1)
speed: The playback speed of the animation. (Default: 1)
customPlayer: Sets whether the animation is played with Roblox's default animation player or the module's custom player (Default: false)

> [!IMPORTANT]
> The module's custom player utilizes a PreRender connection on the client to move the animation's TimePosition by deltaTime multiplied by it's Speed. This doesn't sound special at first, but note that Roblox's player seemingly fails to play animations relative to time like this when CPU processing slows, causing framerate to drop. **THIS IS HOW MOST EMOTES DESYNC WITH THEIR AUDIOS!!!**
> It is also important to note that since the custom player keeps the animation from playing on Roblox's built-in player, that frame markers are more likely to be skipped and not invoked.

- **Garbage Collection**
While it only affects animation tracks that are replicated from the server, it is important to note that the animation tracks aren't *completely* deleted, and are instead turned into "ghost tracks". These ghost tracks are tables containing the animation's necessary data for "revival" whenever it's requested to play again.

- **AnimateHandler**
AnimateHandler is a custom local script inside of StarterPlayerScripts that takes over the processing of character animations, designed to replace StarterCharacterScripts' "Animate" script for every player's character, to minimize networking (and to conveniently confuse exploiters).

> [!WARNING]
> Roblox's built-in emote wheel ui uses CoreSecurity methods that normal scripts cannot access in order to load emotes, this module utilizes a loophole using InsertService by the server, and caches the emotes in a folder for the clients to use. This isn't relatively safe and can be prone to exploits, you can disable ugc emotes via the module's UGC_EMOTES attribute.

- #### ServerAnimator

- **:LoadAnimation(Animation, forceNew, TrackArguments, ReplicateTo)**
Animation: An animation instance or string of the AnimationId.
forceNew: The server animator will create a new FakeTrack, regardless of another FakeTrack with a matching AnimationId. (Default: True)
TrackArguments: The set of properties you wish the FakeTrack to have before its values are replicated to clients for the first time. (Default: nil)
ReplicateTo: An array of players the FakeTrack should replicate itself to, nil for everyone. (Default: nil)

- #### FakeTrack
Created by ServerAnimator:LoadAnimation(), these object-oriented tables are designed to mimic real [AnimationTracks](https://create.roblox.com/docs/en-us/reference/engine/classes/AnimationTrack) and their most basic functions. Calling methods from these FakeTracks network changes made from the server to all players listed in FakeTrack._SetReplicateTo. This restricts the server by not allowing it to receive events, and gives it less methods to work with.
- **:SetReplicateTo(Players)**
Players: An array of players the FakeTrack should replicate itself to. (Default: nil)