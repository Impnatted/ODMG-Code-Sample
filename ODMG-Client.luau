
--============================================================
-- Servicios
--============================================================

_G.NotifyHandler = require(script.Parent.Parent.Misc.NotifyHandler)

local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local TS = game:GetService("TweenService")
local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local UIS = game:GetService("UserInputService")

--============================================================
-- Referencias / Módulos externos
--============================================================

local LocalPlayer = Players.LocalPlayer
local Assets = RS.Assets
local Libraries = Assets.Libraries

local Mouse = LocalPlayer:GetMouse() -- referencia olaa :vV

local NotificationTemplate = Assets.GUI.NotificationTemplate 

local AnimationHandler = require(Libraries.AnimationHandler)
local NotifyHandler = _G.NotifyHandler
local Mobility = require(script.Parent.Parent.Character.Mobility)

local Misc = require(script.Misc)

local ScreenFX = game.ReplicatedStorage.Assets.Remotes.Effects

local CameraShaker = require(game.ReplicatedStorage.Assets.Modules.CameraShaker)
local CamShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(ShakeCF)
	workspace.CurrentCamera.CFrame = workspace.CurrentCamera.CFrame * ShakeCF
end)
CamShake:Start()

local ClientCombat = require(script.Parent.Parent.CombatHandler)
local Animations = Assets.Animations
local Physics = require(Assets.Libraries.Physics)

--============================================================
-- Tabla principal del módulo
--============================================================

local ODMG = {}

-- Referencias compartidas para los módulos hijos
ODMG.RunService = RunService
ODMG.RS = RS
ODMG.TS = TS
ODMG.Players = Players
ODMG.StarterPlayer = StarterPlayer
ODMG.UIS = UIS

ODMG.LocalPlayer = LocalPlayer
ODMG.Assets = Assets
ODMG.AnimationHandler = AnimationHandler
ODMG.Mobility = Mobility
ODMG.ScreenFX = ScreenFX
ODMG.CamShake = CamShake
ODMG.ClientCombat = ClientCombat
ODMG.Animations = Animations
ODMG.Physics = Physics
ODMG.Misc = Misc
ODMG.NotificationTemplate = NotificationTemplate

ODMG.NotifyHandler = NotifyHandler

-- Se completan dentro de Initialize() (dependen de ModuleLoader)
ODMG.ModuleLoader = nil
ODMG.Effects = nil
ODMG.ServerCombat = nil

ODMG.DirectionX = 0

--============================================================
-- Estado / Configuración
--============================================================

ODMG.State = {
	Hooking = {["Right"] = false, ["Left"] = false},
	Orbit = {["Up"] = false, ["Down"] = false, ["Right"] = false, ["Left"] = false},
	Boost = false,
	Handles = false,
	WallSliding = false,
	BladesOut = false,

	Heat = 0, -- hasta 100%
	Overheated = false,

	Checking = false,

	Gas = 100000000,

	Jammed = false,
}

ODMG.Settings = {
	RelativeAntiGravity = 0.7,
	RelativeAntiGravity2 = {
		Hooking = 0.6,
		WallSliding = 0.6,
		WallRunning = 1,
		Impulse = 0.8,
	}, --de 0 a 1 (1 -> 100%)
	TerminalSpeed = 175, --Velocidad Maxima --original: 150
	MaxDistance = 500, --Distancia maxima del hook
	GasForce = 4500, --Fuerza que sientes por el hook
	OrbitForce = 4200, --Fuerza que sientes al hacer orbit
	DesorbitK = 0.70, --aumenta la velocidad consecuentemente

	HeatResistance = 1,

	GasLost = 1,

	MaxGas = 100000000, --diseñado para ser 100

	JamChance = 5, --ej.(5% --> 100)
}

