local mathsies = require("lib.mathsies")
local vec2 = mathsies.vec2
local vec3 = mathsies.vec3
local quat = mathsies.quat
local mat4 = mathsies.mat4

local consts = require("consts")

local normaliseOrZero = require("util.normalise-or-zero")
local limitVectorLength = require("util.limit-vector-length")
local loadObj = require("util.load-obj")
local splitMesh = require("util.split-mesh")

local mouseDx, mouseDy

local outputCanvas, objectShader
local teapotMeshTable, icosphereMeshTable, triangleMeshTable, icosahedronMeshTable

local camera, objects, time

function love.mousepressed()
	love.mouse.setRelativeMode(not love.mouse.getRelativeMode())
end

function love.mousemoved(_, _, dx, dy)
	mouseDx, mouseDy = dx, dy
end

function love.load()
	outputCanvas = love.graphics.newCanvas(love.graphics.getDimensions())
	objectShader = love.graphics.newShader("shaders/object.glsl")

	teapotMeshTable = loadObj("meshes/teapot.obj")
	icosphereMeshTable = loadObj("meshes/icosphere.obj")
	icosahedronMeshTable = loadObj("meshes/icosahedron.obj")
	triangleMeshTable = loadObj("meshes/triangle.obj")

	camera = {
		position = consts.forwardVector * -6,
		orientation = quat(),
		verticalFOV = math.rad(70)
	}

	time = 0
end

local function remakeMeshes()
	local norm2d = vec2.fromAngle(time * 0.5)
	local norm = vec3(norm2d.x, norm2d.y, 0)
	local planeNormal, planeDistance = vec3.normalise(norm), 0.1
	local meshToDrawTable = icosahedronMeshTable
	local meshUnderTable, meshOverTable = splitMesh(meshToDrawTable.vertices, planeNormal, planeDistance)

	local splitOffset = vec3(3, 0, 0)
	objects = {
		{
			position = vec3(),
			orientation = quat(),
			mesh = meshToDrawTable.mesh
		},
		{
			position = splitOffset,
			orientation = quat(),
			mesh = meshUnderTable.mesh
		},
		{
			position = splitOffset + planeNormal * planeDistance * 2,
			orientation = quat(),
			mesh = meshOverTable.mesh
		}
	}
end

local function updateState(dt)
	remakeMeshes()

	local speed = 5
	local translation = vec3()
	if love.keyboard.isDown("d") then translation = translation + consts.rightVector end
	if love.keyboard.isDown("a") then translation = translation - consts.rightVector end
	if love.keyboard.isDown("e") then translation = translation + consts.upVector end
	if love.keyboard.isDown("q") then translation = translation - consts.upVector end
	if love.keyboard.isDown("w") then translation = translation + consts.forwardVector end
	if love.keyboard.isDown("s") then translation = translation - consts.forwardVector end
	camera.position = camera.position + vec3.rotate(normaliseOrZero(translation) * speed, camera.orientation) * dt

	local maxAngularSpeed = consts.tau * 2
	local keyboardRotationSpeed = consts.tau / 4
	local keyboardRotationMultiplier = keyboardRotationSpeed / maxAngularSpeed
	local mouseMovementForMaxSpeed = 20
	local rotation = vec3()
	if love.keyboard.isDown("k") then rotation = rotation + consts.rightVector * keyboardRotationMultiplier end
	if love.keyboard.isDown("i") then rotation = rotation - consts.rightVector * keyboardRotationMultiplier end
	if love.keyboard.isDown("l") then rotation = rotation + consts.upVector * keyboardRotationMultiplier end
	if love.keyboard.isDown("j") then rotation = rotation - consts.upVector * keyboardRotationMultiplier end
	if love.keyboard.isDown("u") then rotation = rotation + consts.forwardVector * keyboardRotationMultiplier end
	if love.keyboard.isDown("o") then rotation = rotation - consts.forwardVector * keyboardRotationMultiplier end
	rotation = rotation + consts.upVector * mouseDx / mouseMovementForMaxSpeed
	rotation = rotation + consts.rightVector * mouseDy / mouseMovementForMaxSpeed
	camera.orientation = quat.normalise(camera.orientation * quat.fromAxisAngle(limitVectorLength(rotation, 1) * maxAngularSpeed * dt))
end

function love.update(dt)
	if not love.window.hasFocus() then
		love.mouse.setRelativeMode(false)
	end
	if not (mouseDx and mouseDy) or love.mouse.getRelativeMode() == false then
		mouseDx = 0
		mouseDy = 0
	end

	updateState(dt)

	time = time + dt

	mouseDx, mouseDy = nil, nil
end

function love.draw()
	local worldToCamera = mat4.camera(camera.position, camera.orientation)
	local worldToCameraStationary = mat4.camera(vec3(), camera.orientation)
	local cameraToClip = mat4.perspectiveLeftHanded(
		outputCanvas:getWidth() / outputCanvas:getHeight(),
		camera.verticalFOV,
		consts.farPlaneDistance,
		consts.nearPlaneDistance
	)
	local worldToClip = cameraToClip * worldToCamera
	local clipToSky = mat4.inverse(cameraToClip * worldToCameraStationary)

	love.graphics.setDepthMode("lequal", true)
	love.graphics.setCanvas({outputCanvas, depth = true})
	love.graphics.clear()

	love.graphics.setShader(objectShader)
	for _, object in ipairs(objects) do
		if object.mesh then
			local modelToWorld = mat4.transform(object.position, object.orientation)
			local modelToClip = worldToClip * modelToWorld
			objectShader:send("modelToClip", {mat4.components(modelToClip)})
			love.graphics.draw(object.mesh)
		end
	end

	love.graphics.setDepthMode("always", false)
	love.graphics.setShader()
	love.graphics.setCanvas()
	love.graphics.draw(outputCanvas, 0, love.graphics.getHeight(), 0, 1, -1)
end
