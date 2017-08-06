local descEN = [[Flying junctions in Europe.
* Available via Passenger station menu

Implemented functions:
* 1 ~ 6 tracks for upper or lower level
* Crossing angle between 5° and 89° with increment of 1°
* Track grouping of tunnels by 1, 2 or no grouping
* Independent adjustment of cuvres of tracks
* Left handed or right handed
* Built in concrete or stone bricks
* Raising or trenche transition tracks in possible forms of bridge, terra or solid construction.
* Build with slope
* Altitude Adjustment
* Independent catenary options

Changelog:
1.7
* Fixed crashes with small angles
1.6
* Raising or trenche transition tracks
* Independent catenary options
* Stone bricks version
* Reworked materials
* Backward compatibility
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
* Construction en concrete ou pierre de taille
* Voies de transition montant/désendant sous formes de pont, terre ou construction solide.
* Options de caténaire indépendantes

Changelog:
1.7
* Correction de plantage lors l'angle passe en petit
1.6
* Voies de transition montant/désendant
* Options de caténaire indépendantes
* Version en pierre de taille
* Matériels refaites
* Compatibilité arrière
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
* 水泥或石砖建造
* 上升/下降的过渡轨道可以以桥、堆土或者实心形式展现
* 不同层不同的接触网选项

Changelog:
1.7
* 修正了较小角度时的奔溃问题
1.6
* 上升/下降的过渡轨道
* 不同层不同的接触网选项
* 石砖版本
* 优化了贴图
* 向后兼容
1.5
* 完全重写，并且增加了曲线选项
1.2
* 修正了和既有存档的冲突.]]

function data()
    return {
        en = {
            ["name"] = "Flying Junction",
            ["desc"] = descEN,
        },
        fr = {
            ["name"] = "Saut de mouton",
            ["desc"] = descFR,
            ["Number of lower tracks"] = "Nombre des voies en bas",
            ["Number of upper tracks"] = "Nombre des voies en haut",
            ["Curved levels"] = "Niveaux avec courbes",
            ["Crossing angles"] = "Angle de croisement",
            ["Tracks per group"] = "Nombre de voie par groupe",
            ["Radius of lower tracks"] = "Rayon au niveau bas",
            ["Radius of upper tracks"] = "Rayon au niveau haut",
            ["Transition A slope"] = "Pente de la transition A",
            ["Transition B slope"] = "Pente de la transition B",
            ["Form of asc. tr. A"] = "Fome de la montée tr. A",
            ["Form of asc. tr. B"] = "Fome de la montée tr B",
            ["Mirrored"] = "En miroir",
            ["General Slope"] = "Pente générale",
            ["Tunnel Height"] = "Hauteur de tunnel",
            ["Altitude Adjustment"] = "Ajustement d'altitude",
            ["Catenary applied for"] = "Application de caténaire",
            ["Bridge"] = "Pont",
            ["Terra"] = "Terre",
            ["Solid"] = "Solide",
            ["Both"] = "Tous",
            ["Lower"] = "Bas",
            ["Upper"] = "Haut",
            ["None"] = "Aucun",
            ["All"] = "Toutes",
            ["Bifurcation Flying Junction in concrete"] = "Saut de mouton de bifurcation en concrete",
            ["Crossing Flying Junction in concrete"] = "Saut de mouton de croisement en concrete",
            ["Exchange Flying Junction in concrete"] = "Saut de mouton d'échange en concrete",
            ["Bifurcation Flying Junction in bricks"] = "Saut de mouton de bifurcation en pierre de taille",
            ["Crossing Flying Junction in bricks"] = "Saut de mouton de croisement en pierre de taille",
            ["Exchange Flying Junction in bricks"] = "Saut de mouton d'échange en pierre de taille",
            ["A flying junction that used to bifurcate two lines, built in concrete"] = "Un saut de mouton pour bifurquer deux lignes, construction en concrete.",
            ["A flying junction that used to cross two lines, built in concrete"] = "Un saut de mouton pour croiser deux lignes, construction en concrete.",
            ["A flying junction that used to exchange the position of tracks, built in concrete"] = "Un saut de mouton pour changement des positions des deux groupes, construction en concrete.",
            ["A flying junction that used to bifurcate two lines, built in bricks"] = "Un saut de mouton pour bifurquer deux lignes, construction en pierre de taille.",
            ["A flying junction that used to cross two lines, built in bricks"] = "Un saut de mouton pour croiser deux ligne , construction en pierre de taille.",
            ["A flying junction that used to exchange the position of tracks, built in bricks"] = "Un saut de mouton pour changement des positions des deux groupes, construction en pierre de taille.",
        },
        zh_CN = {
            ["name"] = "欧式疏解桥",
            ["desc"] = descCN,
            ["Number of lower tracks"] = "下层轨道数量",
            ["Number of upper tracks"] = "上层轨道数量",
            ["Curved levels"] = "曲线部分",
            ["Radius of lower tracks"] = "下层半径",
            ["Radius of upper tracks"] = "上层半径",
            ["Transition A slope"] = "A过渡区段坡度",
            ["Transition B slope"] = "B过渡区段坡度",
            ["Form of asc. tr. A"] = "A过渡区段形式",
            ["Form of asc. tr. B"] = "B过渡区段形式",
            ["Crossing angles"] = "交汇角",
            ["Tracks per group"] = "每组轨道数量",
            ["Mirrored"] = "镜像",
            ["General Slope"] = "整体坡度",
            ["Altitude Adjustment"] = "高度调整",
            ["Catenary applied for"] = "接触网用于",
            ["Bridge"] = "桥",
            ["Terra"] = "堆土",
            ["Solid"] = "实心",
            ["Both"] = "两者",
            ["Lower"] = "下层",
            ["Upper"] = "上层",
            ["None"] = "无",
            ["All"] = "所有",
            
            ["Bifurcation Flying Junction in concrete"] = "水泥制联络疏解",
            ["Crossing Flying Junction in concrete"] = "水泥制交叉疏解",
            ["Exchange Flying Junction in concrete"] = "水泥制换位疏解",
            ["Bifurcation Flying Junction in bricks"] = "砖制联络疏解",
            ["Crossing Flying Junction in bricks"] = "砖制交叉疏解",
            ["Exchange Flying Junction in bricks"] = "砖制换位疏解",
            ["A flying junction that used to bifurcate two lines, built in concrete"] = "用水泥建造的，用于联络的疏解桥.",
            ["A flying junction that used to cross two lines, built in concrete"] = "用水泥建造的，用于交叉的疏解桥.",
            ["A flying junction that used to exchange the position of tracks, built in concrete"] = "用水泥建造的，用于交换线位的疏解桥.",
            ["A flying junction that used to bifurcate two lines, built in bricks"] = "用石砖建造的，用于联络的疏解桥.",
            ["A flying junction that used to cross two lines, built in bricks"] = "用石砖建造的，用于交叉的疏解桥.",
            ["A flying junction that used to exchange the position of tracks, built in bricks"] = "用石砖建造的，用于交换线位的疏解桥."
        
        },
    }
end
