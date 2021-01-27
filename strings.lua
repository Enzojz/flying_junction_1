local descEN = [[This mod helps you construct a compact european style flying junction.

The development of the mod started in 2020 May but I got little time to work on it due to busy job occupation, so it's released as early version to avoid you being waiting to long.
It's still not stable and contains only the core part, don't be surprise if these's little problem here and there and if it crashes under certain circumstances: just avoid the same parameter the next time.

It's not a port of Flying Junction mod in Tpf1, all is reworked with benefit of techinique that I developped with the Ultimate Station and Ultimate Underground Station.

This mod also features the module sytsem provided by the game, you can mix different tracks also retaining wall configuration in a same structure. You can also replace modules in-place.

There are two basic configurations: road and railway, after build you can configurate the junction as you like: change road with tracks, change track modules or road modules in module editing mode.

Lot's of things to be done:
1. The transition parts (the most complicated thing)
2. Sunk mode
4. Length reducer (as you see in compact tunnel entry)
5. Some details...

This mod requires "Shader Enhancement mod" for extending materials.
]]

local descFR = [[
]]

local descCN = [[本模组帮助你建造一种欧洲很常见的单体结构疏解桥。

作者于2020年五月就已经开始模组的开发工作，但无奈工作繁忙，拖到现在也只完成了核心部分，先发布已经完成的部分以飧玩家。
该模组尚未完善，如果发生闪退的情况，下次避免使用相同参数即可。

模组使用了游戏提供的模块化系统，可以按照需求定制轨道和结构墙的配置。
]]

local descTC = [[本模組幫助你建造一種歐洲很常見的單體結構疏解橋。

作者于2020年五月就已經開始模組的開發工作，但無奈工作繁忙，拖到現在也只完成了核心部分，先發佈已經完成的部分以飧玩家。
該模組尚未完善，如果發生閃退的情況，下次避免使用相同參數即可。

模組使用了遊戲提供的模組化系統，可以按照需求定制軌道和結構牆的配置。
]]

function data()
    return {
        en = {
            MOD_NAME = "Flying junction (early release)",
            MOD_DESC = descEN,
            MENU_NAME = "Flying junction",
            MENU_DESC = "Railway flyover in a single structure",
            MENU_TRACK_NR_LOWER = "Number of lower tracks",
            MENU_TRACK_NR_UPPER = "Number of upper tracks",
            MENU_TRACK_TYPE = "Track Type",
            MENU_TRACK_CAT = "Catenary",
            MENU_X_DEG = "Crossing angle (°)",
            MENU_R_UPPER = "Upper track radii (m)",
            MENU_R_LOWER = "Lower track radii (m)",
            MENU_TUNNEL_HEIGHT = "Tunnel Height (m)",
            MENU_WALL_STYLE = "Retaining wall",
            MENU_WITH_CAT = "(with catenary)",
            TRACK_CAT = "Tracks (Elec.)",
            TRACK = "Tracks",
            STRUCTURE="Structure",
            MENU_WALL_NAME = "Retaining wall",
            MENU_WALL_DESC = "Retaining wall that seperate the tracks.",
            STREET = "Road",
            ONE_WAY = "Road - One way",
            ONE_WAY_REV = "Road - One way (Rev.)",
            MENU_STREET_TYPE = "Road Type",
            EXT_TYPE = "Edge Type",
            ZIGZAG = "ZigZag",
            ALIGNED = "Aligned"
        },
        zh = {
            MOD_NAME = "欧式疏解桥",
            MOD_DESC = descCN,
            MENU_NAME = "Flying junction",
            MENU_DESC = "单一结构中的欧式疏解桥",
            MENU_TRACK_NR_LOWER = "下层轨道数",
            MENU_TRACK_NR_UPPER = "上层轨道数",
            MENU_TRACK_TYPE = "轨道类型",
            MENU_TRACK_CAT = "接触网",
            MENU_X_DEG = "交汇角 (°)",
            MENU_R_UPPER = "上层轨道半径(米)",
            MENU_R_LOWER = "下层轨道半径(米)",
            MENU_TUNNEL_HEIGHT = "隧道高度(米)",
            MENU_WALL_STYLE = "结构墙体",
            MENU_WITH_CAT = "(带接触网)",
            TRACK_CAT = "轨道(电)",
            TRACK = "轨道",
            STRUCTURE="支撑结构",
            MENU_WALL_NAME = "结构墙",
            MENU_WALL_DESC = "分隔轨道的结构墙.",
            STREET = "街道",
            ONE_WAY = "单行道",
            ONE_WAY_REV = "单行道 (反)",
            MENU_STREET_TYPE = "道路类型",
            EXT_TYPE = "边缘类型",
            ZIGZAG = "齿状",
            ALIGNED = "平直"
        },
        tw = {
            MOD_NAME = "歐式疏解橋",
            MOD_DESC = descTC,
            MENU_NAME = "歐式疏解橋",
            MENU_DESC = "單一結構中的歐式疏解橋",
            MENU_TRACK_NR_LOWER = "下層軌道數",
            MENU_TRACK_NR_UPPER = "上層軌道數",
            MENU_TRACK_TYPE = "軌道類型",
            MENU_TRACK_CAT = "接觸網",
            MENU_X_DEG = "交匯角 (°)",
            MENU_R_UPPER = "上層軌道半徑(公尺)",
            MENU_R_LOWER = "下層軌道半徑(公尺)",
            MENU_TUNNEL_HEIGHT = "隧道高度(公尺)",
            MENU_WALL_STYLE = "結構牆體",
            MENU_WITH_CAT = "(帶接觸網)",
            TRACK_CAT = "軌道(電)",
            TRACK = "軌道",
            STRUCTURE="支撐結構",
            MENU_WALL_NAME = "結構牆",
            MENU_WALL_DESC = "分隔軌道的結構牆.",
            STREET = "街道",
            ONE_WAY = "單行道",
            ONE_WAY_REV = "單行道 (反)",
            MENU_STREET_TYPE = "道路類型",
            EXT_TYPE = "邊緣類型",
            ZIGZAG = "齒狀",
            ALIGNED = "平直"
        },
    }
end
