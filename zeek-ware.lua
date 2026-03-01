-- [[ Zeek.Ware v1.3 | Premium Logic + Xeno Support ]] --
local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'
local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

-- // Services
local Players, RunService, UserInputService, Lighting = game:GetService("Players"), game:GetService("RunService"), game:GetService("UserInputService"), game:GetService("Lighting")
local LocalPlayer, Camera, Mouse = Players.LocalPlayer, workspace.CurrentCamera, Players.LocalPlayer:GetMouse()

-- // Global Logic Objects
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness, FOVCircle.NumSides, FOVCircle.Transparency = 1, 64, 1

-- // UI Window
local Window = Library:CreateWindow({ Title = 'Zeek.Ware | Roblox Rivals', Center = true, AutoShow = true, TabPadding = 8, MenuFadeTime = 0.2 })
local Tabs = { Combat = Window:AddTab('Combat'), Visuals = Window:AddTab('Visuals'), ['UI Settings'] = Window:AddTab('UI Settings') }

-- ===========================
-- UI CONSTRUCTION (COMBAT)
-- ===========================
local AimbotGroup = Tabs.Combat:AddLeftGroupbox('Aimbot')
AimbotGroup:AddToggle('AimbotEnabled', { Text = 'Enable Aimbot' }):AddKeyPicker('AimbotBind', { Default = 'MouseButton2', Mode = 'Hold', Text = 'Aimbot Key' })
AimbotGroup:AddToggle('AimbotTeamCheck', { Text = 'Team Check', Default = true })
AimbotGroup:AddSlider('AimbotFOV', { Text = 'FOV Size', Default = 100, Min = 10, Max = 800 })
AimbotGroup:AddToggle('ShowFOVCircle', { Text = 'Show FOV Circle' })
AimbotGroup:AddToggle('AimbotVisibleCheck', { Text = 'Visible Check', Default = true })
AimbotGroup:AddDropdown('AimbotHitbox', { Values = { 'Head', 'UpperTorso', 'HumanoidRootPart' }, Default = 1, Text = 'Target Hitbox' })
AimbotGroup:AddSlider('AimbotSmoothing', { Text = 'Smoothing', Default = 5, Min = 1, Max = 20 })
AimbotGroup:AddToggle('AimPrediction', { Text = 'Aim Prediction' })
AimbotGroup:AddSlider('PredictionStrength', { Text = 'Pred Strength', Default = 1, Min = 0, Max = 5 })

local TriggerGroup = Tabs.Combat:AddLeftGroupbox('Trigger Bot')
TriggerGroup:AddToggle('TriggerBotEnabled', { Text = 'Enable Trigger Bot' }):AddKeyPicker('TriggerBind', { Default = 'None', Mode = 'Hold', Text = 'Trigger Key' })
TriggerGroup:AddSlider('TriggerDelay', { Text = 'Delay (ms)', Default = 20, Min = 0, Max = 500 })

local SilentAimGroup = Tabs.Combat:AddRightGroupbox('Silent Aim')
SilentAimGroup:AddToggle('SilentAimEnabled', { Text = 'Enable Silent Aim' }):AddKeyPicker('SilentAimBind', { Default = 'None', Mode = 'Always', Text = 'Silent Aim Key' })
SilentAimGroup:AddSlider('SilentAimHitchance', { Text = 'Hit Chance %', Default = 100, Min = 0, Max = 100 })
SilentAimGroup:AddDropdown('SilentAimPart', { Values = { 'Head', 'UpperTorso' }, Default = 1, Text = 'Target Part' })

local WeaponGroup = Tabs.Combat:AddRightGroupbox('Weapon Mods')
WeaponGroup:AddToggle('NoRecoil', { Text = 'No Recoil' })
WeaponGroup:AddToggle('NoSpread', { Text = 'No Spread' })
WeaponGroup:AddToggle('InfiniteAmmo', { Text = 'Infinite Ammo' })
WeaponGroup:AddToggle('RapidFire', { Text = 'Rapid Fire' })
WeaponGroup:AddToggle('AutomaticWeapons', { Text = 'Full Auto' })

