local descEN = [[Flying junctions.
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
1.15
* Reimplementation of models and model positioning algorithm to have non-overlapping, non-flickering walls or bricks
1.14
* CommonAPI support
* Seperation of upper/lower track types
1.13
* Fixed upper level catenary bug
1.12
* Fixed crash when modifying lower level length when altitude equals to or greater than 100%, or higher level length when altitude is 0%
1.11
* Fixed crash when lower length equals to 50% and shorter
* Fixed error of position calculate for non crossing layout with grouped tracks
* Fixed error of position and length calculate for side retaining walls for lower level
* Fixed missing upper fences on side of transition B
* Fixed terrain alignment error on some solid transition section.
1.10
* Colission bugfix on crossing layout
* Retaining wall form bugfix on crossing layout
* Terrain alignement on lower level improved
1.9
* Added option to have curves on transitions
* Added common axis for general slope
1.8
* Added option to adjust transition length
* Improved slope option
* Improved menu
1.7
* Fixed crashes with small angles
1.6
* Raising or trenche transition tracks
* Independent catenary options
* Stone bricks version
* Reworked materials
* Backward compatibility
1.5
* Totally rewritten with curves options
1.2
* Fixed issue with change of original in-game bridges in saved games
1.1
* Changed altitude options for a more accurate adjustment, and avoid brdige failure by default

---------------
* Planned projects
- Crossing station
- Better Curved station]]

local descFR = [[Saut de mouton.
* Disponible via menu de gare de voyageurs

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
1.15
* Reimplémentation de l'algorithme de positionement des maquettes pour éviter la superposition et scintillement entre des maquettes
1.14
* Support de CommonAPI
* Séparation d'option de type de voie du haut et du bas
1.13
* Correction d'implémentation de caténaire du niveau superieur.
1.12
* Correction de plantage lors modification du longueur du niveau bas, quand l'altitude est équal à ou superieur à 100%, ou pour le niveau haut quand l'altitude est à 0%.
1.11
* Correction de plantage lors longueur du niveau bas est équal à 50%
* Correction de erreur de calcule des positions des voies groupées pour disponition non croisement simple
* Correction de erreur de calcule du lengueur et de la position du mur de soutènement
* Rajoute de clôture manquantes du côté transition B
* Correct de erreur de calculs de alignment de terrain sur des transition solide.
1.10
* Correction de erreur de colission sur disposition de croisement
* Correction de forme de mur sur la disposition de croisement
* Amélioration de alignement du terrain
1.9
* Ajoute des options pour avoir transitions en courbes
* Ajoute d'une axe commue pour la pente générale
1.8
* Ajoute des options pour modifier le longueur des transitions
* Amélioration d'option de pente
* Amélioration de menu
1.7
* Correction de plantage lors l'angle passe en petit
1.6
* Voies de transition montant/désendant
* Options de caténaire indépendantes
* Version en pierre de taille
* Matériels refaites
* Compatibilité arrière
1.5
* Refactorisation totalle avec options des courbes
1.2
* Correction de problem avec gamesaves existants.]]

local descCN = [[欧式疏解桥.
* 通过旅客车站菜单建造

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
1.15
* 重写了模型和模型放置算法，消除了前后墙或者砖的模型之间的重叠和闪烁现象
1.14
* 增加了CommonAPI支持
* 增加了分离的上下层轨道类型选项
1.13
* 修正了上层接触网选项的错误
1.12
* 修复了在高度调整为100%或者更高的情况下，修改下层长度，以及在高度调整为0%修改上层长度时引发的游戏崩溃
1.11
* 修正了下层长度为50%时的游戏崩溃
* 修正了轨道分组时的轨道位置计算错误
* 修正了下层挡土墙的长度和位置计算错误
* 修复了B过渡区段上方消失的围栏
* 修复了在一些实心过渡区段的地面计算错误
1.10
* 修正了交叉布局下的一个冲突错误
* 修正了交叉布局下挡土墙的形状
* 优化了底层轨道的地形修整算法
1.9
* 增加了过渡区段的曲线选项
* 增加了一个新的整体坡度倾斜轴选项
1.8
* 增加了过渡区段长度的选项
* 改进了坡度选项
* 改进了菜单的布置
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
* 修正了和既有存档的冲突]]

function data()
    return {
        en = {
            ["name"] = "Flying Junction",
            ["desc"] = descEN,
        },
        fr = {
            ["name"] = "Saut de mouton",
            ["desc"] = descFR,
            ["Lower Track Type"] = "Type de voie en bas",
            ["Upper Track Type"] = "Type de voie en haut",
            ["Number of lower tracks"] = "Nombre des voies en bas",
            ["Number of upper tracks"] = "Nombre des voies en haut",
            ["Curved levels"] = "Niveaux avec courbes",
            ["Crossing angles"] = "Angle de croisement",
            ["Tracks per group"] = "Nombre de voie par groupe",
            ["Radius of lower tracks"] = "Rayon du niveau bas",
            ["Radius of upper tracks"] = "Rayon du niveau haut",
            ["Lower tracks length"] = "Longueur du niveau bas",
            ["Upper tracks length"] = "Longueur du niveau haut",
            ["Form"] = "Forme",
            ["Axis"] = "Axe",
            ["Radius"] = "Rayon",
            ["Slope"] = "Pente",
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
            ["Common"] = "Commune",
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
            ["Lower Track Type"] = "下层轨道类型",
            ["Upper Track Type"] = "上层轨道类型",
            ["Number of lower tracks"] = "下层轨道数量",
            ["Number of upper tracks"] = "上层轨道数量",
            ["Curved levels"] = "曲线部分",
            ["Radius of lower tracks"] = "下层轨道半径",
            ["Radius of upper tracks"] = "上层轨道半径",
            ["Transition A"] = "A过渡区段",
            ["Transition B"] = "B过渡区段",
            ["Lower tracks length"] = "下层轨道长度",
            ["Upper tracks length"] = "上层轨道长度",
            ["Form"] = "形式",
            ["Axis"] = "倾斜轴",
            ["Radius"] = "半径",
            ["Slope"] = "坡度",
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
            ["Common"] = "共轴",
            ["Tunnel Height"] = "隧道净高",
            
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
