local OrionLib = loadstring(game:HttpGet(('https://raw.githubusercontent.com/jensonhirst/Orion/main/source')))()

local Window = OrionLib:MakeWindow({Name = "ตัวเทส", HidePremium = false, SaveConfig = true, ConfigFolder = "ตัวเทส นะจ๊ะ"})

--------------------------------------------------Main-------------------------------------------------------------------------------------

local Tab = Window:MakeTab({
    Name = "Main",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

-- ตัวแปรและการตั้งค่า
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local hrp = character:WaitForChild("HumanoidRootPart")

-- อัปเดต hrp เมื่อตัวละครเกิดใหม่
player.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    hrp = newCharacter:WaitForChild("HumanoidRootPart")
end)

-- ตรวจสอบ SamTimer
if not SamTimer then
    OrionLib:MakeNotification({
        Name = "ข้อผิดพลาด",
        Content = "ไม่พบ SamTimer ใน PlayerGui!",
        Time = 2
    })
end

-- ค่าคงที่
local ITEM_USE_DELAY = 0.01 -- ลด delay หลังใช้ไอเทมแต่ละชิ้น
local EQUIP_DELAY = 0.005 -- ลด delay การสวมใส่ไอเทม
local ANTI_BAN_RANDOM_DELAY = 0.01 -- ลด delay สุ่มเพื่อป้องกันการตรวจจับ
local ANTI_BAN_MAX_RANDOM_DELAY = 0.05 -- ลดค่าสูงสุดของ delay สุ่ม
local FISH_MERCHANT_PROXIMITY_THRESHOLD = 700 -- ระยะห่างสูงสุดถึง FishMerchant (หน่วย studs)
local TELEPORT_OFFSET = Vector3.new(0, 0, -5) -- Offset ไปด้านหน้าของ FishMerchant
local CLICK_OFFSET = 3
local CLICK_RETRIES = 3
local COOLDOWN = 15
local MAX_CLICK_DISTANCE = 10
local MAX_BARREL_TWEEN_DISTANCE = 50 -- ระยะห่างสูงสุดสำหรับการเคลื่อนไปยังถังและลังใน Auto Mode
local MAX_BARREL_LOOPS = 10
local BARREL_SWITCH_DELAY = 2.0
local BARREL_FARM_DELAY = 0.5 -- ลด delay หลังเก็บถัง/ลังแต่ละรอบ
local BARREL_LOOP_RESET_DELAY = 5.0 -- ลด delay เมื่อครบรอบ
local ITEM_USE_DELAY = 0.3
local EQUIP_DELAY = 0.1
local MIXER_CLICK_DELAY = 0.5
local MIXER_CLICK_COUNT = 1
local tweenDuration = 0.5
local fruitThreshold = 10
local AUTO_MODE_LOOP_DELAY = 0.5 -- ลด delay ในลูป Auto Mode

-- รายการไอเทมที่อนุญาต
local allowedTools = {
    "Pear Juice",
    "Coconut Milk",
    "Fruit Juice",
    "Sour Juice",
    "Banana Juice",
    "Apple Juice",
    "Pumpkin Juice"
}

-- รายการผลไม้สำหรับตรวจสอบ
local fruits = {
    "Prickly ",
    "Cantaloupe",
    "Melon",
    "Green Apple",
    "Banana",
    "Apple",
    "Pumpkin"
}

-- โฟลเดอร์และตัวแปร
local BarrelsFolder = workspace:FindFirstChild("Barrels") and workspace.Barrels:FindFirstChild("Barrels")
local CratesFolder = workspace:FindFirstChild("Barrels") and workspace.Barrels:FindFirstChild("Crates")
local Island8 = workspace:FindFirstChild("Island8")
local Kitchen = Island8 and Island8:FindFirstChild("Kitchen")
local Mixer = Kitchen and Kitchen:GetChildren()[3] and Kitchen:GetChildren()[3]:FindFirstChild("JuicingBowl") and Kitchen:GetChildren()[3].JuicingBowl:FindFirstChild("Mixer1")
local MixerClickDetector = Mixer and Mixer:FindFirstChild("ClickDetector")
local barrelCooldowns = {}
local autoFarmBarrelsEnabled = false
local autoFarmMixerEnabled = false
local autoUseItemsEnabled = false
local autoModeEnabled = false
local barrelLoopCount = 0
local lastMixerClickTime = 0
local CLAIM_SAM_DELAY = 1500
local CLAIM_SAM_RANDOM_DELAY = 1500
local args = {"Claim10"}

-- ตรวจสอบโฟลเดอร์
if not BarrelsFolder then
    OrionLib:MakeNotification({
        Name = "ข้อผิดพลาด",
        Content = "ไม่พบ BarrelsFolder ใน workspace!",
        Time = 2
    })
    BarrelsFolder = workspace
end
if not CratesFolder then
    OrionLib:MakeNotification({
        Name = "ข้อผิดพลาด",
        Content = "ไม่พบ CratesFolder ใน workspace!",
        Time = 2
    })
    CratesFolder = workspace
end
if not Mixer or not MixerClickDetector then
    OrionLib:MakeNotification({
        Name = "ข้อผิดพลาด",
        Content = "ไม่พบ Mixer หรือ ClickDetector ใน Island8.Kitchen!",
        Time = 2
    })
end

-- ฟังก์ชันสุ่มดีเลย์เพื่อป้องกันการตรวจจับ
local function randomDelay(min, max)
    return task.wait(min + math.random() * (max - min))
end

-- ฟังก์ชันแยกวิเคราะห์พาธ
local function parsePath(pathString)
    local path = workspace
    for part in string.gmatch(pathString, "[^%.%[%]]+") do
        if string.match(part, "%d+") then
            path = path:GetChildren()[tonumber(part)]
        else
            path = path:FindFirstChild(part)
        end
        if not path then
            return nil
        end
    end
    return path
end

-- ฟังก์ชันตรวจสอบว่ามี juices ใน Backpack หรือไม่
local function hasJuices()
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return false end
    for _, tool in ipairs(backpack:GetChildren()) do
        if table.find(allowedTools, tool.Name) and tool:IsA("Tool") then
            return true
        end
    end
    return false
end

-- ฟังก์ชันนับจำนวนผลไม้ใน Backpack
local function countFruits()
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return 0 end
    local count = 0
    for _, tool in ipairs(backpack:GetChildren()) do
        if table.find(fruits, tool.Name) and tool:IsA("Tool") then
            count = count + 1
        end
    end
    return count
end

-- ฟังก์ชันเคลื่อนที่ด้วย TweenService พร้อมปรับระยะเวลา tween ตามระยะห่าง
local function tweenToPosition(targetPos)
    if not hrp then
        OrionLib:MakeNotification({
            Name = "ข้อผิดพลาด",
            Content = "ไม่พบ HumanoidRootPart!",
            Time = 1
        })
        return false
    end
    local randomOffset = Vector3.new(
        math.random(-0.5, 0.5),
        0,
        math.random(-0.5, 0.5)
    )
    local heightOffset = autoFarmMixerEnabled and (CLICK_OFFSET - 2) or (CLICK_OFFSET + 2)
    local adjustedTargetPos = targetPos + Vector3.new(0, heightOffset, 0)
    local distance = (hrp.Position - targetPos).Magnitude
    local dynamicTweenDuration = math.min(tweenDuration, distance / 10)
    local tweenInfo = TweenInfo.new(dynamicTweenDuration + math.random(0, 0.3), Enum.EasingStyle.Linear, Enum.EasingDirection.InOut)
    local tween = TweenService:Create(hrp, tweenInfo, {CFrame = CFrame.new(adjustedTargetPos + randomOffset)})
    tween:Play()
    tween.Completed:Wait()
    randomDelay(ANTI_BAN_RANDOM_DELAY, ANTI_BAN_MAX_RANDOM_DELAY)
    return true
end

-- ฟังก์ชันตรวจสอบความถูกต้องของเป้าหมาย (ถังหรือลัง)
local function isValidTarget(target)
    return target and target:IsA("BasePart") and target.Parent and target:FindFirstChildOfClass("ClickDetector")
end

-- ฟังก์ชันตรวจสอบความถูกต้องของ Tool
local function isValidTool(tool)
    return tool and tool:IsA("Tool") and tool.Parent and tool:FindFirstChild("Handle") and table.find(allowedTools, tool.Name)
end

-- ฟังก์ชันตรวจสอบความถูกต้องของ Mixer ClickDetector
local function isValidMixer()
    return Mixer and MixerClickDetector and MixerClickDetector:IsA("ClickDetector") and Mixer.Parent and hrp
end

-- ฟังก์ชันคลิกเป้าหมาย (ถังหรือลัง)
local function clickTarget(target)
    if not isValidTarget(target) or not hrp then
        OrionLib:MakeNotification({
            Name = "ข้อผิดพลาด",
            Content = "เป้าหมายไม่ถูกต้องหรือไม่มี HumanoidRootPart!",
            Time = 1
        })
        return false
    end
    local lastClick = barrelCooldowns[target] or 0
    if tick() - lastClick < COOLDOWN then
        return true
    end

    local targetPos = target.Position
    local distance = (hrp.Position - targetPos).Magnitude
    if autoModeEnabled and distance > MAX_BARREL_TWEEN_DISTANCE then
        return false
    end

    if (autoFarmBarrelsEnabled or autoModeEnabled) and not autoUseItemsEnabled and not autoFarmMixerEnabled then
        if not tweenToPosition(targetPos) then
            return false
        end
    else
        return false
    end

    local clickDetector = target:FindFirstChildOfClass("ClickDetector")
    if clickDetector then
        local distance = (hrp.Position - target.Position).Magnitude
        if distance > MAX_CLICK_DISTANCE then
            OrionLib:MakeNotification({
                Name = "ข้อผิดพลาด",
                Content = "ระยะห่างเกิน " .. MAX_CLICK_DISTANCE .. " studs!",
                Time = 1
            })
            return false
        end
        for i = 1, CLICK_RETRIES do
            if not (autoFarmBarrelsEnabled or autoModeEnabled) or autoUseItemsEnabled or autoFarmMixerEnabled then return false end
            fireclickdetector(clickDetector, distance)
            randomDelay(0.1, 0.3)
        end
        barrelCooldowns[target] = tick()
        randomDelay(BARREL_SWITCH_DELAY, BARREL_SWITCH_DELAY + 0.5)
        return true
    else
        OrionLib:MakeNotification({
            Name = "ข้อผิดพลาด",
            Content = "ไม่พบ ClickDetector ในเป้าหมาย!",
            Time = 1
        })
        return false
    end
end

-- ฟังก์ชันกด Mixer1
local function mixJuice()
    if not isValidMixer() then
        OrionLib:MakeNotification({
            Name = "ข้อผิดพลาด",
            Content = "Mixer หรือ ClickDetector ไม่ถูกต้อง!",
            Time = 1
        })
        return false
    end

    local mixerPos = Mixer.Position
    if not tweenToPosition(mixerPos) then
        return false
    end

    local distance = (hrp.Position - Mixer.Position).Magnitude
    if distance > MAX_CLICK_DISTANCE then
        OrionLib:MakeNotification({
            Name = "ข้อผิดพลาด",
            Content = "ระยะห่างจาก Mixer เกิน " .. MAX_CLICK_DISTANCE .. " studs!",
            Time = 1
        })
        return false
    end

    for i = 1, MIXER_CLICK_COUNT do
        if not autoFarmMixerEnabled or autoUseItemsEnabled or autoFarmBarrelsEnabled then
            return false
        end
        local currentTime = tick()
        if currentTime - lastMixerClickTime >= MIXER_CLICK_DELAY then
            fireclickdetector(MixerClickDetector, distance)
            lastMixerClickTime = currentTime
            randomDelay(MIXER_CLICK_DELAY, MIXER_CLICK_DELAY + 0.2)
        end
    end

    return true
end

-- ฟังก์ชันใช้ไอเทมใน Backpack
local function useBackpackItems()
    while true do
        if autoUseItemsEnabled and not autoFarmBarrelsEnabled and not autoFarmMixerEnabled then
            local backpack = player:FindFirstChild("Backpack")
            if not backpack then
                OrionLib:MakeNotification({
                    Name = "ข้อผิดพลาด",
                    Content = "ไม่พบ Backpack!",
                    Time = 1
                })
                task.wait(0.01)
                continue
            end

            local tools = backpack:GetChildren()
            local foundAllowedTool = false
            local currentIndex = 1

            while currentIndex <= #tools do
                local tool = tools[currentIndex]
                if isValidTool(tool) then
                    foundAllowedTool = true
                    local humanoid = character:FindFirstChildOfClass("Humanoid")
                    if humanoid then
                        humanoid:EquipTool(tool)
                        task.wait(EQUIP_DELAY)
                        if tool.Parent == character then
                            tool:Activate()
                            task.wait(ITEM_USE_DELAY)
                            currentIndex = currentIndex + 1
                        else
                            currentIndex = currentIndex + 1
                        end
                    end
                else
                    currentIndex = currentIndex + 1
                end
            end

            if not foundAllowedTool then
                OrionLib:MakeNotification({
                    Name = "ข้อมูล",
                    Content = "ไม่มีไอเทมที่อนุญาตใน Backpack!",
                    Time = 1
                })
            end
            task.wait(ANTI_BAN_RANDOM_DELAY + math.random() * (ANTI_BAN_MAX_RANDOM_DELAY - ANTI_BAN_RANDOM_DELAY))
        else
            task.wait(0.01)
        end
    end
end

-- ลูปฟาร์มถังและลัง (สำหรับโหมดแมนนวล)
local function autoFarmBarrels()
    while true do
        if autoFarmBarrelsEnabled and not autoUseItemsEnabled and not autoFarmMixerEnabled then
            if not BarrelsFolder or not CratesFolder then
                OrionLib:MakeNotification({
                    Name = "ข้อผิดพลาด",
                    Content = "ไม่พบ BarrelsFolder หรือ CratesFolder!",
                    Time = 2
                })
                randomDelay(2, 3)
            else
                local barrels = BarrelsFolder:GetChildren()
                local crates = CratesFolder:GetChildren()
                local targets = {}
                for _, barrel in ipairs(barrels) do
                    if isValidTarget(barrel) then
                        table.insert(targets, barrel)
                    end
                end
                for _, crate in ipairs(crates) do
                    if isValidTarget(crate) then
                        table.insert(targets, crate)
                    end
                end
                if #targets == 0 then
                    OrionLib:MakeNotification({
                        Name = "ข้อมูล",
                        Content = "ไม่มีถังหรือลังให้คลิก!",
                        Time = 2
                    })
                    randomDelay(2, 3)
                else
                    local allClicked = true
                    local sortedTargets = {}
                    for _, target in ipairs(targets) do
                        local distance = (hrp.Position - target.Position).Magnitude
                        table.insert(sortedTargets, {target = target, distance = distance})
                    end
                    table.sort(sortedTargets, function(a, b) return a.distance < b.distance end)
                    
                    for _, entry in ipairs(sortedTargets) do
                        local target = entry.target
                        if not autoFarmBarrelsEnabled or autoUseItemsEnabled or autoFarmMixerEnabled then
                            allClicked = false
                            break
                        end
                        if target.Parent then
                            if not clickTarget(target) then
                                allClicked = false
                            end
                        end
                    end
                    if allClicked then
                        barrelLoopCount = barrelLoopCount + 1
                        if barrelLoopCount >= MAX_BARREL_LOOPS then
                            barrelLoopCount = 0
                            randomDelay(BARREL_LOOP_RESET_DELAY, BARREL_LOOP_RESET_DELAY + 2)
                        else
                            randomDelay(BARREL_FARM_DELAY, BARREL_FARM_DELAY + 0.5)
                        end
                    end
                end
            end
        end
        randomDelay(BARREL_FARM_DELAY, BARREL_FARM_DELAY + 0.5)
    end
end

-- ลูปฟาร์มถังและลังใน Auto Mode
local function farmBarrelsInAutoMode()
    if not BarrelsFolder or not CratesFolder then
        OrionLib:MakeNotification({
            Name = "ข้อผิดพลาด",
            Content = "ไม่พบ BarrelsFolder หรือ CratesFolder ใน Auto Mode!",
            Time = 2
        })
        return false
    end

    local barrels = BarrelsFolder:GetChildren()
    local crates = CratesFolder:GetChildren()
    local targets = {}
    for _, barrel in ipairs(barrels) do
        if isValidTarget(barrel) then
            table.insert(targets, barrel)
        end
    end
    for _, crate in ipairs(crates) do
        if isValidTarget(crate) then
            table.insert(targets, crate)
        end
    end
    if #targets == 0 then
        OrionLib:MakeNotification({
            Name = "ข้อมูล",
            Content = "ไม่มีถังหรือลังให้คลิกใน Auto Mode!",
            Time = 2
        })
        return false
    end

    local allClicked = true
    local sortedTargets = {}
    for _, target in ipairs(targets) do
        if isValidTarget(target) then
            local distance = (hrp.Position - target.Position).Magnitude
            if distance <= MAX_BARREL_TWEEN_DISTANCE then
                table.insert(sortedTargets, {target = target, distance = distance})
            end
        end
    end
    table.sort(sortedTargets, function(a, b) return a.distance < b.distance end)

    if #sortedTargets == 0 then
        OrionLib:MakeNotification({
            Name = "ข้อมูล",
            Content = "ไม่มีถังหรือลังในระยะ " .. MAX_BARREL_TWEEN_DISTANCE .. " studs!",
            Time = 2
        })
        return false
    end

    for _, entry in ipairs(sortedTargets) do
        local target = entry.target
        if not autoModeEnabled or autoUseItemsEnabled or autoFarmMixerEnabled then
            allClicked = false
            break
        end
        if target.Parent and isValidTarget(target) then
            if not clickTarget(target) then
                allClicked = false
            end
        end
    end

    if allClicked then
        barrelLoopCount = barrelLoopCount + 1
        if barrelLoopCount >= MAX_BARREL_LOOPS then
            barrelLoopCount = 0
            randomDelay(BARREL_LOOP_RESET_DELAY, BARREL_LOOP_RESET_DELAY)
        else
            randomDelay(BARREL_FARM_DELAY, BARREL_FARM_DELAY)
        end
    end
    return allClicked
end

-- ลูปกด Mixer
local function autoFarmMixer()
    while true do
        if autoFarmMixerEnabled and not autoUseItemsEnabled and not autoFarmBarrelsEnabled then
            if not mixJuice() then
                OrionLib:MakeNotification({
                    Name = "ข้อผิดพลาด",
                    Content = "กด Mixer1 ล้มเหลว!",
                    Time = 1
                })
            end
        end
        randomDelay(0.5, 1)
    end
end

-- ฟังก์ชันแปลงเวลาใน SamTimer เป็นวินาที
local function getTimerSeconds(timerText)
    if not timerText or timerText == "" or timerText == "0:00" then
        return 0
    end
    local minutes, seconds = timerText:match("(%d+):(%d+)")
    if minutes and seconds then
        return tonumber(minutes) * 60 + tonumber(seconds)
    end
    return math.huge -- ถ้าแปลงไม่ได้ ให้รอนานเพื่อป้องกันข้อผิดพลาด
end

-- ฟังก์ชัน Auto Claim Sam's Quest
local function autoClaimSam()
    while true do
        if autoClaimSamEnabled and ClaimSamRemote and SamTimer then
            local timerText = SamTimer.Text
            local timerSeconds = getTimerSeconds(timerText)
            
            if timerSeconds > 0 then
                OrionLib:MakeNotification({
                    Name = "AutoClaimSam",
                    Content = "รอ Sam's Quest: เหลือเวลา " .. timerText,
                    Time = 2
                })
            end

            if timerSeconds == 0 then
                ClaimSamRemote:FireServer(unpack(args))
                OrionLib:MakeNotification({
                    Name = "AutoClaimSam",
                    Content = "กดรับ Sam's Quest สำเร็จ!",
                    Time = 2
                })
                randomDelay(CLAIM_SAM_DELAY, CLAIM_SAM_DELAY + CLAIM_SAM_RANDOM_DELAY)
            else
                task.wait(timerSeconds + math.random(0.1, 0.5))
            end
        else
            task.wait(1)
        end
    end
end

-- เริ่ม Coroutines
coroutine.wrap(autoFarmBarrels)()
coroutine.wrap(autoFarmMixer)()
coroutine.wrap(useBackpackItems)()
coroutine.wrap(autoClaimSam)()

-- ลูปสำหรับ Auto Mode
coroutine.wrap(function()
    while true do
        if autoModeEnabled then
            local haveJuices = hasJuices()
            local fruitCount = countFruits()
            if haveJuices then
                autoUseItemsEnabled = true
                autoFarmMixerEnabled = false
                autoFarmBarrelsEnabled = false
            elseif fruitCount >= fruitThreshold then
                autoUseItemsEnabled = false
                autoFarmMixerEnabled = true
                autoFarmBarrelsEnabled = false
            else
                autoUseItemsEnabled = ture
                autoFarmMixerEnabled = false
                autoFarmBarrelsEnabled = true
                farmBarrelsInAutoMode()
            end
        end
        randomDelay(AUTO_MODE_LOOP_DELAY, AUTO_MODE_LOOP_DELAY + 0.5)
    end
end)()

--------------------------------------------------All Auto Farm Mod-------------------------------------------------------------------------------------
local Section = Tab:AddSection({
    Name = "All Auto Farm Mode (UseItems, Mixer, Barrels/Box)"
})

Tab:AddToggle({
    Name = "เปิด Auto Mode",
    Default = false,
    Callback = function(Value)
        if Value then
            local fishMerchant = workspace:FindFirstChild("Merchants") and workspace.Merchants:FindFirstChild("FishMerchant")
            if not fishMerchant then
                OrionLib:MakeNotification({
                    Name = "ข้อผิดพลาด",
                    Content = "ไม่พบ Merchants.FishMerchant ใน Workspace!",
                    Time = 1
                })
                return
            end

            local fishHumanoid = fishMerchant:FindFirstChild("Humanoid")
            local fishRootPart = fishMerchant:FindFirstChild("HumanoidRootPart")
            if not fishHumanoid or not fishRootPart then
                OrionLib:MakeNotification({
                    Name = "ข้อผิดพลาด",
                    Content = "ไม่พบ Humanoid หรือ HumanoidRootPart ใน FishMerchant!",
                    Time = 1
                })
                return
            end

            local fishMerchantPos = fishRootPart.Position + TELEPORT_OFFSET
            local distance = (hrp.Position - fishRootPart.Position).Magnitude
            if distance > FISH_MERCHANT_PROXIMITY_THRESHOLD then
                OrionLib:MakeNotification({
                    Name = "AutoMode",
                    Content = "ตัวละครอยู่ห่างจาก FishMerchant เกิน " .. FISH_MERCHANT_PROXIMITY_THRESHOLD .. " studs, กำลังเคลื่อนย้าย...",
                    Time = 1
                })
                if not tweenToPosition(fishMerchantPos) then
                    OrionLib:MakeNotification({
                        Name = "ข้อผิดพลาด",
                        Content = "การเคลื่อนย้ายไปยัง FishMerchant ล้มเหลว!",
                        Time = 1
                    })
                    return
                end
                OrionLib:MakeNotification({
                    Name = "AutoMode",
                    Content = "เคลื่อนย้ายไปยัง FishMerchant สำเร็จ!",
                    Time = 1
                })
            else
                OrionLib:MakeNotification({
                    Name = "AutoMode",
                    Content = "ตัวละครอยู่ใกล้ FishMerchant แล้ว!",
                    Time = 1
                })
            end

            if autoFarmBarrelsEnabled or autoFarmMixerEnabled or autoUseItemsEnabled or autoClaimSamEnabled then
                autoFarmBarrelsEnabled = false
                autoFarmMixerEnabled = false
                autoUseItemsEnabled = fals
                OrionLib:MakeNotification({
                    Name = "คำเตือน",
                    Content = "ปิดโหมดอื่นเพื่อเปิด Auto Mode!",
                    Time = 1
                })
            end
            autoModeEnabled = true
            OrionLib:MakeNotification({
                Name = "AutoMode",
                Content = "เปิดโหมด Auto Mode!",
                Time = 1
            })
        else
            autoModeEnabled = false
            autoUseItemsEnabled = false
            autoFarmMixerEnabled = false
            autoFarmBarrelsEnabled = false
            barrelLoopCount = 0
            OrionLib:MakeNotification({
                Name = "AutoMode",
                Content = "ปิดโหมด Auto Mode!",
                Time = 1
            })
        end
    end
})

--------------------------------------------------Claim_Sam-------------------------------------------------------------------------------------


-- ฟังก์ชันสำหรับกด Claim_Sam
local function fireClaimSam()
    local success, err = pcall(function()
        local replicatedStorage = game:GetService("ReplicatedStorage")
        local connections = replicatedStorage:WaitForChild("Connections")
        local claimSam = connections:WaitForChild("Claim_Sam")
        claimSam:FireServer(unpack(args))
    end)
    if not success then
    end
end

-- Coroutine สำหรับกดรับอัตโนมัติ
coroutine.wrap(function()
    while true do
        if autoClaimSamEnabled then
            fireClaimSam()
            randomDelay(CLAIM_SAM_DELAY, CLAIM_SAM_DELAY + CLAIM_SAM_RANDOM_DELAY)
        else
            task.wait(1)
        end
    end
end)()

local Section = Tab:AddSection({
    Name = "AutoClaimSamQuest"
})

Tab:AddToggle({
    Name = "AutoClaimSamQuest",
    Default = false,
    Callback = function(Value)
        autoClaimSamEnabled = Value
        if Value and (autoFarmBarrelsEnabled or autoFarmMixerEnabled or autoUseItemsEnabled or autoModeEnabled) then
            autoFarmBarrelsEnabled = false
            autoFarmMixerEnabled = false
            autoUseItemsEnabled = false
            autoModeEnabled = false
        end
    end
})
--------------------------------------------------Island---------------------------------------------------------------------------------------------
local Tab = Window:MakeTab({
    Name = "Island",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})
Tab:AddButton({
	Name = "Button!",
	Callback = function()
      		print("button pressed")
  	end    
})

Tab:AddButton({
	Name = "Button!",
	Callback = function()
      		print("button pressed")
  	end    
})

Tab:AddButton({
	Name = "Button!",
	Callback = function()
      		print("button pressed")
  	end    
})

Tab:AddButton({
	Name = "Button!",
	Callback = function()
      		print("button pressed")
  	end    
})

Tab:AddButton({
	Name = "Button!",
	Callback = function()
      		print("button pressed")
  	end    
})

Tab:AddButton({
	Name = "Button!",
	Callback = function()
      		print("button pressed")
  	end    
})

Tab:AddButton({
	Name = "Button!",
	Callback = function()
      		print("button pressed")
  	end    
})

Tab:AddButton({
	Name = "Button!",
	Callback = function()
      		print("button pressed")
  	end    
})

Tab:AddButton({
	Name = "Button!",
	Callback = function()
      		print("button pressed")
  	end    
})

Tab:AddButton({
	Name = "Button!",
	Callback = function()
      		print("button pressed")
  	end    
})

Tab:AddButton({
	Name = "Button!",
	Callback = function()
      		print("button pressed")
  	end    
})

Tab:AddButton({
	Name = "Button!",
	Callback = function()
      		print("button pressed")
  	end    
})

Tab:AddButton({
	Name = "Button!",
	Callback = function()
      		print("button pressed")
  	end    
})

Tab:AddButton({
	Name = "Button!",
	Callback = function()
      		print("button pressed")
  	end    
})

Tab:AddButton({
	Name = "Button!",
	Callback = function()
      		print("button pressed")
  	end    
})

Tab:AddButton({
	Name = "Button!",
	Callback = function()
      		print("button pressed")
  	end    
})

--------------------------------------------------Options-------------------------------------------------------------------------------------
local Tab = Window:MakeTab({
    Name = "Options",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

Tab:AddSlider({
    Name = "Tween Duration (ช้าหรือเร็วขึ้น)",
    Min = 0.1,
    Max = 50,
    Default = 0.1,
    Color = Color3.fromRGB(255, 255, 255),
    Increment = 0.1,
    ValueName = "วินาที",
    Callback = function(Value)
        tweenDuration = Value
        OrionLib:MakeNotification({
            Name = "Options",
            Content = "ปรับ Tween Duration เป็น " .. Value .. " วินาที!",
            Time = 2
        })
    end    
})

Tab:AddSlider({
    Name = "Fruit Threshold (ปรับ fruitCount)",
    Min = 10,
    Max = 100,
    Default = 30,
    Color = Color3.fromRGB(255, 255, 255),
    Increment = 1,
    ValueName = "ชิ้น",
    Callback = function(Value)
        fruitThreshold = Value
        OrionLib:MakeNotification({
            Name = "Options",
            Content = "ปรับ Fruit Threshold เป็น " .. Value .. " ชิ้น!",
            Time = 2
        })
    end    
})

Tab:AddSlider({
    Name = "Max Barrel/Crate Tween Distance (Auto Mode)",
    Min = 100,
    Max = 1000,
    Default = 500,
    Color = Color3.fromRGB(255, 255, 255),
    Increment = 1,
    ValueName = "studs",
    Callback = function(Value)
        MAX_BARREL_TWEEN_DISTANCE = Value
        OrionLib:MakeNotification({
            Name = "Options",
            Content = "ปรับ Max Barrel/Crate Tween Distance เป็น " .. Value .. " studs ใน Auto Mode!",
            Time = 2
        })
    end    
})

Tab:AddSlider({
    Name = "Barrel/Crate Farm Delay (Auto Mode)",
    Min = 0.1,
    Max = 2,
    Default = 0.5,
    Color = Color3.fromRGB(255, 255, 255),
    Increment = 0.1,
    ValueName = "วินาที",
    Callback = function(Value)
        BARREL_FARM_DELAY = Value
        OrionLib:MakeNotification({
            Name = "Options",
            Content = "ปรับ Barrel/Crate Farm Delay เป็น " .. Value .. " วินาที ใน Auto Mode!",
            Time = 2
        })
    end    
})
