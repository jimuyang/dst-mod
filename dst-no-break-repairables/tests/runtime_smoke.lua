local API = NO_BREAK_REPAIRABLES_API
local passed = 0
local failed = 0

local function Check(condition, message)
    if condition then
        passed = passed + 1
        print("[NBR TEST] PASS: " .. message)
    else
        failed = failed + 1
        print("[NBR TEST] FAIL: " .. message)
    end
end

local function IsBroken(inst)
    return inst:IsValid() and inst:HasTag(API.broken_item_tag)
end

local function Cleanup(inst)
    if inst ~= nil and inst:IsValid() then
        inst:Remove()
    end
end

local function TestYellowAmulet()
    local owner = GLOBAL.SpawnPrefab("wilson")
    local item = GLOBAL.SpawnPrefab("yellowamulet")
    owner.components.inventory:Equip(item)
    item.components.fueled:MakeEmpty()

    Check(item:IsValid(), "yellowamulet survives depletion")
    Check(IsBroken(item), "yellowamulet enters broken state")
    Check(not item.components.equippable:IsEquipped(), "yellowamulet is force-unequipped")
    Check(item.components.equippable.restrictedtag == API.broken_equip_restriction,
        "yellowamulet cannot be equipped while broken")
    owner.components.inventory:Equip(item)
    Check(not item.components.equippable:IsEquipped(),
        "yellowamulet rejects an actual equip attempt while broken")

    local fuel = GLOBAL.SpawnPrefab("nightmarefuel")
    item.components.fueled:TakeFuelItem(fuel)
    Check(item.components.fueled:GetPercent() > 0, "yellowamulet accepts nightmare fuel at zero")
    Check(not IsBroken(item), "yellowamulet leaves broken state after refueling")

    Cleanup(item)
    Cleanup(owner)
end

local function TestFedArmor(prefab)
    local owner = GLOBAL.SpawnPrefab("wilson")
    local item = GLOBAL.SpawnPrefab(prefab)
    local original_absorption = item.components.armor.absorb_percent
    owner.components.inventory:Equip(item)
    item.components.armor:SetCondition(0)

    Check(item:IsValid(), prefab .. " survives zero armor")
    Check(IsBroken(item), prefab .. " enters broken state")
    Check(item.components.armor.absorb_percent == 0, prefab .. " has no absorption while broken")
    Check(not item.components.equippable:IsEquipped(), prefab .. " is force-unequipped")
    owner.components.inventory:Equip(item)
    Check(not item.components.equippable:IsEquipped(), prefab .. " rejects equip while broken")

    local food = GLOBAL.SpawnPrefab("berries")
    local ate = item.components.eater:Eat(food)
    Check(ate == true and item.components.armor:GetPercent() > 0, prefab .. " is repaired by feeding")
    Check(not IsBroken(item), prefab .. " leaves broken state after feeding")
    Check(item.components.armor.absorb_percent == original_absorption,
        prefab .. " restores its original absorption")

    Cleanup(food)
    Cleanup(item)
    Cleanup(owner)
end

local function TestFiniteUses()
    local owner = GLOBAL.SpawnPrefab("wilson")
    local item = GLOBAL.SpawnPrefab("orangeamulet")
    owner.components.inventory:Equip(item)
    item.components.finiteuses:SetUses(0)
    Check(item:IsValid() and IsBroken(item), "repairable finiteuses item survives depletion")
    Check(not item.components.equippable:IsEquipped(),
        "repairable finiteuses item is force-unequipped")
    owner.components.inventory:Equip(item)
    Check(not item.components.equippable:IsEquipped(),
        "repairable finiteuses item rejects equip while broken")

    local repair_item = GLOBAL.SpawnPrefab("nightmarefuel")
    local repaired = item.components.repairable:Repair(nil, repair_item)
    Check(repaired == true and item.components.finiteuses:GetPercent() > 0,
        "repairable finiteuses item accepts its repair material at zero")
    Check(not IsBroken(item), "repairable finiteuses item leaves broken state after repair")
    owner.components.inventory:Equip(item)
    Check(item.components.equippable:IsEquipped(),
        "repairable finiteuses item can be equipped after repair")
    Cleanup(repair_item)
    Cleanup(item)
    Cleanup(owner)

    local control = GLOBAL.SpawnPrefab("greenamulet")
    Check(API.get_state(control) == nil, "non-repairable finiteuses item is not intercepted")
    control.components.finiteuses:SetUses(0)
    Check(not control:IsValid(), "non-repairable finiteuses item keeps vanilla removal behavior")
    Cleanup(control)
