# Repairable Gear Stays

> 可修复的耐久物品归零后会进入“保留但失效”的破损状态，修复到正数后恢复，不会变成无限耐久装备。

## 行为总览

```mermaid
flowchart LR
    A[可修复物品耐久归零] --> B[保留实体]
    B --> C{绝望石装备?}
    C -- 否 --> D[自动卸下并禁止装备]
    C -- 是 --> E[卸下后桥接第一段自修复]
    D --> F[加燃料 / 喂食 / 材料修复 / 缝补]
    E --> F
    F --> G[耐久大于零并恢复原有效果]
```

Mod 明确支持：

- 魔光护符 `yellowamulet`：燃料耗尽后自动卸下；噩梦燃料或纯粹恐惧补充后恢复。
- 恐怖盾牌 `shieldofterror`：0 护甲时保留、吸收率归零；喂食后恢复。
- “恐怖头盔”：按与恐怖盾牌配套的眼面具 `eyemaskhat` 处理；喂食后恢复。
- 橙色护符等可装备的 `finiteuses + repairable` 且原本在归零时删除的物品。
- 所有带 `FUELTYPE.USAGE`、允许缝补且原本在归零时删除的可装备物品。
- 伯尼 `bernie_inactive`：保留原版破损外观，但取消落地后的延迟分解；缝补后恢复。
- 可直接补充燃料且原本在归零时删除的可装备物品。
- 绝望石头盔 `dreadstonehat` 和绝望石盔甲 `armordreadstone`：0 耐久时卸下并失效；由 Mod 在持有者疯狂时桥接第一段自修复，恢复到正数后即可重新穿戴。

以下物品刻意不改：

- 不可修复的普通工具、武器和护甲。
- 明确设置 `no_sewing = true` 的耗损装备。
- 暖石等非装备型 fueled 物品。
- 腐烂、建筑生命值和工作次数。
- 已有 `forgerepairable` 破损状态的亮茄、虚空和废铁装备。
- 带未知自定义耗尽回调的第三方 Mod 物品；避免丢失其特殊清理逻辑。

## 安装

### macOS 本地世界

1. 将本目录复制或软链接到：

   ```text
   ~/Library/Application Support/Steam/steamapps/common/Don't Starve Together/dontstarve_steam.app/Contents/mods/dst-no-break-repairables
   ```

2. 启动 DST，在创建或编辑世界时进入 `Mods`，启用 `Repairable Gear Stays`。
3. Mod 仅修改服务端逻辑，其他玩家不需要单独安装。

开发时可执行：

```bash
ln -s /absolute/path/to/dst-mod/no-break-repairables \
  "$HOME/Library/Application Support/Steam/steamapps/common/Don't Starve Together/dontstarve_steam.app/Contents/mods/dst-no-break-repairables"
```

### Dedicated Server

将目录放入服务端 `mods/dst-no-break-repairables`，然后在 shard 的 `modoverrides.lua` 中启用：

```lua
return {
    ["dst-no-break-repairables"] = {
        enabled = true,
        configuration_options = {
            runtime_tests = false,
        },
    },
}
```

## 验证

`runtime_tests` 默认为 `false`。开发验证时临时设为 `true`，世界加载后服务端日志会输出 `[NBR TEST]`。当前本机 Dedicated Server 实测结果：

```text
[NBR TEST] RESULT: passed=65 failed=0
```

测试覆盖魔光护符自动卸下和实际加燃料、恐怖盾牌/眼面具实际喂食、橙色护符材料修复、实际缝纫、雨伞耗尽后自动切换备用雨具、旧 broken 物品不阻塞健康备用品、直接/自定义/延迟删除 fueled 路径、绝望石装备，以及不可修复物品反例。

## 兼容性

- 使用 `AddPrefabPostInitAny` 在 prefab 完成初始化后做保守识别，不复制原版 prefab，也不覆写 `Armor:SetCondition` 等全局组件方法。
- 破损时会保存并在修复后恢复物品原有 `equippable.restrictedtag` 和护甲吸收率。
- 禁止重新装备依赖原版玩家 `equippable` restriction；NPC 或第三方实体装备这些物品不在自动兼容范围内。
- 0 耐久物品仍处于破损状态时，不建议停用 Mod；原版重新加载这些物品时可能恢复原有删除或错误生效行为。停用前先修好它们。
- 游戏更新若改变耐久组件或目标 prefab 的回调，需要重新跑内置测试。

实现依据与兼容性边界见 [调研文档](doc/research.md)。

## 参考资料

- [Klei Modding Practices: Introduction to Modding](https://forums.kleientertainment.com/forums/topic/50773-guide-modding-practices-introduction-to-modding/)
- [Klei 论坛：AddComponentPostInit 的执行时机](https://forums.kleientertainment.com/forums/topic/130808-how-does-addcomponentpostinit-exactly-works/)
- [当前脚本镜像中的 MakeForgeRepairable](https://github.com/CN-DST-DEVELOPER/scripts/blob/cfb77bf07e6496e344ac92652a08566d12067e8a/standardcomponents.lua#L1779-L1812)
