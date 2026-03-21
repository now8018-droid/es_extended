--- เดิมจาก client/modules/adjustments.lua — เหลือเฉพาะเลือด + PvP

---@return nil
function ESX.ApplyPlayerClientSettings()
    if Config.DisableHealthRegeneration then
        SetPlayerHealthRechargeMultiplier(ESX.playerId, 0.0)
    end

    local ped = ESX.PlayerData and ESX.PlayerData.ped
    if Config.EnablePVP and ped and ped ~= 0 then
        SetCanAttackFriendly(ped, true, false)
        NetworkSetFriendlyFireOption(true)
    end
end

-- หลัง spawn / เปลี่ยน ped ให้ตั้ง PvP ใหม่
AddEventHandler("esx:onPlayerSpawn", function()
    if not Config.EnablePVP then
        return
    end
    local ped = PlayerPedId()
    if ped and ped ~= 0 then
        SetCanAttackFriendly(ped, true, false)
        NetworkSetFriendlyFireOption(true)
    end
end)

-- สคริปต์ภายนอกบางตัวยังเรียก Adjustments:FrameLoop / :Load
Adjustments = Adjustments or {}
function Adjustments:FrameLoop() end

function Adjustments:Load()
    ESX.ApplyPlayerClientSettings()
end
