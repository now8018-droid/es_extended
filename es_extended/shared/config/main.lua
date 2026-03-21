Config = {}

local txAdminLocale = GetConvar("txAdmin-locale", "en")
local esxLocale = GetConvar("esx:locale", "invalid")
Config.Locale = (esxLocale ~= "invalid") and esxLocale or (txAdminLocale ~= "custom" and txAdminLocale) or "en"

-- ใช้กระเป๋าสคริปต์ของคุณเอง (ไม่ใช้ UI/NUI กระเป๋าเริ่มต้นของ ESX และไม่ใช้ ox_inventory)
Config.CustomInventory = true

Config.Accounts = {
    bank = {
        label = TranslateCap("account_bank"),
        round = true,
    },
    black_money = {
        label = TranslateCap("account_black_money"),
        round = true,
    },
    money = {
        label = TranslateCap("account_money"),
        round = true,
    },
}

Config.StartingAccountMoney = { bank = 50000 }

Config.StartingInventoryItems = false -- ใช้ค่าเป็นตารางหรือ false

Config.DefaultSpawns = { -- หากต้องการเพิ่มจุดเกิดและสุ่มใช้งาน ให้เอาคอมเมนต์ออกหรือเพิ่มตำแหน่งใหม่
    { x = 222.2027, y = -864.0162, z = 30.2922, heading = 1.0 },
    --{x = 224.9865, y = -865.0871, z = 30.2922, heading = 1.0},
    --{x = 227.8436, y = -866.0400, z = 30.2922, heading = 1.0},
    --{x = 230.6051, y = -867.1450, z = 30.2922, heading = 1.0},
    --{x = 233.5459, y = -868.2626, z = 30.2922, heading = 1.0}
}

Config.AdminGroups = {
    ["owner"] = true,
    ["admin"] = true,
}

-- เดิมอยู่ใน shared/config/adjustments.lua + client/modules/adjustments.lua (ลบแล้ว)
Config.DisableHealthRegeneration = true -- ปิดการฟื้นฟูพลังชีวิตอัตโนมัติ
Config.EnablePVP = true -- อนุญาตให้ผู้เล่นต่อสู้กัน (friendly fire)

Config.ValidCharacterSets = { -- เปิดใช้ชุดอักขระเพิ่มเติมเฉพาะเมื่อเซิร์ฟเวอร์ของคุณรองรับหลายภาษา ค่าเริ่มต้นเป็น false ทั้งหมด.
    ['el'] = false, -- ภาษากรีก
    ['sr'] = false, -- อักษรซีริลลิก
    ['he'] = false, -- ภาษาฮิบรู
    ['ar'] = false, -- ภาษาอาหรับ
    ['zh-cn'] = false -- จีน ญี่ปุ่น เกาหลี
}