ODMG.Keybinds = {
	Hooks = {
		Left = Enum.KeyCode.Q,
		Right = Enum.KeyCode.E,
	},

	Orbit = {
		Up = Enum.KeyCode.W,
		Down = Enum.KeyCode.S,
		Right = Enum.KeyCode.D,
		Left = Enum.KeyCode.A,
	},

	Blades = {
		Reload = Enum.KeyCode.R,

		Light = Enum.UserInputType.MouseButton1,
		Heavy = Enum.UserInputType.MouseButton2,
	},

	WallSlide = { --las keybinds para moverse por la pared son right y left de orbit
		Jump = Enum.KeyCode.Space,
	},

	Impulse = { --doble cada una
		Front = Enum.KeyCode.W,
		Back = Enum.KeyCode.S,
		Right = Enum.KeyCode.D,
		Left = Enum.KeyCode.A,

		Up = Enum.KeyCode.Space,
	},

	Gas = Enum.KeyCode.Space,

	Handles = Enum.KeyCode.T,

	Remove = Enum.KeyCode.K,

	Check = Enum.KeyCode.G
}

ODMG.TotalForce = {}

--============================================================
-- Referencias del personaje (se completan en Check())
--============================================================

function ODMG:Check()
	if not LocalPlayer.Character then
		return
	end
	if not LocalPlayer.Character:FindFirstChild("ODMG") then
		return
	end

	ODMG.Character = LocalPlayer.Character
	ODMG.Humr = ODMG.Character.HumanoidRootPart
	ODMG.Constraints = ODMG.Humr.GearForce
	ODMG.Humanoid = ODMG.Character.Humanoid
	ODMG.Animator = ODMG.Humanoid.Animator
	ODMG.AlignOrientation = ODMG.Constraints.AlignOrientation
	ODMG.ForceInstance = ODMG.Constraints.TotalForce

	return true
end

local function HandlesCheck()
	if ODMG.State.Handles then
		return true
	end
end

--============================================================
-- Tablas de lookup de keybinds (para rutear el input a cada módulo)
--============================================================

local orbitSides = {
	[ODMG.Keybinds.Orbit.Left] = "Left",
	[ODMG.Keybinds.Orbit.Right] = "Right",
	[ODMG.Keybinds.Orbit.Up] = "Up",
	[ODMG.Keybinds.Orbit.Down] = "Down",
}

local hookSides = {
	[ODMG.Keybinds.Hooks.Left] = "Left",
	[ODMG.Keybinds.Hooks.Right] = "Right",
}

local impulseSides = {
	[ODMG.Keybinds.Impulse.Left] = "Left",
	[ODMG.Keybinds.Impulse.Right] = "Right",
	[ODMG.Keybinds.Impulse.Front] = "Front",
	[ODMG.Keybinds.Impulse.Back] = "Back",
	[ODMG.Keybinds.Impulse.Up] = "Up",
}

--============================================================
-- Estado interno de input / debounces
--============================================================

local handlesDebounce = false

local impulseDebounce = {}
local impulsetick, impulseside = tick() --,nil

local bladetick, bladedebounce = tick(), false

--============================================================
-- Sistema de fuerzas (usado por Slides, HookGas e Impulses)
--============================================================

local function GetTotalForce()
	if not LocalPlayer.Character then
		return Vector3.zero
	end

	local TotalForce = Vector3.zero

	local gRel = ODMG.Settings.RelativeAntiGravity
	if ODMG.State.WallSliding then
		gRel = 0.8
	end
	ODMG.TotalForce.Antiweight = Vector3.new(0, LocalPlayer.Character.HumanoidRootPart.AssemblyMass * workspace.Gravity * gRel, 0)

	for _, Force: Vector3 in pairs(ODMG.TotalForce) do
		if not Force then
			continue
		end
		TotalForce += Force
	end

	local AirDrag: Vector3 = Physics:GetAirDrag(LocalPlayer.Character.HumanoidRootPart, ODMG.Settings.TerminalSpeed, TotalForce.Magnitude)
	TotalForce += AirDrag

	local dk = ODMG.State.Boost and 0.765 or ODMG.Settings.DesorbitK

	dk = ODMG.State.WallSliding and 0.3 or dk

	TotalForce -= AirDrag * dk

	return TotalForce
