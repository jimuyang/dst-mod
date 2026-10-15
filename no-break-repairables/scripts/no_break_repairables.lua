local FUELTYPE = GLOBAL.FUELTYPE
local REPAIR_THRESHOLD = 0.01

local BROKEN_ITEM_TAG = "no_break_repairables_broken"
local BROKEN_EQUIP_RESTRICTION = "no_break_repairables_can_equip_broken"

-- Armor has no generic repair marker. Keep this list limited to vanilla armor
-- with a verified repair path.
local REPAIRABLE_ARMOR =
{
    shieldofterror = "feed",
    eyemaskhat = "feed",
    dreadstonehat = "self_repair",
    armordreadstone = "self_repair",
}

-- These vanilla fueled items use a custom depleted callback which ultimately
-- removes the item. Their normal onunequip callback already performs the
-- required effect cleanup, so the broken handler can safely replace it.
local CUSTOM_FUELED_REMOVERS =
{
    beargervest = true,
    umbrella = true,
    eyebrellahat = true,
    molehat = true,
    polly_rogershat = true,
    salty_doghat = true,
}

local UMBRELLA_REMOVERS =
{
    umbrella = true,
    eyebrellahat = true,
}

local PERSISTENT_BROKEN_FUELED =
{
    -- Bernie already has a visual broken state, but when left on the ground it
    -- starts a delayed decay task that ultimately removes the repairable item.
    bernie_inactive = true,
}

local function GetState(inst)
    return inst._no_break_repairables_state
end

local function GetDurabilityPercent(inst, kind)
    local component = inst.components[kind]
    return component ~= nil and component:GetPercent() or nil
end

local function EquipHealthySpare(inventory, inst, state, equipslot)
    if inventory:GetEquippedItem(equipslot) ~= nil then
        return
    end

    local spare = nil
    if state.kind == "armor" then
        spare = inventory:FindItem(function(candidate)
            return candidate.prefab == inst.prefab
                and not candidate:HasTag(BROKEN_ITEM_TAG)
                and candidate.components.equippable ~= nil
        end)
    elseif state.push_umbrella_ranout then
        spare = inventory:FindItem(function(candidate)
            return candidate:HasTag("umbrella")
                and not candidate:HasTag(BROKEN_ITEM_TAG)
                and candidate.components.equippable ~= nil
                and candidate.components.equippable.equipslot == equipslot
        end)
    end

    if spare ~= nil then
        inventory:Equip(spare)
    end
end

local function ForceUnequip(inst)
    local equippable = inst.components.equippable
    local inventoryitem = inst.components.inventoryitem
    if equippable == nil or inventoryitem == nil or not equippable:IsEquipped() then
        return
    end

    local owner = inventoryitem:GetGrandOwner()
    local inventory = owner ~= nil and owner.components.inventory or nil
    if inventory == nil then
        return
    end

    local item = inventory:Unequip(equippable.equipslot, nil, true)
    if item ~= nil and item:IsValid() then
        local state = GetState(inst)
        if state ~= nil and state.push_umbrella_ranout then
            -- Match the vanilla umbrella callback while keeping the broken
            -- umbrella out of the inventory search until a spare is equipped.
            owner:PushEvent("umbrellaranout",
            {
                prefab = inst.prefab,
                equipslot = equippable.equipslot,
            })
        end
        -- Vanilla replacement handlers only try the first matching inventory
        -- item. Retry while excluding an older broken item that blocked them.
        EquipHealthySpare(inventory, inst, state, equippable.equipslot)
        inventory:GiveItem(item, nil, owner:GetPosition())
    end
end

local function CancelDelayedRemoval(inst)
    local state = GetState(inst)
    local fueled = inst.components.fueled
    if state ~= nil and state.broken and state.cancel_decay
            and fueled ~= nil and fueled:IsEmpty() and inst._decaytask ~= nil then
        inst._decaytask:Cancel()
        inst._decaytask = nil
    end