end

local function TestFueled()
    local direct_owner = GLOBAL.SpawnPrefab("wilson")
    local direct = GLOBAL.SpawnPrefab("raincoat")
    direct_owner.components.inventory:Equip(direct)
    direct.components.fueled:MakeEmpty()
    Check(direct:IsValid() and IsBroken(direct), "sewable fueled item survives depletion")
    Check(direct:HasTag("needssewing"), "zero fueled item remains sewing-compatible")
    Check(not direct.components.equippable:IsEquipped(),
        "sewable fueled item is force-unequipped")
    direct_owner.components.inventory:Equip(direct)
    Check(not direct.components.equippable:IsEquipped(),
        "sewable fueled item rejects equip while broken")
    local direct_kit = GLOBAL.SpawnPrefab("sewing_kit")
    local direct_sewn = direct_kit.components.sewing:DoSewing(direct, direct_owner)
    Check(direct_sewn == true and not IsBroken(direct),
        "sewable fueled item recovers through actual sewing")
    Cleanup(direct_kit)
    Cleanup(direct)
    Cleanup(direct_owner)

    local custom_owner = GLOBAL.SpawnPrefab("wilson")
    local custom = GLOBAL.SpawnPrefab("umbrella")
    local spare = GLOBAL.SpawnPrefab("umbrella")
    custom_owner.components.inventory:GiveItem(spare)
    custom_owner.components.inventory:Equip(custom)
    custom.components.fueled:MakeEmpty()
    Check(custom:IsValid() and IsBroken(custom), "custom-depletion sewable item survives depletion")
    Check(custom_owner.components.inventory:GetEquippedItem(GLOBAL.EQUIPSLOTS.HANDS) == spare,
        "depleted umbrella preserves vanilla spare auto-equip")
    local custom_kit = GLOBAL.SpawnPrefab("sewing_kit")
    local custom_sewn = custom_kit.components.sewing:DoSewing(custom, custom_owner)
    Check(custom_sewn == true and not IsBroken(custom),
        "custom-depletion sewable item recovers through actual sewing")
    Cleanup(custom_kit)
    Cleanup(custom)
    Cleanup(spare)
    Cleanup(custom_owner)

    local delayed_owner = GLOBAL.SpawnPrefab("wilson")
    local delayed = GLOBAL.SpawnPrefab("bernie_inactive")
    delayed.components.fueled:MakeEmpty()
    Check(delayed:IsValid() and IsBroken(delayed), "delayed-decay repairable item survives depletion")
    Check(delayed._decaytask == nil, "broken Bernie decay removal is cancelled")
    delayed:PushEvent("ondropped")
    Check(delayed._decaytask == nil, "broken Bernie remains persistent after being dropped")
    local delayed_kit = GLOBAL.SpawnPrefab("sewing_kit")
    local delayed_sewn = delayed_kit.components.sewing:DoSewing(delayed, delayed_owner)
    Check(delayed_sewn == true and not IsBroken(delayed),
        "broken Bernie recovers through actual sewing")
    Cleanup(delayed_kit)
    Cleanup(delayed)
    Cleanup(delayed_owner)

    local control = GLOBAL.SpawnPrefab("walking_stick")
    Check(API.get_state(control) == nil, "no_sewing fueled item is not intercepted")
    control.components.fueled:MakeEmpty()
    Check(not control:IsValid(), "no_sewing fueled item keeps vanilla removal behavior")
    Cleanup(control)
end

local function TestHealthySpareFallback()
    local armor_owner = GLOBAL.SpawnPrefab("wilson")
    local old_armor = GLOBAL.SpawnPrefab("shieldofterror")
    local spare_armor = GLOBAL.SpawnPrefab("shieldofterror")
    local current_armor = GLOBAL.SpawnPrefab("shieldofterror")
    old_armor.components.armor:SetCondition(0)
    Check(IsBroken(old_armor), "older depleted armor is marked broken")
    armor_owner.components.inventory:GiveItem(old_armor)
    armor_owner.components.inventory:GiveItem(spare_armor)
    armor_owner.components.inventory:Equip(current_armor)
    current_armor.components.armor:SetCondition(0)
    Check(armor_owner.components.inventory:GetEquippedItem(GLOBAL.EQUIPSLOTS.HANDS) == spare_armor,
        "older broken armor does not block healthy spare auto-equip")
    Cleanup(old_armor)
    Cleanup(spare_armor)
    Cleanup(current_armor)
    Cleanup(armor_owner)

    local umbrella_owner = GLOBAL.SpawnPrefab("wilson")
    local old_umbrella = GLOBAL.SpawnPrefab("umbrella")
    local spare_umbrella = GLOBAL.SpawnPrefab("umbrella")
    local current_umbrella = GLOBAL.SpawnPrefab("umbrella")
    old_umbrella.components.fueled:MakeEmpty()
    Check(IsBroken(old_umbrella), "older depleted umbrella is marked broken")
    umbrella_owner.components.inventory:GiveItem(old_umbrella)
    umbrella_owner.components.inventory:GiveItem(spare_umbrella)
    umbrella_owner.components.inventory:Equip(current_umbrella)
    current_umbrella.components.fueled:MakeEmpty()
    Check(umbrella_owner.components.inventory:GetEquippedItem(GLOBAL.EQUIPSLOTS.HANDS)
            == spare_umbrella,
        "older broken umbrella does not block healthy spare auto-equip")
    Cleanup(old_umbrella)
    Cleanup(spare_umbrella)
    Cleanup(current_umbrella)
    Cleanup(umbrella_owner)
