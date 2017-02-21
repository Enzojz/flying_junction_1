local descEN = [[Typical Concrete Flying Junction in Europe.

* Available via Passenger station menu
* Attention: this MOD may change the bridge order for other bridge MODs, take attention with use on saved games with other bridge MODs installed.

Implemented functions:
* 1 ~ 6 tracks for upper or lower level
* Crossing angle between 5° and 89° with increment of 1°
* Track grouping of tunnels by 1, 2 or no grouping
* Independent adjustment of cuvres of tracks  
* Left handed or right handed
* Build with slope
* Altitude Adjustment

To be implemented functions:
* Option of parallel track raising
* Cosmetics

Changelog:
1.5
* Totally rewritten with curves options.
1.2
* Fixed issue with change of original in-game bridges in saved games.
1.1
* Changed altitude options for a more accurate adjustment, and avoid brdige failure by default 

--------------- 
* Planned projects 
- Crossing station 
- Better Curved station]]

local descFR = [[Saut de mouton.

* Disponible via menu de gare de voyageurs
* Attention: ce MOD pourrait changer l'ordre des ponts, veuillez utilise avec prudent avec les gamesaves existants.

Caractéristiques:
* 1 ~ 6 voies pour le niveau supérieur et inférieur
* Angle de croisement entre 5° et 89° avec incrément de 1°
* Tunnel des voies de groupe de 1, 2 or tous les voies
* Changement indépendant de courbure des voies  
* Gaucher ou droitier
* Construction en pente 
* Changement d'altitude

À implémenter:
* Options des voies en montant/désendant
* Cosmétique

Changelog:
1.5
* Refactorisation totalle avec options des courbes.
1.2
* Correction de problem avec gamesaves existants.]]

local descCN = [[欧式水泥疏解桥.

* 通过旅客车站菜单建造
* 注意: 该MOD包含一个新的桥类，可能会影响现有游戏存档.

特点:
* 上层和下层各可有 1 ~ 6 条股道
* 5°到89°度的交汇角，调整幅度为1°
* 隧道分组可为1条，2条或所有轨道
* 四个独立的轨道曲线调整选项  
* 坡度选项 
* 高度选项

尚未实现:
* 完整的平行轨道上升/下降部分
* 更真实的贴图

Changelog:
1.5
* 完全重写，并且增加了曲线选项Refactorisation totalle avec options des courbes.
1.2
* 修正了和既有存档的冲突.]]

function data()
    return {
        en = {
            ["name"] = "Concrete Flying Junction",
            ["desc"] = descEN,
        },
        fr = {
            ["name"] = "Saut de mouton",
            ["desc"] = descFR,
            ["Number of lower tracks"] = "Nombre des voies inférieurs",
            ["Number of upper tracks"] = "Nombre des voies supérieurs",
            ["Crossing angles"] = "Angle de croisement",
            ["Tracks per group"] = "Nombre de voie par groupe",
            ["Curvature of lower tracks : Far/Near"] = "Courbure de voie inf. : Proche/Loin",
            ["Curvature of upper tracks : Far/Near"] = "Courbure de voie sup. : Proche/Loin",
            ["Mirrored"] = "En miroir",
            ["Slope(‰)"] = "Pente(‰)",
            ["Altitude Adjustment(m)"] = "Ajustement d'altitude(m)",
        },
        zh_CN = {
            ["name"] = "欧式水泥疏解桥",
            ["desc"] = descCN,
            ["Number of lower tracks"] = "下层轨道数量",
            ["Number of upper tracks"] = "上层轨道数量",
            ["Curvature of lower tracks : Far/Near"] = "下层轨道曲率 : 远/近",
            ["Curvature of upper tracks : Far/Near"] = "上层轨道曲率 : 远/近",
            ["Crossing angles"] = "交汇角",
            ["Tracks per group"] = "每组轨道数量",
            ["Mirrored"] = "镜像",
            ["Slope(‰)"] = "坡度(‰)",
            ["Altitude Adjustment(m)"] = "整体高度(m)",
        },
    }
end