-- ===========================
-- UI CONSTRUCTION (VISUALS)
-- ===========================
local ESPGroup = Tabs.Visuals:AddLeftGroupbox('ESP')
ESPGroup:AddToggle('ESPEnabled', { Text = 'Enable ESP' })
ESPGroup:AddToggle('ESPBoxes', { Text = 'Boxes', Default = true })
ESPGroup:AddToggle('ESPNames', { Text = 'Names', Default = true })
ESPGroup:AddToggle('ESPHealth', { Text = 'Health Bar', Default = true })
ESPGroup:AddToggle('ESPTracers', { Text = 'Tracers' })
ESPGroup:AddLabel('ESP Colors'):AddColorPicker('ESPColor', { Default = Color3.fromRGB(255, 255, 255) })

local WorldGroup = Tabs.Visuals:AddLeftGroupbox('World')
WorldGroup:AddToggle('Fullbright', { Text = 'Fullbright' })
WorldGroup:AddSlider('FOVChanger', { Text = 'Camera FOV', Default = 70, Min = 70, Max = 120 })

-- ===========================
-- PREMIUM BACKEND LOGIC
-- ===========================

-- // Target Acquisition
local function GetClosestTarget()
    local MaxDist, TargetPlayer = Options.AimbotFOV.Value, nil
    local MouseLoc = UserInputService:GetMouseLocation()
    for _, v in pairs(Players:GetPlayers()) do
        if v ~= LocalPlayer and v.Character and v.Character:FindFirstChild("Humanoid") and v.Character.Humanoid.Health > 0 then
            if Toggles.AimbotTeamCheck.Value and v.Team == LocalPlayer.Team then continue end
            local Part = v.Character:FindFirstChild(Options.AimbotHitbox.Value)
            if Part then
                local Pos, OnScreen = Camera:WorldToViewportPoint(Part.Position)
                if OnScreen then
                    local Distance = (Vector2.new(Pos.X, Pos.Y) - MouseLoc).Magnitude
                    if Distance < MaxDist then
                        if Toggles.AimbotVisibleCheck.Value then
                            local RayParam = RaycastParams.new()
                            RayParam.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
                            local Result = workspace:Raycast(Camera.CFrame.Position, (Part.Position - Camera.CFrame.Position).Unit * 1000, RayParam)
                            if not Result or not Result.Instance:IsDescendantOf(v.Character) then continue end
                        end
                        MaxDist, TargetPlayer = Distance, v
                    end
                end
            end
        end
    end
    return TargetPlayer
end

-- // Metatable Hook for Silent Aim
local OldNC
OldNC = hookmetamethod(game, "__namecall", function(self, ...)
    local Method, Args = getnamecallmethod(), {...}
    if not checkcaller() and Toggles.SilentAimEnabled.Value and Options.SilentAimBind:GetState() then
        if Method == "Raycast" or Method == "FindPartOnRay" then
            local AimTarget = GetClosestTarget()
            if AimTarget and math.random(1, 100) <= Options.SilentAimHitchance.Value then
                local HitPart = AimTarget.Character[Options.SilentAimPart.Value]
                if Method == "Raycast" then Args[2] = (HitPart.Position - Args[1]).Unit * 1000 else Args[1] = Ray.new(Camera.CFrame.Position, (HitPart.Position - Camera.CFrame.Position).Unit * 1000) end
                return OldNC(self, unpack(Args))
            end
        end
    end
    return OldNC(self, ...)
end)

-- // Memory Scanner (Weapon Mods)
task.spawn(function()
    while task.wait(0.5) do
        for _, v in pairs(getgc(true)) do
            if type(v) == "table" and rawget(v, "FireRate") then
                if Toggles.NoRecoil.Value then v.Recoil = 0 v.RecoilData = {Min=0,Max=0} end
                if Toggles.NoSpread.Value then v.Spread = 0 v.VariableSpread = 0 end
                if Toggles.RapidFire.Value then v.FireRate = 0.01 end
                if Toggles.AutomaticWeapons.Value then v.Automatic = true end
                if Toggles.InfiniteAmmo.Value then v.Ammo = 999 v.MaxAmmo = 999 end
            end
        end
    end
end)