end

function ODMG:EnableForce(Disabled: boolean)
	if Disabled then
		TS:Create(workspace.CurrentCamera, TweenInfo.new(0.3, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, 0), {FieldOfView = 70}):Play()
		ScreenFX:Fire({Effect = 'WindLines', ArgTable = {On = false, DirectionX = ODMG.DirectionX}})
		ODMG.State.Forces = false
		return
	end

	TS:Create(workspace.CurrentCamera, TweenInfo.new(0.3, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, 0), {FieldOfView = 120}):Play()

	ODMG.Effects:Gas(ODMG.Character.ODMG, true)

	local Connection
	Connection = RunService.Stepped:Connect(function(_, dt)
		if ODMG.State.Heat >= 100 or (not ODMG.State.Hooking.Left and not ODMG.State.Hooking.Right and not ODMG.State.WallSliding and not ODMG.State.Impulse) then
			ODMG.TotalForce.Antiweight = Vector3.zero
			ODMG.ForceInstance.Force = Vector3.zero
			Connection:Disconnect()
			ODMG.Effects:GasBoost(ODMG.Character.ODMG, false)

			TS:Create(workspace.CurrentCamera, TweenInfo.new(0.3, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, 0), {FieldOfView = 70}):Play()
			ScreenFX:Fire({Effect = 'WindLines', ArgTable = {On = false, DirectionX = ODMG.DirectionX}})
			ScreenFX:Fire({Effect = 'WindLinesS', ArgTable = {On = false, DirectionX = ODMG.DirectionX}})

			return
		end

		ODMG.ForceInstance.Force = GetTotalForce()

		if not ODMG.State.Hooking.Left and not ODMG.State.Hooking.Right then
			return
		end
	end)
end

--============================================================
-- Handles (equipar / desequipar)
--============================================================
-- HOLA ROZAL

local Player = game:GetService("Players").LocalPlayer
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Playergui = Player.PlayerGui
local MouseGUI = Playergui:WaitForChild("Mouse")
MouseGUI.IgnoreGuiInset = true
local CursorFrame = MouseGUI:WaitForChild("Frame")
local CursorImage = CursorFrame:FindFirstChildWhichIsA("ImageLabel", true)
CursorFrame.Visible = false

local function UpdateCursorPosition()
	local ViewportPosition = UIS:GetMouseLocation()
	CursorFrame.Position = UDim2.fromOffset(ViewportPosition.X, ViewportPosition.Y)
end

local RenderConnection: RBXScriptConnection? = nil

function ODMG:Handles(Enabled: boolean)
	if Enabled then
		Mouse.Icon = ""
		UIS.MouseIconEnabled = false
		CursorFrame.Visible = true

		if not RenderConnection then
			RenderConnection = RunService.RenderStepped:Connect(UpdateCursorPosition)
		end
	else
		UIS.MouseIconEnabled = true
		Mouse.Icon = "rbxasset://textures/Cursors/KeyboardMouse/ArrowFarCursor.png"
		CursorFrame.Visible = false

		if RenderConnection then
			RenderConnection:Disconnect()
			RenderConnection = nil
		end
	end

	ODMG.State.Handles = Enabled
	local Anim = ODMG.Animator:LoadAnimation(Animations.Gear.EquipHandles)
	Anim.Priority = Enum.AnimationPriority.Action2
	Anim:Play(0.15)
	task.wait(0.20)
	ODMG.ModuleLoader.Server.ODMG:Handles(ODMG.Character, Enabled)
end

--============================================================
-- Debug
--============================================================

function ODMG:HitPart(Position: Vector3, Color: Color3, Time: number?)
	local newPart = RS.HitPart:Clone()
	newPart.Position = Position
	newPart.Parent = workspace.Ignore
	newPart.Color = Color

	if Time then
		game:GetService("Debris"):AddItem(newPart, Time)
	end
	return newPart
end

--============================================================
-- Módulos hijos
--============================================================

