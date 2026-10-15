name = "坏而不毁 | No Break Repairables"
description = [[
可修复的耐久物品归零后不再消失。

- 魔光护符、恐怖盾牌、眼面具归零后保留
- 可修复 finiteuses 物品与可缝补装备归零后保留
- 归零时自动卸下，修复到超过 1% 耐久后可重新装备
]]
author = "yangfan.jimu"
version = "1.1.0"

api_version = 10
dst_compatible = true
dont_starve_compatible = false
reign_of_giants_compatible = false

all_clients_require_mod = false
client_only_mod = false
server_only_mod = true

configuration_options =
{
    {
        name = "runtime_tests",
        label = "Developer runtime tests",
        hover = "Run the bundled server-side smoke tests once after the world loads.",
        options =
        {
            { description = "Disabled", data = false },
            { description = "Enabled", data = true },
        },
        default = false,
    },
}