end

local function OnProtectedItemDropped(inst)
    CancelDelayedRemoval(inst)
    -- Keep this robust if another ondropped listener is registered after ours.
    inst:DoTaskInTime(0, CancelDelayedRemoval)
end

local function StopBrokenSelfRepair(state)
    if state.self_repair_task ~= nil then
        state.self_repair_task:Cancel()
        state.self_repair_task = nil
    end
end

local function DoBrokenSelfRepair(inst)
    local state = GetState(inst)
    local armor = inst.components.armor
    local inventoryitem = inst.components.inventoryitem
    if state == nil or not state.broken or armor == nil or inventoryitem == nil then
        if state ~= nil then
            StopBrokenSelfRepair(state)
        end
        return
    end

    local owner = inventoryitem:GetGrandOwner()
    local sanity = owner ~= nil and owner.components.sanity or nil
    if sanity ~= nil and sanity:IsInsanityMode() then
        local rate = 1 / GLOBAL.Lerp(
            1 / GLOBAL.TUNING.ARMOR_DREADSTONE_REGEN_MAXRATE,
            1 / GLOBAL.TUNING.ARMOR_DREADSTONE_REGEN_MINRATE,
            sanity:GetPercent())
        armor:Repair(armor.maxcondition * rate)
    end
end

local function StartBrokenSelfRepair(inst, state)
    if state.repair_mode == "self_repair" and state.self_repair_task == nil then
        state.self_repair_task = inst:DoPeriodicTask(
            GLOBAL.TUNING.ARMOR_DREADSTONE_REGEN_PERIOD,
            DoBrokenSelfRepair)
    end
end

local function SetBroken(inst)
    local state = GetState(inst)
    if state == nil or state.broken or not inst:IsValid() then
        return
    end

    state.broken = true
    inst:AddTag(BROKEN_ITEM_TAG)
    CancelDelayedRemoval(inst)

    local armor = inst.components.armor
    if armor ~= nil then
        state.absorption_before_break = armor.absorb_percent
        armor:SetAbsorption(0)
    end

    local equippable = inst.components.equippable
    if equippable ~= nil then
        state.restricted_tag_before_break = equippable.restrictedtag
        equippable.restrictedtag = BROKEN_EQUIP_RESTRICTION
    end

    ForceUnequip(inst)
    StartBrokenSelfRepair(inst, state)
end

local function SetRepaired(inst)
    local state = GetState(inst)
    if state == nil or not state.broken or not inst:IsValid() then
        return
    end

    state.broken = false
    StopBrokenSelfRepair(state)
    inst:RemoveTag(BROKEN_ITEM_TAG)

    local armor = inst.components.armor
    if armor ~= nil and state.absorption_before_break ~= nil then
        armor:SetAbsorption(state.absorption_before_break)
        state.absorption_before_break = nil
    end

    local equippable = inst.components.equippable
    if equippable ~= nil then
        equippable.restrictedtag = state.restricted_tag_before_break
    end
    state.restricted_tag_before_break = nil
end

local function SyncBrokenState(inst)
    local state = GetState(inst)
    if state == nil or not inst:IsValid() then
        return
    end

    local percent = GetDurabilityPercent(inst, state.kind)
    if percent == nil then
        return
    end

    if percent <= 0 or (state.was_broken_on_load and percent <= REPAIR_THRESHOLD) then
        SetBroken(inst)
    elseif percent > REPAIR_THRESHOLD then
        SetRepaired(inst)
    end
    state.was_broken_on_load = nil
end

local function OnPercentUsedChange(inst)
    SyncBrokenState(inst)
end

