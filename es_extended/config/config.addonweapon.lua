Config.AddonWeapons = Config.AddonWeapons or {
    --[[
    ============================================================================
    คู่มือการเพิ่มอาวุธเสริม / Custom Weapons
    ============================================================================

    วิธีใช้งาน
    1) เพิ่มอาวุธใหม่เป็น key ของตารางนี้ โดยใช้ชื่อแบบ GTA weapon name เช่น
       WEAPON_GLOCK, WEAPON_AK74, WEAPON_CUSTOMRPG
    2) ระบบจะ merge Config.AddonWeapons เข้า Config.Weapons อัตโนมัติ
    3) ถ้าชื่อซ้ำกับอาวุธเดิมใน config.weapons.lua ค่าในไฟล์นี้จะ override ตัวเดิม
    4) สามารถลงทะเบียนระหว่าง runtime ได้ด้วย export RegisterWeapon เช่น
       exports["es_extended"]:RegisterWeapon("WEAPON_GLOCK", data)

    Weapon addon กับ weapon component ต่างกันยังไง
    - weapon addon = "ตัวอาวุธ" ใหม่ 1 รายการใน Config.Weapons
      ตัวอย่าง: WEAPON_GLOCK, WEAPON_AK74, WEAPON_CUSTOMRPG
      ใช้กำหนด label, ammo, maxAmmo, type, tints และรายการ component ที่อาวุธนั้นรองรับ
    - weapon component = "ของแต่ง/อุปกรณ์เสริม" ที่ติดตั้งบนอาวุธ 1 กระบอก
      ตัวอย่าง: suppressor, flashlight, extended clip, scope
      component ต้องอยู่ใน field `components` ของอาวุธนั้น ไม่ได้ประกาศเป็นอาวุธใหม่แยกต่างหาก
    - สรุปง่าย ๆ:
      ถ้าของนั้นผู้เล่น "ถือเป็นอาวุธได้เลย" => ใส่ใน AddonWeapons
      ถ้าของนั้น "ต้องติดกับอาวุธอีกที" => ใส่เป็น component ของอาวุธ

    ฟิลด์ที่ปรับแต่งได้ทั้งหมด
    - label: string
        ชื่อที่แสดงผลใน inventory / loadout / pickup

    - type: string
        ประเภทอาวุธที่ระบบใช้คำนวณค่า default และ anti-cheat tuning
        ค่าที่แนะนำในระบบปัจจุบัน:
        melee, pistol, smg, rifle, shotgun, sniper, launcher,
        throwable, utility, heavy, unknown

    - ammo: table | nil
        ข้อมูลชนิดกระสุน
        รูปแบบ: { label = "ชื่อกระสุน", hash = `AMMO_PISTOL` }
        สำหรับ melee บางชนิดไม่จำเป็นต้องใส่

    - maxAmmo: number | nil
        จำนวนกระสุนสูงสุด ถ้าไม่ใส่จะ fallback จาก ammo/type defaults

    - throwable: boolean | nil
        ใช้ระบุว่าอาวุธนี้เป็นของขว้าง ถ้า true ระบบจะ infer type เป็น throwable

    - tints: table | nil
        ตารางสีอาวุธ เช่น Config.DefaultWeaponTints หรือ Config.MK2WeaponTints

    - components: table
        รายการ components ที่ "อาวุธกระบอกนี้รองรับ" เช่น กล้อง, แม็ก, suppressor
        รูปแบบควรเหมือน config.weapons.lua:
        {
            { name = "clip_extended", label = TranslateCap("component_clip_extended"), hash = `COMPONENT_PISTOL_CLIP_02` },
            { name = "suppressor", label = TranslateCap("component_suppressor"), hash = `COMPONENT_AT_PI_SUPP` },
        }
        ค่าเริ่มต้นควรเป็น {} ถ้ายังไม่มี component

        หมายเหตุ:
        - ตรงนี้คือ "metadata ของ component ที่ติดได้" ไม่ใช่ component ที่ผู้เล่นติดอยู่ตอนนี้
        - component ที่ติดตั้งจริงใน loadout/player data จะถูกเก็บเป็น list ของชื่อ component
          เช่น { "clip_extended", "suppressor" }

    - minFireInterval: number | nil
        ระยะขั้นต่ำระหว่างการยิงแต่ละนัด (ms) ใช้ในระบบตรวจจับพฤติกรรมการยิง

    - maxRange: number | nil
        ระยะยิงสูงสุดที่คาดหวัง

    - minDamage: number | nil
    - maxDamage: number | nil
        กรอบความเสียหายที่ระบบยอมรับสำหรับอาวุธประเภทนี้

    - spreadTolerance: number | nil
    - recoilTolerance: number | nil
        ค่าความคลาดเคลื่อน/แรงดีดที่ระบบใช้ยอมรับได้

    หมายเหตุสำคัญ
    - ถ้าไม่ใส่ type ระบบจะพยายามเดาจากชื่ออาวุธหรือ ammo hash
    - ถ้าไม่ใส่ maxAmmo ระบบจะใช้ ammo defaults หรือ type defaults ให้
    - แนะนำให้ใส่ type ให้ชัดเสมอสำหรับอาวุธ custom เพื่อให้ tuning แม่นที่สุด
    - ถ้าเป็นอาวุธใช้น้ำมัน/แรงดัน/charge ให้ใช้ type = "utility"
    - ถ้าเป็นของขว้าง ให้ตั้ง throwable = true และระบุ ammo hash ให้ตรงชนิด

    ============================================================================
    ตัวอย่างครบทุกหมวด
    ============================================================================

    -- 1) Unknown / ใช้สำหรับ prototype หรืออาวุธที่ไม่ต้องการ tuning เฉพาะ
    WEAPON_PROTOTYPE = {
        label = "Prototype Weapon",
        type = "unknown",
        maxAmmo = 120,
        components = {},
        minFireInterval = 120,
        maxRange = 120.0,
        minDamage = 0,
        maxDamage = 75,
        spreadTolerance = 0.0035,
        recoilTolerance = 8.0,
    },

    -- 2) Melee
    WEAPON_KATANA = {
        label = "Katana",
        type = "melee",
        components = {},
        minFireInterval = 300,
        maxRange = 3.0,
        minDamage = 15,
        maxDamage = 75,
        spreadTolerance = 0.0,
        recoilTolerance = 0.0,
    },

    -- 3) Pistol
    WEAPON_GLOCK = {
        label = "Glock 17",
        type = "pistol",
        ammo = { label = TranslateCap("ammo_rounds"), hash = `AMMO_PISTOL` },
        maxAmmo = 250,
        tints = Config.DefaultWeaponTints,
        components = {
            { name = "suppressor", label = TranslateCap("component_suppressor"), hash = `COMPONENT_AT_PI_SUPP` },
            { name = "clip_extended", label = TranslateCap("component_clip_extended"), hash = `COMPONENT_PISTOL_CLIP_02` },
        },
        minFireInterval = 105,
        maxRange = 95.0,
        minDamage = 1,
        maxDamage = 55,
        spreadTolerance = 0.0030,
        recoilTolerance = 7.0,
    },

    -- 4) SMG
    WEAPON_VECTOR = {
        label = "KRISS Vector",
        type = "smg",
        ammo = { label = TranslateCap("ammo_rounds"), hash = `AMMO_SMG` },
        maxAmmo = 500,
        tints = Config.DefaultWeaponTints,
        components = {
            { name = "scope_small", label = TranslateCap("component_scope_small"), hash = `COMPONENT_AT_SCOPE_MACRO` },
            { name = "suppressor", label = TranslateCap("component_suppressor"), hash = `COMPONENT_AT_AR_SUPP_02` },
        },
    },

    -- 5) Rifle
    WEAPON_AK74 = {
        label = "AK-74",
        type = "rifle",
        ammo = { label = TranslateCap("ammo_rounds"), hash = `AMMO_RIFLE` },
        maxAmmo = 500,
        tints = Config.DefaultWeaponTints,
        components = {
            { name = "scope_medium", label = TranslateCap("component_scope_medium"), hash = `COMPONENT_AT_SCOPE_MEDIUM` },
            { name = "suppressor", label = TranslateCap("component_suppressor"), hash = `COMPONENT_AT_AR_SUPP` },
        },
        maxRange = 190.0,
        recoilTolerance = 9.5,
    },

    -- 6) Shotgun
    WEAPON_BENELLI = {
        label = "Benelli M4",
        type = "shotgun",
        ammo = { label = TranslateCap("ammo_shells"), hash = `AMMO_SHOTGUN` },
        maxAmmo = 120,
        tints = Config.DefaultWeaponTints,
        components = {},
        maxRange = 45.0,
        maxDamage = 125,
    },

    -- 7) Sniper
    WEAPON_AWP = {
        label = "AWP",
        type = "sniper",
        ammo = { label = TranslateCap("ammo_rounds"), hash = `AMMO_SNIPER` },
        maxAmmo = 50,
        tints = Config.DefaultWeaponTints,
        components = {
            { name = "scope_large", label = TranslateCap("component_scope_large"), hash = `COMPONENT_AT_SCOPE_MAX` },
        },
        minFireInterval = 950,
        maxRange = 500.0,
        maxDamage = 170,
    },

    -- 8) Launcher
    WEAPON_CUSTOMRPG = {
        label = "Custom RPG",
        type = "launcher",
        ammo = { label = TranslateCap("ammo_rockets"), hash = `AMMO_RPG` },
        maxAmmo = 20,
        components = {},
        minFireInterval = 850,
        maxRange = 360.0,
        maxDamage = 260,
    },

    -- 9) Throwable
    WEAPON_CUSTOMGRENADE = {
        label = "Custom Grenade",
        throwable = true,
        ammo = { label = TranslateCap("ammo_grenade"), hash = `AMMO_GRENADE` },
        maxAmmo = 25,
        components = {},
        minFireInterval = 500,
        maxRange = 60.0,
        minDamage = 5,
        maxDamage = 150,
        spreadTolerance = 0.0080,
        recoilTolerance = 6.0,
    },

    -- 10) Utility
    WEAPON_CUSTOMEXTINGUISHER = {
        label = "Custom Extinguisher",
        type = "utility",
        ammo = { label = TranslateCap("ammo_charge"), hash = `AMMO_FIREEXTINGUISHER` },
        maxAmmo = 4500,
        components = {},
        minFireInterval = 150,
        maxRange = 25.0,
        minDamage = 0,
        maxDamage = 10,
        spreadTolerance = 0.0,
        recoilTolerance = 0.0,
    },

    -- 11) Heavy
    WEAPON_CUSTOMMINIGUN = {
        label = "Custom Minigun",
        type = "heavy",
        ammo = { label = TranslateCap("ammo_rounds"), hash = `AMMO_MINIGUN` },
        maxAmmo = 9999,
        tints = Config.DefaultWeaponTints,
        components = {},
        minFireInterval = 55,
        maxRange = 220.0,
        maxDamage = 90,
    },

    ============================================================================
    หมายเหตุเรื่อง ammo hash ที่ใช้บ่อย
    ============================================================================
    Pistol      -> `AMMO_PISTOL`
    SMG         -> `AMMO_SMG`
    Rifle       -> `AMMO_RIFLE`
    Shotgun     -> `AMMO_SHOTGUN`
    Sniper      -> `AMMO_SNIPER`
    Launcher    -> `AMMO_RPG`, `AMMO_GRENADELAUNCHER`, `AMMO_HOMINGLAUNCHER`
    Heavy       -> `AMMO_MINIGUN`, `AMMO_RAILGUN`
    Throwable   -> `AMMO_GRENADE`, `AMMO_MOLOTOV`, `AMMO_STICKYBOMB`, ฯลฯ
    Utility     -> `AMMO_FIREEXTINGUISHER`, `AMMO_PETROLCAN`

    ถ้าคุณต้องการใช้งานจริง ให้เอาบล็อกตัวอย่างที่ต้องการออกจาก comment นี้
    แล้ววางเป็น key จริงในตาราง Config.AddonWeapons ด้านล่างหรือแทนที่ตารางนี้ได้เลย
    ]]
}