Config.EnablePaycheck = true -- เปิดใช้งานเงินเดือน
Config.LogPaycheck = false -- บันทึกการจ่ายเงินเดือนไปยังห้อง Discord ที่กำหนดผ่าน webhook (ค่าเริ่มต้นคือ false)
Config.EnableSocietyPayouts = false -- จ่ายเงินจากบัญชี society ของงานที่ผู้เล่นสังกัดอยู่หรือไม่? ต้องใช้ esx_society
Config.MaxWeight = 24 -- น้ำหนักสูงสุดของกระเป๋าโดยไม่ใส่เป้
Config.InventoryMode = "limit" -- โหมดกระเป๋าแบบจำกัดจำนวน โดยจะไม่ใช้น้ำหนักในการตรวจสอบการถือของ
Config.DefaultItemLimit = -1 -- ค่าจำกัดสำรองเมื่อไอเท็มนั้นไม่ได้กำหนด limit ไว้
-- เมื่อ CustomInventory = false และเปิดระบบ pickup เดิมของ ESX (ฝั่ง client ลบแล้ว — ควรคง false)
Config.EnablePickupSystem = false
Config.PaycheckInterval = 7 * 60000 -- ระยะเวลาการรับเงินเดือน หน่วยเป็นมิลลิวินาที
-- 1000-player tuning: batch DB every 10-20s, no gameplay DB queries
Config.SaveInterval = 15000 -- 15s default; use 10000-20000 for high-pop. Batch DB writes only.
Config.SaveBatchSize = 1 -- Max 1-2 players per tick for stable resmon (~0.01 ms)
Config.SaveBatchDelay = 8 -- 5-10 ms between jobs; prevents save spikes
Config.CriticalMoneySaveThreshold = 50000 -- Immediate save when money delta >= threshold
Config.CriticalRareItemDelta = 1 -- Immediate save for rare item delta >= threshold
Config.CriticalSaveCooldownMs = 1500 -- Prevent immediate-save spam per player
Config.ReconnectCooldownMs = 5000 -- Block rapid reconnects to reduce rollback races
Config.SyncBatchSize = 8 -- Max players per tick for inventory/account sync
Config.SyncBatchDelay = 10 -- ms between sync batches
Config.ScopeBatchSize = 64 -- Players per tick when rebuilding scope cache
Config.GCStepSize = 2048 -- collectgarbage("step") kB between batches; 0 = disabled
Config.InventorySyncInterval = 750 -- Delta sync interval (ms)
Config.InventorySyncRateLimit = 500 -- Min delay between syncs per player (ms)
Config.LoginQueueInterval = 1000 -- ช่วงเวลาประมวลผลคิวเข้าสู่ระบบ หน่วยเป็นมิลลิวินาที
Config.LoginQueueBatchSize = 4 -- จำนวนผู้เล่นสูงสุดที่ประมวลผลจากคิวต่อรอบ
Config.PaycheckChunkSize = 32 -- จำนวนผู้เล่นที่ประมวลผลต่อหนึ่งชุดของการจ่ายเงินเดือน
Config.PaycheckChunkDelay = 50 -- ระยะเวลาหน่วงระหว่างแต่ละชุดการจ่ายเงินเดือน หน่วยเป็นมิลลิวินาที
-- Client CPU: one unified tick (ped + vehicle + weapon + pause). Higher = lower resmon (may feel slightly less snappy).
Config.ClientActionLoopInterval = 2500
Config.PedLoopInterval = 2500 -- legacy alias; prefer ClientActionLoopInterval
Config.SlowLoopInterval = 2500
Config.EnablePlayerSyncLookAt = false -- NetworkSetLocalPlayerSyncLookAt — small cost; off for minimal resmon
Config.ClientStatebagCoordsInterval = 8000 -- Push coords interval (ms); larger = less Lua/native work
Config.ClientStatebagCoordsMinMove = 4.0 -- Meters before pushing again (fewer statebag writes)
Config.PlayerScopeBucketSize = 128.0 -- Spatial bucket size for scope
Config.PlayerScopeRefreshInterval = 2000 -- 2s when using client statebag coords; server loop disabled for event-driven
Config.UseClientStatebagCoords = true -- Clients push coords to statebag; no server position loop (1000-player)
Config.EventThrottle = {
    giveItem = 300,
    removeInventory = 300,
    useItem = 200,
}
Config.WeaponAutoDetect = true -- สแกน resource เพื่อหาไฟล์ meta ของอาวุธเสริมโดยอัตโนมัติ
Config.WeaponAutoDetectFiles = {
    "weapons.meta",
    "weaponcomponents.meta",
    "stream/weapons.meta",
    "stream/weaponcomponents.meta",
}
Config.WeaponTypeNamePatterns = {
    pistol = { "PISTOL", "REVOLVER" },
    rifle = { "RIFLE", "CARBINE", "M4", "AK", "BULLPUP" },
    smg = { "SMG", "PDW", "MACHINEPISTOL" },
    shotgun = { "SHOTGUN" },
    sniper = { "SNIPER", "MARKSMAN" },
    throwable = { "GRENADE", "MOLOTOV", "STICKY", "BOMB", "MINE", "SNOWBALL", "BZGAS", "BALL", "FLARE" },
}
Config.WeaponTypeDefaults = {
    unknown = { maxAmmo = 250, minFireInterval = 120, maxRange = 120.0, minDamage = 0, maxDamage = 75, spreadTolerance = 0.0035, recoilTolerance = 8.0 },
    melee = { maxAmmo = 0, minFireInterval = 350, maxRange = 3.5, minDamage = 1, maxDamage = 60, spreadTolerance = 0.0, recoilTolerance = 0.0 },
    pistol = { maxAmmo = 250, minFireInterval = 110, maxRange = 90.0, minDamage = 1, maxDamage = 55, spreadTolerance = 0.0032, recoilTolerance = 7.5 },
    smg = { maxAmmo = 500, minFireInterval = 65, maxRange = 110.0, minDamage = 1, maxDamage = 45, spreadTolerance = 0.0045, recoilTolerance = 8.5 },
    rifle = { maxAmmo = 500, minFireInterval = 85, maxRange = 180.0, minDamage = 1, maxDamage = 65, spreadTolerance = 0.0040, recoilTolerance = 9.0 },
    shotgun = { maxAmmo = 120, minFireInterval = 260, maxRange = 40.0, minDamage = 2, maxDamage = 120, spreadTolerance = 0.0090, recoilTolerance = 12.0 },
    sniper = { maxAmmo = 50, minFireInterval = 900, maxRange = 450.0, minDamage = 10, maxDamage = 160, spreadTolerance = 0.0010, recoilTolerance = 5.0 },
    launcher = { maxAmmo = 20, minFireInterval = 800, maxRange = 350.0, minDamage = 20, maxDamage = 250, spreadTolerance = 0.0120, recoilTolerance = 14.0 },
    throwable = { maxAmmo = 25, minFireInterval = 500, maxRange = 60.0, minDamage = 5, maxDamage = 150, spreadTolerance = 0.0080, recoilTolerance = 6.0 },
    utility = { maxAmmo = 4500, minFireInterval = 150, maxRange = 25.0, minDamage = 0, maxDamage = 10, spreadTolerance = 0.0, recoilTolerance = 0.0 },
    heavy = { maxAmmo = 9999, minFireInterval = 55, maxRange = 220.0, minDamage = 1, maxDamage = 90, spreadTolerance = 0.0060, recoilTolerance = 12.0 },
}
Config.SaveDeathStatus = true -- บันทึกสถานะการตายของผู้เล่น
Config.EnableDebug = false -- เปิดใช้ตัวเลือก Debug หรือไม่
Config.EnablePerformanceDebug = true -- ติดตามตัวนับและคำเตือนของเส้นทางทำงานที่ช้า
Config.SlowFunctionWarningMs = 25 -- แจ้งเตือนเมื่อเส้นทางหลักใช้เวลานานเกินค่านี้ในโหมด debug

Config.DefaultJobDuty = true -- สถานะเข้างานเริ่มต้นของผู้เล่นเมื่อเปลี่ยนอาชีพ
Config.OffDutyPaycheckMultiplier = 0.5 -- ตัวคูณเงินเดือนตอนนอกเวลางาน เช่น 0.5 = 50% ของเงินเดือนตอนเข้างาน

Config.Multichar = false -- ไม่ใช้ multichar
Config.Identity = true -- เก็บข้อมูลตัวตนของตัวละครไว้สำหรับเซิร์ฟเวอร์ตัวละครเดียวหากต้องการ
Config.DistanceGive = 4.0 -- ระยะสูงสุดในการให้ไอเท็ม อาวุธ และอื่น ๆ

Config.AdminLogging = false -- บันทึกการใช้คำสั่งบางอย่างของผู้ที่มีสิทธิ์ group.admin ace (ค่าเริ่มต้นคือ false)

Config.EnableDefaultInventory = false -- ปิด NUI/F2 กระเป๋า ESX (ใช้กระเป๋าคัสตอม)