end

local function TestDreadstone(done)
    local owner = GLOBAL.SpawnPrefab("wilson")
    local item = GLOBAL.SpawnPrefab("dreadstonehat")
    local body = GLOBAL.SpawnPrefab("armordreadstone")
    local original_absorption = item.components.armor.absorb_percent
    local original_body_absorption = body.components.armor.absorb_percent
    owner.components.sanity:SetPercent(0)
    owner.components.inventory:Equip(item)
    item.components.armor:SetCondition(0)
    Check(item:IsValid() and IsBroken(item), "dreadstonehat survives zero armor")
    Check(item.components.armor.absorb_percent == 0, "dreadstonehat has no absorption at zero")
    Check(not item.components.equippable:IsEquipped(), "dreadstonehat is force-unequipped at zero")
    Check(item.components.equippable.restrictedtag == API.broken_equip_restriction,
        "dreadstonehat cannot retain secondary equipped effects at zero")

    owner.components.inventory:Equip(body)
    body.components.armor:SetCondition(0)
    Check(body:IsValid() and IsBroken(body), "armordreadstone survives zero armor")
    Check(body.components.armor.absorb_percent == 0, "armordreadstone has no absorption at zero")
    Check(not body.components.equippable:IsEquipped(), "armordreadstone is force-unequipped at zero")
    Check(body.components.equippable.restrictedtag == API.broken_equip_restriction,
        "armordreadstone cannot retain secondary equipped effects at zero")

    GLOBAL.TheWorld:DoTaskInTime(GLOBAL.TUNING.ARMOR_DREADSTONE_REGEN_PERIOD + 0.2, function()
        Check(item.components.armor:GetPercent() > 0,
            "dreadstonehat broken-state bridge starts insanity self-repair")
        Check(not IsBroken(item) and item.components.armor.absorb_percent == original_absorption,
            "dreadstonehat restores equip permission and absorption after self-repair")
        Check(API.get_state(item).self_repair_task == nil,
            "dreadstonehat stops its broken-state repair task after recovery")
        Check(body.components.armor:GetPercent() > 0,
            "armordreadstone broken-state bridge starts insanity self-repair")
        Check(not IsBroken(body) and body.components.armor.absorb_percent == original_body_absorption,
            "armordreadstone restores equip permission and absorption after self-repair")
        Check(API.get_state(body).self_repair_task == nil,
            "armordreadstone stops its broken-state repair task after recovery")
        Cleanup(item)
        Cleanup(body)
        Cleanup(owner)

        local control = GLOBAL.SpawnPrefab("footballhat")
        Check(API.get_state(control) == nil, "non-repairable armor is not intercepted")
        control.components.armor:SetCondition(0)
        Check(not control:IsValid(), "non-repairable armor keeps vanilla removal behavior")
        Cleanup(control)
        done()
    end)
end

local function Run()
    print("[NBR TEST] BEGIN")
    TestYellowAmulet()
    TestFedArmor("shieldofterror")
    TestFedArmor("eyemaskhat")
    TestFiniteUses()
    TestFueled()
    TestHealthySpareFallback()
    TestDreadstone(function()
        print(string.format("[NBR TEST] RESULT: passed=%d failed=%d", passed, failed))
        if failed > 0 then
            error(string.format("NBR runtime tests failed: %d", failed))
        end
    end)
end

AddSimPostInit(function()
    if GLOBAL.TheWorld ~= nil and GLOBAL.TheWorld.ismastersim then
        GLOBAL.TheWorld:DoTaskInTime(1, Run)
    end
end)
