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

-- เดิมอยู่ใน config/adjustments.lua + client/modules/adjustments.lua (ลบแล้ว)
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
-- ปรับค่ารองรับเซิร์ฟเวอร์ 1000 คน: เขียนฐานข้อมูลเป็นชุดทุก 10-20 วินาที และไม่ยิงคิวรี DB ในเส้นทางเกมเพลย์หลัก
Config.SaveInterval = 15000 -- ค่าเริ่มต้น 15 วินาที; เซิร์ฟเวอร์คนเยอะควรใช้ 10000-20000 และให้บันทึกฐานข้อมูลแบบเป็นชุดเท่านั้น
Config.SaveBatchSize = 1 -- จำนวนผู้เล่นสูงสุดที่บันทึกต่อหนึ่งรอบ ควรอยู่ราว 1-2 คนเพื่อให้ resmon นิ่ง (~0.01 ms)
Config.SaveBatchDelay = 8 -- หน่วง 5-10 มิลลิวินาทีระหว่างแต่ละงานบันทึก เพื่อกันโหลดพุ่งเป็นช่วง
Config.CriticalMoneySaveThreshold = 50000 -- บันทึกทันทีเมื่อเงินเปลี่ยนแปลงมากกว่าหรือเท่ากับค่านี้
Config.CriticalRareItemDelta = 1 -- บันทึกทันทีเมื่อจำนวนไอเท็มแรร์เปลี่ยนแปลงมากกว่าหรือเท่ากับค่านี้
Config.CriticalSaveCooldownMs = 1500 -- ป้องกันการสั่งบันทึกทันทีถี่เกินไปต่อผู้เล่นหนึ่งคน
Config.ReconnectCooldownMs = 5000 -- บล็อกการรีคอนเน็กต์ถี่เกินไปเพื่อลดความเสี่ยงจากข้อมูลย้อนกลับหรือการ rollback
Config.SyncBatchSize = 8 -- จำนวนผู้เล่นสูงสุดที่ซิงก์ข้อมูลบัญชีและกระเป๋าในหนึ่งรอบ
Config.SyncBatchDelay = 10 -- ระยะหน่วงระหว่างแต่ละชุดซิงก์ หน่วยเป็นมิลลิวินาที
Config.ScopeBatchSize = 64 -- จำนวนผู้เล่นที่ประมวลผลต่อรอบตอนสร้าง scope cache ใหม่
Config.GCStepSize = 2048 -- ขนาดหน่วยความจำ (กิโลไบต์) ที่ให้ collectgarbage("step") ทำงานระหว่างแต่ละชุด; 0 = ปิดใช้งาน
Config.InventorySyncInterval = 750 -- ช่วงเวลาการซิงก์เฉพาะข้อมูลที่เปลี่ยนแปลงของกระเป๋า หน่วยเป็นมิลลิวินาที
Config.InventorySyncRateLimit = 500 -- ระยะห่างขั้นต่ำระหว่างการซิงก์ของผู้เล่นแต่ละคน หน่วยเป็นมิลลิวินาที
Config.InventoryActionRateLimit = 20 -- จำนวนการเปลี่ยนแปลงกระเป๋าสูงสุดของผู้เล่นต่อหนึ่งช่วงเวลาที่กำหนด
Config.InventoryRateWindowMs = 1000 -- ช่วงเวลาสำหรับคำนวณ rate limit ของการเปลี่ยนแปลงกระเป๋า หน่วยเป็นมิลลิวินาที
Config.InventoryRateBlockMs = 3000 -- ระยะเวลาบล็อกชั่วคราวเมื่อมีการยิงคำสั่งเกิน rate limit หน่วยเป็นมิลลิวินาที
Config.InventoryMaxActionCount = 100 -- จำนวนไอเท็มที่อนุญาตให้เพิ่มหรือลดได้สูงสุดต่อหนึ่งคำสั่ง
Config.InventoryMaxSetCount = 10000 -- จำนวนไอเท็มรวมสูงสุดที่ยอมรับได้จากคำสั่ง setInventoryItem
Config.InventoryQueueMaxSize = 128 -- จำนวนคำสั่งกระเป๋าที่รอในคิวได้สูงสุดต่อผู้เล่นหนึ่งคน
Config.InventoryQueueProcessBatchSize = 16 -- จำนวนคำสั่งกระเป๋าสูงสุดที่ประมวลผลต่อหนึ่ง tick ของ worker เพื่อกันอาการกระตุกเวลาเกิด burst
Config.InventoryLogFlushInterval = 500 -- ช่วงเวลาส่ง log กระเป๋าแบบ async ออกจากคิว หน่วยเป็นมิลลิวินาที
Config.InventoryLogBatchSize = 128 -- จำนวน log กระเป๋าแบบ async สูงสุดที่ส่งออกต่อหนึ่งชุด
Config.InventoryLogQueueMaxSize = 512 -- จำนวน log กระเป๋าที่รอคิวได้สูงสุดก่อนเริ่มทิ้งรายการใหม่เพื่อลดการกินหน่วยความจำ
Config.InventoryLogMode = "suspicious" -- โหมดการเก็บ log กระเป๋า: off = ปิด, suspicious = เก็บเฉพาะเหตุผิดปกติ, all = เก็บทุก mutation
Config.InventorySuspicionThreshold = 3 -- ค่าขีดเริ่มต้นสำหรับมองว่าแพทเทิร์นการแก้กระเป๋าน่าสงสัย
Config.LoginQueueInterval = 1000 -- ช่วงเวลาประมวลผลคิวเข้าสู่ระบบ หน่วยเป็นมิลลิวินาที
Config.LoginQueueBatchSize = 4 -- จำนวนผู้เล่นสูงสุดที่ประมวลผลจากคิวต่อรอบ
Config.PaycheckChunkSize = 32 -- จำนวนผู้เล่นที่ประมวลผลต่อหนึ่งชุดของการจ่ายเงินเดือน
Config.PaycheckChunkDelay = 50 -- ระยะเวลาหน่วงระหว่างแต่ละชุดการจ่ายเงินเดือน หน่วยเป็นมิลลิวินาที
-- ลดภาระ CPU ฝั่ง client ด้วยลูปหลักชุดเดียว (ped + vehicle + weapon + pause) ยิ่งค่าสูง resmon ยิ่งต่ำ แต่การตอบสนองอาจช้าลงเล็กน้อย.
Config.ClientActionLoopInterval = 2500
Config.PedLoopInterval = 2500 -- ชื่อคอนฟิกเดิมเพื่อความเข้ากันได้ย้อนหลัง; แนะนำให้ใช้ ClientActionLoopInterval แทน
Config.SlowLoopInterval = 2500
Config.EnablePlayerSyncLookAt = false -- ตัวเลือก NetworkSetLocalPlayerSyncLookAt มีต้นทุนเล็กน้อย; ปิดไว้เพื่อลด resmon ให้ต่ำที่สุด
Config.ClientStatebagCoordsInterval = 8000 -- ช่วงเวลาที่ client ส่งพิกัดเข้า statebag หน่วยเป็นมิลลิวินาที; ค่ายิ่งมาก งาน Lua/native ยิ่งน้อย
Config.ClientStatebagCoordsMinMove = 4.0 -- ผู้เล่นต้องขยับอย่างน้อยกี่เมตรก่อนส่งพิกัดใหม่อีกครั้ง เพื่อลดจำนวนการเขียน statebag
Config.DiscordRichPresence = {
    enabled = true,
    appId = "", -- ถ้าว่างจะ fallback ไปอ่าน convar esx:discordAppId หรือ discord_app_id
    updateInterval = 30000,
    status = {
        text = "Playing on ESX",
        showPlayerName = true,
        showPlayerId = true,
        showJob = true,
    },
    assets = {
        large = {
            key = "",
            text = "ESX Legacy",
        },
        small = {
            key = "",
            text = "",
        }
    },
    buttons = {
        -- { label = "Join Discord", url = "https://discord.gg/yourserver" },
        -- { label = "Connect", url = "fivem://connect/127.0.0.1:30120" },
    }
}
Config.PlayerScopeBucketSize = 128.0 -- ขนาดพื้นที่ของ bucket ที่ใช้แบ่ง scope ผู้เล่น
Config.ScopeDirtyFlushInterval = 250 -- ช่วงเวลาประมวลผลงาน scope incremental ที่ค้างอยู่ หน่วยเป็นมิลลิวินาที
Config.PlayerScopeRefreshInterval = 2000 -- ค่าความเข้ากันได้ย้อนหลังสำหรับโหมด fallback ที่ยังใช้ลูปรีเฟรช scope แบบเดิม
Config.PlayerScopeFullRefreshInterval = 15000 -- ช่วงเวลาสแกน scope ทั้งระบบเพื่อซ่อมข้อมูลตกหล่น หน่วยเป็นมิลลิวินาที
Config.ScopeDirtyBatchSize = 128 -- จำนวนผู้เล่นสูงสุดที่อัปเดต scope แบบ incremental ต่อหนึ่งรอบ
Config.UseClientStatebagCoords = true -- ให้ client ส่งพิกัดเข้า statebag โดยตรง และไม่ต้องมีลูปอ่านตำแหน่งฝั่งเซิร์ฟเวอร์ เหมาะกับเซิร์ฟเวอร์คนเยอะ
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
