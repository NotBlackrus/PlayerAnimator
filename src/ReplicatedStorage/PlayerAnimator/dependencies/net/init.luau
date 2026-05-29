--[[
This is just my personal preference for networking, you can choose any other resource, as long as you modify the module to support it. Shouldn't be too difficult, just a bit annoying!
]]

local byte = require("@self/ByteNetMax")

return {
	Animator = byte.defineNamespace("Animator", function()
		return {
			packets = {
				LoadAnimation = byte.definePacket({
					value = byte.struct({
						animationId = byte.string,
						gUID = byte.string,
						speed = byte.optional(byte.float32),
						weight = byte.optional(byte.float32),
						loop = byte.optional(byte.bool),
						animationPriority = byte.optional(byte.uint8),
						player = byte.optional(byte.playerIdentifier),
					})
				});
				Play = byte.definePacket({
					value = byte.struct({
						gUID = byte.string,
						fadeTime = byte.optional(byte.float32),
						weight = byte.optional(byte.float32),
						speed = byte.optional(byte.float32),
						customPlayer = byte.optional(byte.bool),
						player = byte.optional(byte.playerIdentifier),
					})
				});
				Stop = byte.definePacket({
					value = byte.struct({
						gUID = byte.string,
						fadeTime = byte.optional(byte.float32),
						player = byte.optional(byte.playerIdentifier),
					})
				});
				AdjustSpeed = byte.definePacket({
					value = byte.struct({
						gUID = byte.string,
						speed = byte.float32,
						player = byte.optional(byte.playerIdentifier),
					})
				});
				AdjustWeight = byte.definePacket({
					value = byte.struct({
						gUID = byte.string,
						weight = byte.float32,
						fadeTime = byte.optional(byte.float32),
						player = byte.optional(byte.playerIdentifier),
					})
				});
				Destroy = byte.definePacket({
					value = byte.struct({
						gUID = byte.string,
						player = byte.optional(byte.playerIdentifier),
					})
				});
				Emote = byte.definePacket({
					value = byte.struct({
						emoteId = byte.string,
						player = byte.optional(byte.playerIdentifier),
					})
				});
				StopAll = byte.definePacket({
					value = byte.struct({
						player = byte.playerIdentifier,
						fadeTime = byte.optional(byte.float32),
					})
				})
			};
			queries = {
				Init = byte.defineQuery({
					request = byte.struct({
						request = byte.bool;
					}),
					response = byte.struct({
						data = byte.array(byte.playerIdentifier, byte.map(byte.string, byte.string))
					})
				})
			},
		}
	end);
}