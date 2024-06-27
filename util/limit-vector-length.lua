local vec3 = require("lib.mathsies").vec3

local normaliseOrZero = require("util.normalise-or-zero")

local function limitVectorLength(v, m)
	local l = #v
	if l > m then
		return normaliseOrZero(v) * m
	end
	return vec3.clone(v)
end

return limitVectorLength