local Combat = require(script.Combat)(ODMG)
local Slides = require(script.Slides)(ODMG)
local HookGas = require(script.HookGas)(ODMG)
local Impulses = require(script.Impulses)(ODMG)
local Follower = require(script.Follower)(ODMG)

ODMG.Combat = Combat
ODMG.Slides = Slides
ODMG.HookGas = HookGas
ODMG.Impulses = Impulses
ODMG.Follower = Follower

--============================================================
-- Inicialización / Input
--============================================================

function ODMG:Initialize()
	ODMG.ModuleLoader = require(Assets.ModuleLoader)
	ODMG.Effects = ODMG.ModuleLoader.Server.Effects
	ODMG.ServerCombat = ODMG.ModuleLoader.Server.CombatHandler

	LocalPlayer.CharacterAdded:Connect(function(Character)
		ODMG.State.Gas = 100000000
		ODMG.State.BladesOut = false
		ODMG.State.Handles = false
	end)

	UIS.InputBegan:Connect(function(Input, _GP)
		if _GP then
			return
		end

		if not ODMG:Check() then
			return
		end

		if ODMG.State.Checking  then
			return
		end

		if Input.KeyCode == ODMG.Keybinds.Handles then
			if handlesDebounce then
				return
			end
			if ODMG.Character:FindFirstChildWhichIsA("Tool") and not ODMG.State.Handles then
				return
			end
			handlesDebounce = true
			task.delay(0.35, function()
				handlesDebounce = false
			end)
			ODMG:Handles(not ODMG.State.Handles)
		end

		if Input.KeyCode == ODMG.Keybinds.Check then
			if ODMG.State.Checking then
				return
			end

			ODMG.State.Checking = true

			local FINAL_GAS
			local PitchSound = 1

			local GAS_PORCENTAJE = math.ceil((ODMG.State.Gas*100) / ODMG.Settings.MaxGas)

			if true == true then
				if GAS_PORCENTAJE == 100 then
					FINAL_GAS = ODMG.Misc.GAS_PERCENTAGES["100"]
					PitchSound = 2
				elseif GAS_PORCENTAJE < 100 and GAS_PORCENTAJE >= 75 then
					FINAL_GAS = ODMG.Misc.GAS_PERCENTAGES["75"]
					PitchSound = 1.6
				elseif GAS_PORCENTAJE < 75 and GAS_PORCENTAJE >= 50 then
					FINAL_GAS = ODMG.Misc.GAS_PERCENTAGES["50"]
					PitchSound = 1.4
				elseif GAS_PORCENTAJE < 50 and GAS_PORCENTAJE >= 25 then
					FINAL_GAS = ODMG.Misc.GAS_PERCENTAGES["25"]
					PitchSound = 1
				elseif GAS_PORCENTAJE < 25 and GAS_PORCENTAJE > 0 then
					FINAL_GAS = "casi vacío"
					PitchSound = 0.8
				else
					FINAL_GAS = ODMG.Misc.GAS_PERCENTAGES["0"]
					PitchSound = 0.5
				end
			end



			task.delay(.1,function()
				ScreenFX:Fire({Effect = 'Output', ArgTable = {In = 0.01, Out = 0.5, Transp = 0.65}})
				task.wait(.65)
				ScreenFX:Fire({Effect = 'Output', ArgTable = {In = 0.01, Out = 0.5, Transp = 0.65}})
			end)

			local newAnim:AnimationTrack = ODMG.Animator:LoadAnimation(Animations.Gear.CheckGas)
			newAnim.Priority = Enum.AnimationPriority.Action2
			newAnim:Play()
			newAnim.Stopped:Connect(function()
				ODMG.State.Checking = false
				ODMG.NotifyHandler:Create((ODMG.Misc.Gas[math.random(1, #ODMG.Misc.Gas)].." <b><font color='rgb(160,160,220)'>"..FINAL_GAS.."</font></b>"),1,1,4,ODMG.NotificationTemplate)				
			end)

			ODMG.Effects:GasCheck(ODMG.Character.ODMG,PitchSound)

		end

		if not HandlesCheck() then
			return
		end

		if Input.KeyCode == ODMG.Keybinds.Blades.Reload then
			bladetick = tick()
		end

		if Input.UserInputType == ODMG.Keybinds.Blades.Light then
			if not ODMG.State.Handles then
				return
			end
			if not ODMG.State.BladesOut then
				return
			end
			Combat:WindUp()
		end

		if hookSides[Input.KeyCode] then
			HookGas:Hook(hookSides[Input.KeyCode], true)
		end
		if orbitSides[Input.KeyCode] then
			--if not ODMG.State.Hooking.Left or not ODMG.State.Hooking.Right then return end
			HookGas:Orbit(orbitSides[Input.KeyCode], true)

			if ODMG.State.FloorSliding and ODMG.Humr.AssemblyLinearVelocity.Magnitude < 25 then
				ODMG.Humanoid:ChangeState(Enum.HumanoidStateType.Running) --para que cancele el floorslide
			end
		end

		if Input.KeyCode == ODMG.Keybinds.WallSlide.Jump and ODMG.State.WallSliding then
			Slides:WallRun()
		end

		--IMPULSOS

		if impulseSides[Input.KeyCode] then
			local index = table.find(impulseDebounce, impulseSides[Input.KeyCode])

			if tick() - impulsetick > 0.45 and not index then
				impulsetick = tick()
				impulseside = impulseSides[Input.KeyCode]
			else
				if impulseSides[Input.KeyCode] ~= impulseside then
					return
				end
				impulsetick = tick() * 0.5
				table.insert(impulseDebounce, impulseSides[Input.KeyCode])
				task.delay(10, function()
					index = table.find(impulseDebounce, impulseSides[Input.KeyCode])
					table.remove(impulseDebounce, index)
				end)

				Impulses:Impulse2(impulseside)
				impulseside = nil
			end
		end

		if Input.KeyCode == ODMG.Keybinds.Gas then
			HookGas:GasBoost(true)
		end
	end)

	UIS.InputEnded:Connect(function(Input, _GP)
		if _GP then
			return
		end
		if not ODMG:Check() then
			return
		end

		if Input.KeyCode == ODMG.Keybinds.Blades.Reload then
			if bladedebounce then
				return
			end
			if tick() - bladetick > 1 then
				if not ODMG.State.BladesOut then
					return
				end
			end
			bladedebounce = true
			task.delay(1, function()
				bladedebounce = false
			end)

			local Animation

			if ODMG.State.BladesOut then
				ODMG.State.BladesOut = false
				ODMG.ModuleLoader.Server.ODMG:Sheath(ODMG.Character)
				Animation = ODMG.Animator:LoadAnimation(Animations.Gear.BladesIn)
			else
				ODMG.State.BladesOut = true
				ODMG.ModuleLoader.Server.ODMG:Unsheath(ODMG.Character)
				Animation = ODMG.Animator:LoadAnimation(Animations.Gear.BladesOut)
			end

			Animation.Priority = Enum.AnimationPriority.Action2
			Animation:Play()
		end

		if Input.UserInputType == ODMG.Keybinds.Blades.Light then
			if not ODMG.State.Handles then
				return
			end
			if not ODMG.State.BladesOut then
				return
			end
			Combat:Light()
		end

		if hookSides[Input.KeyCode] then
			HookGas:Hook(hookSides[Input.KeyCode], false)
		end

		if orbitSides[Input.KeyCode] then
			HookGas:Orbit(orbitSides[Input.KeyCode], false)
		end

		if impulseSides[Input.KeyCode] then
			if impulseside then
				Impulses:Impulse2(impulseside, true)
			end
		end

		if Input.KeyCode == ODMG.Keybinds.Gas then
			HookGas:GasBoost(false)
		end
		if Input.KeyCode == ODMG.Keybinds.WallSlide.Jump then
			Slides:WallJump()
		end
	end)
end

return ODMG