-- // ESP Update Loop
local ESP_Cache = {}
local function UpdateESP()
    for _, p in pairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        if not ESP_Cache[p] then ESP_Cache[p] = { Box = Drawing.new("Square"), Text = Drawing.new("Text") } end
        local obj, char = ESP_Cache[p], p.Character
        if Toggles.ESPEnabled.Value and char and char:FindFirstChild("HumanoidRootPart") and char.Humanoid.Health > 0 then
            local Pos, OnScreen = Camera:WorldToViewportPoint(char.HumanoidRootPart.Position)
            if OnScreen then
                local Size = (3000 / Pos.Z)
                obj.Box.Visible, obj.Box.Size, obj.Box.Position, obj.Box.Color = Toggles.ESPBoxes.Value, Vector2.new(Size * 0.7, Size), Vector2.new(Pos.X - (Size * 0.7)/2, Pos.Y - Size/2), Options.ESPColor.Value
                obj.Text.Visible, obj.Text.Text, obj.Text.Position = Toggles.ESPNames.Value, p.Name .. " [" .. math.floor(char.Humanoid.Health) .. "]", Vector2.new(Pos.X, Pos.Y - Size/2 - 15)
                obj.Text.Center, obj.Text.Outline = true, true
                continue
            end
        end
        obj.Box.Visible, obj.Text.Visible = false, false
    end
end

-- // Main Performance Loop
RunService.RenderStepped:Connect(function()
    FOVCircle.Visible, FOVCircle.Radius, FOVCircle.Position, FOVCircle.Color = Toggles.ShowFOVCircle.Value, Options.AimbotFOV.Value, UserInputService:GetMouseLocation(), Options.AccentColor.Value
    if Toggles.AimbotEnabled.Value and Options.AimbotBind:GetState() then
        local AimTarget = GetClosestTarget()
        if AimTarget then
            local HitPart = AimTarget.Character[Options.AimbotHitbox.Value]
            local Predict = Toggles.AimPrediction.Value and (HitPart.Velocity * (Options.PredictionStrength.Value / 10)) or Vector3.new(0,0,0)
            local ScreenPos, MouseLoc = Camera:WorldToViewportPoint(HitPart.Position + Predict), UserInputService:GetMouseLocation()
            mousemoverel((ScreenPos.X - MouseLoc.X) / Options.AimbotSmoothing.Value, (ScreenPos.Y - MouseLoc.Y) / Options.AimbotSmoothing.Value)
        end
    end
    if Toggles.TriggerBotEnabled.Value and Options.TriggerBind:GetState() and Mouse.Target then
        local TargetPlr = Players:GetPlayerFromCharacter(Mouse.Target.Parent)
        if TargetPlr and TargetPlr.Team ~= LocalPlayer.Team then task.wait(Options.TriggerDelay.Value / 1000) mouse1click() end
    end
    if Toggles.Fullbright.Value then Lighting.Brightness, Lighting.ClockTime, Lighting.GlobalShadows = 2, 14, false end
    Camera.FieldOfView = Options.FOVChanger.Value
    UpdateESP()
end)

-- // Settings Initialization
local MenuGroup = Tabs['UI Settings']:AddLeftGroupbox('Menu')
MenuGroup:AddButton('Unload', function() Library:Unload() end)
MenuGroup:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', { Default = 'RightControl', NoUI = true, Text = 'Menu Keybind' })
Library.ToggleKeybind = Options.MenuKeybind
ThemeManager:SetLibrary(Library); SaveManager:SetLibrary(Library); ThemeManager:SetFolder('ZeekWare'); SaveManager:SetFolder('ZeekWare/Configs')
SaveManager:BuildConfigSection(Tabs['UI Settings']); ThemeManager:ApplyToTab(Tabs['UI Settings'])
Library:Notify('Zeek.Ware v1.3 Activated', 5)