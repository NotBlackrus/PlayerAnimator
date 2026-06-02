--[[
This is just my personal preference for networking, you can choose any other resource, as long as you modify the module to support it. Shouldn't be too difficult, just a bit annoying!
]]

local byte = require("../bytenet-max")

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
						looped = byte.optional(byte.bool),
						animationPriority = byte.optional(byte.uint8),
						player = byte.optional(byte.float64),
					})
				});
				Play = byte.definePacket({
					value = byte.struct({
						gUID = byte.string,
						fadeTime = byte.optional(byte.float32),
						weight = byte.optional(byte.float32),
						speed = byte.optional(byte.float32),
						customPlayer = byte.optional(byte.bool),
						player = byte.optional(byte.float64),
					})
				});
				Stop = byte.definePacket({
					value = byte.struct({
						gUID = byte.string,
						fadeTime = byte.optional(byte.float32),
						player = byte.optional(byte.float64),
					})
				});
				AdjustSpeed = byte.definePacket({
					value = byte.struct({
						gUID = byte.string,
						speed = byte.float32,
						player = byte.optional(byte.float64),
					})
				});
				AdjustWeight = byte.definePacket({
					value = byte.struct({
						gUID = byte.string,
						weight = byte.float32,
						fadeTime = byte.optional(byte.float32),
						player = byte.optional(byte.float64),
					})
				});
				Destroy = byte.definePacket({
					value = byte.struct({
						gUID = byte.string,
						player = byte.optional(byte.float64),
					})
				});
				Emote = byte.definePacket({
					value = byte.struct({
						emoteId = byte.string,
						player = byte.optional(byte.float64),
					})
				});
				StopAll = byte.definePacket({
					value = byte.struct({
						player = byte.float64,
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
						data = byte.array(byte.float64, byte.map(byte.string, byte.string))
					})
				})
			},
		}
	end);
}