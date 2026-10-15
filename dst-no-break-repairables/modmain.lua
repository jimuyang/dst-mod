modimport("scripts/no_break_repairables.lua")

if GetModConfigData("runtime_tests") == true then
    modimport("tests/runtime_smoke.lua")
end
