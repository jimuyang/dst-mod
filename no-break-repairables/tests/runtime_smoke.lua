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

local function TestRepairThreshold()
    for _, prefab in ipairs({ "eyemaskhat", "orangeamulet", "yellowamulet" }) do
        local owner = GLOBAL.SpawnPrefab("wilson")
        local item = GLOBAL.SpawnPrefab(prefab)
        local durability = item.components[API.get_state(item).kind]
        durability:SetPercent(0.005)
        owner.components.inventory:Equip(item)
        Check(not IsBroken(item) and item.components.equippable:IsEquipped(),
            prefab .. " remains usable below 1% until depleted")

        durability:SetPercent(0)
        for _, percent in ipairs({ 0.005, 0.01 }) do
            durability:SetPercent(percent)
            Check(IsBroken(item), prefab .. " stays broken after repair to " .. percent)
            owner.components.inventory:Equip(item)
            Check(not item.components.equippable:IsEquipped(),
                prefab .. " rejects equip at repair percent " .. percent)
        end

        durability:SetPercent(0.0101)
        Check(not IsBroken(item), prefab .. " recovers only above 1%")
        owner.components.inventory:Equip(item)
        Check(item.components.equippable:IsEquipped(), prefab .. " equips after recovery above 1%")
        Cleanup(item)
        Cleanup(owner)
    end
end

local function TestPartialRepairReload(done)
    local records = {}
    for _, prefab in ipairs({ "eyemaskhat", "orangeamulet", "yellowamulet" }) do
        for _, broken in ipairs({ false, true }) do
            local item = GLOBAL.SpawnPrefab(prefab)
            local durability = item.components[API.get_state(item).kind]
            if broken then
                durability:SetPercent(0)
            end
            durability:SetPercent(0.005)
            local record = item:GetSaveRecord()
            Check((record.data ~= nil and record.data.no_break_repairables_broken == true) == broken,
                prefab .. " saves broken=" .. tostring(broken) .. " after a partial repair")
            local restored = GLOBAL.SpawnSaveRecord(record)
            records[#records + 1] = { item = restored, broken = broken, prefab = prefab }
            Cleanup(item)
        end
    end

    -- Zero-delay entity load tasks are unordered within a scheduler tick.
    GLOBAL.TheWorld:DoTaskInTime(2 * GLOBAL.FRAMES, function()
        for _, record in ipairs(records) do
            local item = record.item
            local owner = GLOBAL.SpawnPrefab("wilson")
            local durability = item.components[API.get_state(item).kind]
            Check(math.abs(durability:GetPercent() - 0.005) < 0.000001,
                record.prefab .. " preserves partial durability across save/load")
            Check(IsBroken(item) == record.broken,
                record.prefab .. " restores broken=" .. tostring(record.broken) .. " across save/load")
            owner.components.inventory:Equip(item)
            Check(item.components.equippable:IsEquipped() == not record.broken,
                record.prefab .. " preserves equip permission across save/load")
            durability:SetPercent(0.02)
            Check(not IsBroken(item), record.prefab .. " can recover after save/load")
            local saved = item:GetSaveRecord()
            Check(saved.data == nil or saved.data.no_break_repairables_broken ~= true,
                record.prefab .. " clears saved broken state after recovery")
            Cleanup(item)
            Cleanup(owner)
        end
        done()
    end)
end

local function TestDreadstone(done)
    local low_sanity_owner = GLOBAL.SpawnPrefab("wilson")
    local full_sanity_owner = GLOBAL.SpawnPrefab("wilson")
    low_sanity_owner.components.sanity:SetPercent(0)
    full_sanity_owner.components.sanity:SetPercent(1)
    local spare = GLOBAL.SpawnPrefab("dreadstonehat")
    low_sanity_owner.components.inventory:GiveItem(spare)

    local records =
    {
        { prefab = "dreadstonehat", owner = low_sanity_owner },
        { prefab = "armordreadstone", owner = low_sanity_owner },
        { prefab = "dreadstonehat", owner = full_sanity_owner },
    }
    for _, record in ipairs(records) do
        local item = GLOBAL.SpawnPrefab(record.prefab)
        record.item = item
        record.absorption = item.components.armor.absorb_percent
        record.owner.components.inventory:Equip(item)
        item.components.armor:SetCondition(0)
        Check(item:IsValid() and IsBroken(item), record.prefab .. " survives zero armor")
        Check(item.components.armor.absorb_percent == 0, record.prefab .. " has no absorption at zero")
        Check(not item.components.equippable:IsEquipped(), record.prefab .. " is force-unequipped")
    end
    Check(low_sanity_owner.components.inventory:GetEquippedItem(GLOBAL.EQUIPSLOTS.HEAD) == spare,
        "depleted dreadstonehat automatically equips a healthy spare")

    local period = GLOBAL.TUNING.ARMOR_DREADSTONE_REGEN_PERIOD
    GLOBAL.TheWorld:DoTaskInTime(period + 0.2, function()
        for _, record in ipairs(records) do
            local item = record.item
            local percent = item.components.armor:GetPercent()
            Check(percent > 0 and percent <= 0.01 and IsBroken(item),
                record.prefab .. " remains broken after its first repair tick")
            Check(item.components.armor.absorb_percent == 0,
                record.prefab .. " has no absorption during partial repair")
            Check(API.get_state(item).self_repair_task ~= nil,
                record.prefab .. " keeps repairing until above 1%")
            record.owner.components.inventory:Equip(item)
            Check(not item.components.equippable:IsEquipped(),
                record.prefab .. " rejects equip after its first repair tick")
        end
    end)

    local ticks = math.floor(0.01 / GLOBAL.TUNING.ARMOR_DREADSTONE_REGEN_MINRATE) + 2
    GLOBAL.TheWorld:DoTaskInTime(period * ticks + 0.2, function()
        Check(low_sanity_owner.components.inventory:GetEquippedItem(GLOBAL.EQUIPSLOTS.HEAD) == spare,
            "repaired dreadstonehat does not replace the equipped spare automatically")
        for _, record in ipairs(records) do
            local item = record.item
            Check(item.components.armor:GetPercent() > 0.01 and not IsBroken(item),
                record.prefab .. " self-repairs past 1% in normal sanity mode")
            Check(item.components.armor.absorb_percent == record.absorption,
                record.prefab .. " restores absorption after recovery")
            Check(API.get_state(item).self_repair_task == nil,
                record.prefab .. " stops broken-state repair after recovery")
            record.owner.components.inventory:Equip(item)
            Check(item.components.equippable:IsEquipped(),
                record.prefab .. " can be equipped again above 1%")
            Cleanup(item)
        end
        Cleanup(spare)
        Cleanup(low_sanity_owner)
        Cleanup(full_sanity_owner)

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
    TestRepairThreshold()
    TestPartialRepairReload(function()
        TestDreadstone(function()
            print(string.format("[NBR TEST] RESULT: passed=%d failed=%d", passed, failed))
            if failed > 0 then
                error(string.format("NBR runtime tests failed: %d", failed))
            end
        end)
    end)
end

AddSimPostInit(function()
    if GLOBAL.TheWorld ~= nil and GLOBAL.TheWorld.ismastersim then
        GLOBAL.TheWorld:DoTaskInTime(1, Run)
    end
end)
