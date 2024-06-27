local mathsies = require("lib.mathsies")
local vec2 = mathsies.vec2
local vec3 = mathsies.vec3

local consts = require("consts")

local function shallowClone(t)
	local ret = {}
	for k, v in pairs(t) do
		ret[k] = v
	end
	return ret
end

local function linePlaneIntersection(lineStart, lineEnd, planeNormal, planeDistance)
	local p = vec3.dot(planeNormal, planeNormal * planeDistance)
	local ad = vec3.dot(lineStart, planeNormal)
	local bd = vec3.dot(lineEnd, planeNormal)
	return (p - ad) / (bd - ad) -- The line's t
end

local function lerp(a, b, i)
	return a + i * (b - a)
end

local function lerpVertex(a, b, i)
	local pos = lerp(
		vec3(a[1], a[2], a[3]),
		vec3(b[1], b[2], b[3]),
		i
	)
	local tex = lerp(
		vec2(a[4], b[4]),
		vec2(a[5], b[5]),
		i
	)
	local norm = vec3.normalise(lerp( -- Should be slerp, but this is fine for small changes
		vec3(a[6], a[7], a[8]),
		vec3(b[6], b[7], b[8]),
		i
	))
	return {
		pos.x, pos.y, pos.z,
		tex.x, tex.y,
		norm.x, norm.y, norm.z
	}
end

-- Doesn't leave a solid face in the two meshes where the cut was.
local function splitMesh(vertices, planeNormal, planeDistance)
	local underVerts, overVerts = {}, {}
	for i = 1, #vertices, 3 do
		local v0 = vertices[i]
		local v1 = vertices[i + 1]
		local v2 = vertices[i + 2]
		local p0 = vec3(v0[1], v0[2], v0[3])
		local p1 = vec3(v1[1], v1[2], v1[3])
		local p2 = vec3(v2[1], v2[2], v2[3])

		local v0Over = vec3.dot(p0, planeNormal) > planeDistance
		local v1Over = vec3.dot(p1, planeNormal) > planeDistance
		local v2Over = vec3.dot(p2, planeNormal) > planeDistance
		local allOver = v0Over and v1Over and v2Over
		local allUnder = not (v0Over or v1Over or v2Over)

		if allOver then
			overVerts[#overVerts + 1] = shallowClone(v0)
			overVerts[#overVerts + 1] = shallowClone(v1)
			overVerts[#overVerts + 1] = shallowClone(v2)
		elseif allUnder then
			underVerts[#underVerts + 1] = shallowClone(v0)
			underVerts[#underVerts + 1] = shallowClone(v1)
			underVerts[#underVerts + 1] = shallowClone(v2)
		else
			local function filter(t)
				return 0 <= t and t <= 1 and t or nil
			end
			local t0 = filter(linePlaneIntersection(p0, p1, planeNormal, planeDistance))
			local t1 = filter(linePlaneIntersection(p1, p2, planeNormal, planeDistance))
			local t2 = filter(linePlaneIntersection(p2, p0, planeNormal, planeDistance))
			local numValid = (t0 and 1 or 0) + (t1 and 1 or 0) + (t2 and 1 or 0)
			if numValid > 1 then
				-- Rotate the vertices and other variables (in this scope) until t0 and t1 are both true
				local v0, v1, v2 = shallowClone(v0), shallowClone(v1), shallowClone(v2)
				local p0, p1, p2 = p0, p1, p2 -- No need to vec3.clone
				local t0, t1, t2 = t0, t1, t2
				local v0Over, v1Over, v2Over = v0Over, v1Over, v2Over
				for _=1, 3 do
					if t0 and t1 then
						local v01 = lerpVertex(v0, v1, t0)
						local v12 = lerpVertex(v1, v2, t1)
						local triTarget, quadTarget
						-- v0 is part of the quad, but is the quad in the over or under mesh?
						if v0Over then
							-- v1Over should be false (mathematically speaking, at least)
							triTarget, quadTarget = underVerts, overVerts
						else
							triTarget, quadTarget = overVerts, underVerts
						end
						-- Tri
						triTarget[#triTarget + 1] = v01
						triTarget[#triTarget + 1] = v1
						triTarget[#triTarget + 1] = v12
						-- Quad tri 1
						quadTarget[#quadTarget + 1] = v0
						quadTarget[#quadTarget + 1] = v01
						quadTarget[#quadTarget + 1] = v2
						-- Quad tri 2
						quadTarget[#quadTarget + 1] = v01
						quadTarget[#quadTarget + 1] = v12
						quadTarget[#quadTarget + 1] = v2
					end
					-- Rotate for next try
					v0, v1, v2 = v1, v2, v0
					p0, p1, p2 = p1, p2, p0
					t0, t1, t2 = t1, t2, t0
					v0Over, v1Over, v2Over = v1Over, v2Over, v0Over
				end
			else
				-- Less than 2 valid t's (due to precision issues), will have to pick a side for the whole triangle
				local numOver = (v0Over and 1 or 0) + (v1Over and 1 or 0) + (v2Over and 1 or 0)
				if numOver >= 2 then
					overVerts[#overVerts + 1] = shallowClone(v0)
					overVerts[#overVerts + 1] = shallowClone(v1)
					overVerts[#overVerts + 1] = shallowClone(v2)
				else
					underVerts[#underVerts + 1] = shallowClone(v0)
					underVerts[#underVerts + 1] = shallowClone(v1)
					underVerts[#underVerts + 1] = shallowClone(v2)
				end
			end
		end
	end
	return
		{
			vertices = underVerts,
			mesh = #underVerts ~= 0 and love.graphics.newMesh(consts.objectVertexFormat, underVerts, "triangles")
		},
		{
			vertices = overVerts,
			mesh = #overVerts ~= 0 and love.graphics.newMesh(consts.objectVertexFormat, overVerts, "triangles")
		}
end

return splitMesh