local function InstallState(inst, kind, repair_mode)
    local state =
    {
        kind = kind,
        repair_mode = repair_mode,
        broken = false,
    }
    inst._no_break_repairables_state = state

    -- Repairs at or below the recovery threshold must stay broken after loading.
    local on_save = inst.OnSave
    inst.OnSave = function(inst, data, ...)
        data.no_break_repairables_broken = state.broken or state.was_broken_on_load or nil
        if on_save ~= nil then
            return on_save(inst, data, ...)
        end
    end

    local on_load = inst.OnLoad
    inst.OnLoad = function(inst, data, ...)
        if on_load ~= nil then
            on_load(inst, data, ...)
        end
        state.was_broken_on_load = data ~= nil and data.no_break_repairables_broken == true
    end

    inst:ListenForEvent("percentusedchange", OnPercentUsedChange)

    -- Fueled:OnLoad initializes its value without emitting percentusedchange.
    -- Deferring one tick also synchronizes zero-durability items loaded from a
    -- save after every component has restored its state.
    inst:DoTaskInTime(0, SyncBrokenState)
    return state
end

local function ProtectArmor(inst, repair_mode)
    local armor = inst.components.armor
    if armor == nil or armor:IsIndestructible() then
        return false
    end

    InstallState(inst, "armor", repair_mode)
    armor:SetKeepOnFinished(true)
    return true
end

local function ProtectFiniteUses(inst)
    local finiteuses = inst.components.finiteuses
    local repairable = inst.components.repairable
    if finiteuses == nil or inst.components.equippable == nil
            or repairable == nil or repairable.repairmaterial == nil then
        return false
    end

    -- Nil/custom callbacks may already implement a broken state. Replacing an
    -- unknown custom callback could discard prefab-specific cleanup.
    if finiteuses.onfinished ~= inst.Remove then
        return false
    end

    InstallState(inst, "finiteuses", "material")
    finiteuses:SetOnFinished(SetBroken)
    return true
end

local function ProtectFueled(inst)
    local fueled = inst.components.fueled
    if fueled == nil or inst.components.equippable == nil then
        return false
    end

    local can_sew =
        (fueled.fueltype == FUELTYPE.USAGE or fueled.secondaryfueltype == FUELTYPE.USAGE)
        and fueled.no_sewing ~= true
    local can_refuel = fueled.accepting == true
    if not can_sew and not can_refuel then
        return false
    end

    local direct_remove = fueled.depleted == inst.Remove
    local has_custom_remover = CUSTOM_FUELED_REMOVERS[inst.prefab]
    local has_delayed_remover = PERSISTENT_BROKEN_FUELED[inst.prefab]
    if not direct_remove and not has_custom_remover and not has_delayed_remover then
        return false
    end

    local state = InstallState(inst, "fueled", can_sew and "sewing" or "fuel")
    state.push_umbrella_ranout = UMBRELLA_REMOVERS[inst.prefab]
    if has_delayed_remover then
        state.cancel_decay = true
        inst:ListenForEvent("ondropped", OnProtectedItemDropped)
    else
        fueled:SetDepletedFn(SetBroken)
    end
    return true
end

local function ProtectPrefab(inst)
    if GLOBAL.TheWorld == nil or not GLOBAL.TheWorld.ismastersim then
        return
    end
    if inst.components == nil or inst.components.inventoryitem == nil then
        return
    end
    if inst.components.forgerepairable ~= nil or GetState(inst) ~= nil then
        return
    end

    local repair_mode = REPAIRABLE_ARMOR[inst.prefab]
    if repair_mode ~= nil and ProtectArmor(inst, repair_mode) then
        return
    end
    if ProtectFiniteUses(inst) then
        return
    end
    ProtectFueled(inst)
end

NO_BREAK_REPAIRABLES_API =
{
    broken_item_tag = BROKEN_ITEM_TAG,
    broken_equip_restriction = BROKEN_EQUIP_RESTRICTION,
    get_state = GetState,
    protect_prefab = ProtectPrefab,
    sync_broken_state = SyncBrokenState,
}

AddPrefabPostInitAny(ProtectPrefab)
