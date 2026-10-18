local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local TS = game:GetService("TweenService")

local Assets = RS.Assets

local ODMG = {}


local function Init(Character:Model)
	local PlayerData = game:GetService("ServerStorage").Assets.PlayerData:WaitForChild(Character.Name)
	if not PlayerData.ODMG.Equipped.Value then
		return
	end
	
	ODMG:Equip(Character,PlayerData.ODMG.Generation.Value,PlayerData.ODMG.Variant.Value)
end

function ODMG:Initialize()

	for _,Player:Player in pairs(Players:GetChildren()) do
		if Player.Character then
			Init(Player.Character)
		end

		Player.CharacterAdded:Connect(function(Character)
			Init(Character)
		end)
	end
	
	Players.PlayerAdded:Connect(function(Player)
		Player.CharacterAdded:Connect(function(Character)
			Init(Character)
		end)
	end)

end


local Gear = Assets.Gear
--Character: Jugador al cual se le dara el gear.
--Model: Modelo del gear (ej. Old, Clean, New)
function ODMG:Equip(Character:Model,Generation:string,Variant:string) 
	local newGear:Model = Gear.ODMG[Generation][Variant]:Clone()
	newGear.Name = "ODMG"
	newGear.Parent = Character
	
	local PlayerData = game:GetService("ServerStorage").Assets.PlayerData:WaitForChild(Character.Name)
	PlayerData.ODMG.Equipped.Value = true
	PlayerData.ODMG.Generation.Value = Generation
	PlayerData.ODMG.Variant.Value = Variant

	--print("blup")
	
	--Main
	
	local Exhaust = newGear.Center.Exhaust
	local Torso:BasePart = Character.Torso
	Exhaust.Torso.Part0 = Torso
	
	--Handles
	
	local LeftBlade:Model = newGear["LeftBlade"]
	local RightBlade:Model = newGear["RightBlade"]
	
	local LeftHandle:Motor6D = newGear.LeftBlade.LHandle["Left Handle"]
	local RightHandle:Motor6D = newGear.RightBlade.RHandle["Right Handle"]
	
	LeftHandle.Part0 = Character["Torso"]
	RightHandle.Part0 = Character["Torso"]
	
	LeftHandle.C1 = CFrame.new(Vector3.new(-1, 0.349, -0.361))*CFrame.Angles(math.rad(-40),math.rad(180),math.rad(0))
	RightHandle.C1 = CFrame.new(Vector3.new(1, 0.349, -0.361))*CFrame.Angles(math.rad(-40),math.rad(180),math.rad(0))
	
	newGear.Parent = Character
	
	ODMG:Sheath(Character)	
end

function ODMG:Unequip(Character:Model) 
	local Gear:Model = Character:FindFirstChild("ODMG")
	if not Gear then
		return warn("Este character no tiene gear.")
	end
	
	local PlayerData = game:GetService("ServerStorage").Assets.PlayerData:WaitForChild(Character.Name)
	PlayerData.ODMG.Equipped.Value = false
	PlayerData.ODMG.Generation.Value = ""
	PlayerData.ODMG.Variant.Value = ""
	
	Gear:Destroy()
end

function ODMG:Unsheath(Character:Model)
	local Gear:Model = Character:FindFirstChild("ODMG")
	local LeftBlade:Model = Gear["LeftBlade"]
	local RightBlade:Model = Gear["RightBlade"]
	
	task.wait(0.30)
	
	Gear.OdmRootPart.BladesOut:Play()
	
	LeftBlade.LBlade.Transparency = 0
	RightBlade.RBlade.Transparency = 0
	
	local LEmit = Gear.LeftCanister.LHolster.Emit
	local REmit = Gear.RightCanister.RHolster.Emit
	
	LEmit.Sparks2.Enabled = true
	LEmit.light.Range = 5
	LEmit.light.Enabled = true
	REmit.Sparks2.Enabled = true
	REmit.light.Range = 5
	REmit.light.Enabled = true
	
	task.wait(0.38)
	
	TS:Create(LEmit.light,TweenInfo.new(0.1),{Range = 0}):Play()
	TS:Create(REmit.light,TweenInfo.new(0.1),{Range = 0}):Play()
	
	LEmit.Sparks2.Enabled = false
	REmit.Sparks2.Enabled = false
end

function ODMG:Sheath(Character:Model)
	local Gear:Model = Character:FindFirstChild("ODMG")
	local LeftBlade:Model = Gear["LeftBlade"]
	local RightBlade:Model = Gear["RightBlade"]

	task.wait(0.26)

	Gear.OdmRootPart.BladesIn:Play()

	task.wait(0.30)

	LeftBlade.LBlade.Transparency = 1
	RightBlade.RBlade.Transparency = 1
end

function ODMG:Light(Character:Model)
	
end

--Handles
function ODMG:Handles(Character:Model,Enabled:boolean)
	local ODMG = Character:FindFirstChild("ODMG")
	if not ODMG then
		return error("Este personaje no tiene ODMG.")
	end
	
	local RHandle:Motor6D = ODMG["RightBlade"]["RHandle"]["Right Handle"]
	local LHandle:Motor6D = ODMG["LeftBlade"]["LHandle"]["Left Handle"]
	
	RHandle.Parent.Equip:Play()
	
	if Enabled then
		LHandle.Part0 = Character["Left Arm"]
		RHandle.Part0 = Character["Right Arm"]
		LHandle.C1 = CFrame.new(Vector3.new(-0.155, 1.036, 0.13))*CFrame.Angles(0,0,0)
		RHandle.C1 = CFrame.new(Vector3.new(0.108, 1.036, 0.131))*CFrame.Angles(0,0,0)
	else
		LHandle.Part0 = Character["Torso"]
		RHandle.Part0 = Character["Torso"]
		LHandle.C1 = CFrame.new(Vector3.new(-1, 0.349, -0.361))*CFrame.Angles(math.rad(-40),math.rad(180),math.rad(0))
		RHandle.C1 = CFrame.new(Vector3.new(1, 0.349, -0.361))*CFrame.Angles(math.rad(-40),math.rad(180),math.rad(0))
	end
end


return ODMG
