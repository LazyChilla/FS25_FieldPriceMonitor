-- gui/InGameMenuFPM.lua
-- Grundstück-Preismonitor

InGameMenuFPM = {}
InGameMenuFPM._mt = Class(InGameMenuFPM, TabbedMenuFrameElement)

local SORT_ID       = "id"
local SORT_AREA     = "area"
local SORT_PRICE    = "price"
local SORT_DISCOUNT = "discount"
local SORT_NET      = "net"
local SORT_STATE    = "state"
local SORT_FRUIT    = "fruit"
local SORT_OWNER    = "owner"

---------------------------------------------------------------------------
-- Konstruktor - Buttons nach STT Pattern im Konstruktor setzen
---------------------------------------------------------------------------
function InGameMenuFPM.new(i18n)
    local self = InGameMenuFPM:superClass().new(nil, InGameMenuFPM._mt)
    self.name              = "ingameMenuFPM"
    self.i18n              = i18n
    self.fieldData         = {}
    self.sortColumn        = SORT_NET
    self.sortDesc          = false
    self.dataBindings      = {}
    self.fieldByFarmlandId = {}
    self.bcSettings        = nil
    self._bcSettings       = nil

    self.backButtonInfo = { inputAction = InputAction.MENU_BACK }
    self.warpButtonInfo = {
        inputAction = InputAction.MENU_ACCEPT,
        text        = string.upper(i18n:getText("ui_fpm_btnWarp") or "Zum Feld"),
        disabled    = true,
        callback    = function() self:onClickWarp() end,
    }

    return self
end

---------------------------------------------------------------------------
-- GUI verdrahten
---------------------------------------------------------------------------
function InGameMenuFPM:onGuiSetupFinished()
    InGameMenuFPM:superClass().onGuiSetupFinished(self)
    self.priceTable:setDataSource(self)
    self.priceTable:setDelegate(self)

    -- Buttons hier setzen - erst nach loadGui verfügbar!
    self:setMenuButtonInfo({
        self.backButtonInfo,
        self.warpButtonInfo,
    })

    -- Kontostand
    self.balanceText = self:getDescendantById("fpmBalance")

    -- Icon via imageSliceId im Profil gesetzt (kein Lua nötig)
end

---------------------------------------------------------------------------
-- Tab öffnen
---------------------------------------------------------------------------
function InGameMenuFPM:onFrameOpen()
    InGameMenuFPM:superClass().onFrameOpen(self)

    -- Icon via imageSliceId im Profil gesetzt (kein Lua nötig)

    -- Cache zurücksetzen damit BC-Status immer frisch gelesen wird
    self.bcSettings = nil

    self:updateBalance()
    self:buildFieldLookup()

    -- pcall damit ein Fehler die Liste nicht leer lässt
    local ok, err = pcall(function()
        self:collectData()
    end)
    if not ok then
        print("[FPM] Fehler in collectData: " .. tostring(err))
        self.fieldData = {}
    end

    self:sortData()
    self.priceTable:reloadData()
    FocusManager:setFocus(self.priceTable)

    if #self.fieldData > 0 and self.fieldData[1].fieldX ~= nil then
        self.warpButtonInfo.disabled = false
    else
        self.warpButtonInfo.disabled = true
    end
    self:setMenuButtonInfoDirty()
end

---------------------------------------------------------------------------
-- Tab schließen
---------------------------------------------------------------------------
function InGameMenuFPM:onFrameClose()
    InGameMenuFPM:superClass().onFrameClose(self)
    self.fieldData         = {}
    self.fieldByFarmlandId = {}
    self.bcSettings        = nil
    self._bcSettings       = nil
end

---------------------------------------------------------------------------
-- Kontostand aktualisieren
---------------------------------------------------------------------------
function InGameMenuFPM:updateBalance()
    if self.balanceText == nil then return end
    local money = g_currentMission:getMoney()
    self.balanceText:setText(self.i18n:formatMoney(money, 0, true, true))
end

---------------------------------------------------------------------------
-- Feldlookup
---------------------------------------------------------------------------
function InGameMenuFPM:buildFieldLookup()
    self.fieldByFarmlandId = {}
    if g_fieldManager == nil then return end
    for _, field in pairs(g_fieldManager:getFields()) do
        if field.farmlandId ~= nil then
            self.fieldByFarmlandId[field.farmlandId] = field
        end
    end
end

---------------------------------------------------------------------------
-- BC-Einstellungen aus Savegame-XML lesen (einmalig gecacht pro Tab-Öffnung)
---------------------------------------------------------------------------
function InGameMenuFPM:getBCSettings()
    if self._bcSettings ~= nil then return self._bcSettings end

    self._bcSettings = false -- false = "geprüft, nicht gefunden"

    local savePath = g_currentMission ~= nil
        and g_currentMission.missionInfo ~= nil
        and g_currentMission.missionInfo.savegameDirectory

    if savePath == nil then return self._bcSettings end

    local xmlPath = savePath .. "/FS25_BetterContracts.xml"
    if not fileExists(xmlPath) then return self._bcSettings end

    local schema = XMLSchema.new("fpmBcCfg")
    schema:register(XMLValueType.BOOL,  "BetterContracts#discount")
    schema:register(XMLValueType.FLOAT, "BetterContracts.discount#perJob")
    schema:register(XMLValueType.INT,   "BetterContracts.discount#maxJobs")

    local xmlFile = XMLFile.loadIfExists("fpmBcCfg", xmlPath, schema)
    if xmlFile == nil then return self._bcSettings end

    local discountOn = xmlFile:getValue("BetterContracts#discount")
    local perJob      = xmlFile:getValue("BetterContracts.discount#perJob")
    local maxJobs     = xmlFile:getValue("BetterContracts.discount#maxJobs")
    xmlFile:delete()

    if not discountOn or perJob == nil or maxJobs == nil then
        return self._bcSettings -- bleibt false
    end

    self._bcSettings = {perJob = perJob, maxJobs = maxJobs}
    return self._bcSettings
end

function InGameMenuFPM:isMPClient()
    -- g_server == nil bedeutet wir sind MP-Client (kein Host)
    return g_server == nil and g_currentMission ~= nil
end

---------------------------------------------------------------------------
-- Rabatt berechnen - direkt aus Savegame-Daten (Giants npcJobs + BC-XML)
-- Rückgabe: discPct, discAmt, status
--   status: "ok"       -> Werte gültig (auch 0%/0€ ist "ok")
--           "no data"  -> BC-Settings nicht lesbar / discount aus
--           "host"     -> MP-Client, nur Host kennt korrekten Wert
---------------------------------------------------------------------------
function InGameMenuFPM:getDiscount(farmland, price, myFarmId)
    if farmland == nil or farmland.npcIndex == nil then return 0, 0, "ok" end

    if self:isMPClient() then return 0, 0, "host" end

    local cfg = self:getBCSettings()
    if cfg == false then return 0, 0, "no data" end

    local farm = g_farmManager ~= nil and g_farmManager:getFarmById(myFarmId) or nil
    if farm == nil or farm.stats == nil or farm.stats.npcJobs == nil then
        return 0, 0, "no data"
    end

    local count = farm.stats.npcJobs[farmland.npcIndex]
    if count == nil then return 0, 0, "no data" end

    if cfg.perJob <= 0 or cfg.maxJobs <= 0 then return 0, 0, "ok" end

    local capJobs = math.floor(0.5 / cfg.perJob)
    local disJobs = math.min(count, cfg.maxJobs, capJobs)
    if disJobs <= 0 then return 0, 0, "ok" end

    local discPct = math.floor(100 * disJobs * cfg.perJob + 0.5)
    local discAmt = math.floor(price * disJobs * cfg.perJob + 0.5)
    return discPct, discAmt, "ok"
end

---------------------------------------------------------------------------
-- Wachstumszustand - exakt nach FarmlandOverview
---------------------------------------------------------------------------
function InGameMenuFPM:getGrowthInfo(x, z, field)
    local ftIdx, growthState = FSDensityMapUtil.getFruitTypeIndexAtWorldPos(x, z)
    if ftIdx == nil then
        -- Kein Fruit → Bodentyp ermitteln
        local groundLabel = "—"
        if field ~= nil then
            local ok, state = pcall(field.getFieldState, field)
            if ok and state ~= nil then
                state:update(x, z)
                local gt = state.groundType
                -- sortKey-Bereiche: -1=leer, 1-50=Wachstum, 51=Erntereif, 60=Vertrocknet, 70=Abgeerntet, 100+=Bodenzustand
                local GT_INFO = {
                    [FieldGroundType.STUBBLE_TILLAGE]     = {"ui_fpm_gt_stubble",       {0.65, 0.55, 0.25, 1}, 100},
                    [FieldGroundType.PLOWED]              = {"ui_fpm_gt_plowed",        {0.71, 0.50, 0.30, 1}, 101},
                    [FieldGroundType.CULTIVATED]          = {"ui_fpm_gt_cultivated",    {0.62, 0.42, 0.22, 1}, 102},
                    [FieldGroundType.SEEDBED]             = {"ui_fpm_gt_seedbed",       {0.55, 0.55, 0.20, 1}, 103},
                    [FieldGroundType.ROLLED_SEEDBED]      = {"ui_fpm_gt_rolledSeedbed", {0.60, 0.60, 0.25, 1}, 104},
                    [FieldGroundType.GRASS_CUT]           = {"ui_fpm_gt_grassCut",      {0.40, 0.70, 0.30, 1}, 105},
                    [FieldGroundType.HARVEST_READY]       = {"ui_fpm_gt_harvestReady",  {0.30, 0.92, 0.30, 1}, 106},
                    [FieldGroundType.HARVEST_READY_OTHER] = {"ui_fpm_gt_harvestReady",  {0.30, 0.92, 0.30, 1}, 106},
                }
                if gt ~= nil then
                    local info = GT_INFO[gt]
                    if info ~= nil then
                        return g_i18n:getText(info[1]), info[2], info[3], "—"
                    end
                end
            end
        end
        return groundLabel, {0.55, 0.55, 0.55, 1}, -1, "—"
    end

    local ft = g_fruitTypeManager:getFruitTypeByIndex(ftIdx)
    if ft == nil then return "—", {0.4,0.4,0.4,1}, 0, "—" end

    local fruitName = (ft.fillType ~= nil)
        and (ft.fillType.title or ft.name) or (ft.name or "?")

    local minHarvest  = ft.minHarvestingGrowthState
    local maxHarvest  = ft.maxHarvestingGrowthState
    local maxGrowing  = minHarvest - 1
    -- withered ist maxHarvestingGrowthState + 1 (FarmlandOverview)
    local withered    = maxHarvest + 1

    if ft.minPreparingGrowthState ~= nil and ft.minPreparingGrowthState >= 0 then
        maxGrowing = math.min(maxGrowing, ft.minPreparingGrowthState - 1)
    end
    if ft.maxPreparingGrowthState ~= nil and ft.maxPreparingGrowthState >= 0 then
        withered = ft.maxPreparingGrowthState + 1
    end

    local stateText, stateColor, sortKey

    if growthState == ft.cutState then
        stateText  = "Abgeerntet"
        stateColor = {0.8, 0.5, 0.2, 1}
        sortKey    = 70
    elseif growthState >= withered then
        -- Überreif/Vertrocknet - alles ÜBER maxHarvest
        stateText  = "Vertrocknet"
        stateColor = {0.8, 0.2, 0.2, 1}
        sortKey    = 60
    elseif growthState > 0 and growthState <= maxGrowing then
        stateText  = string.format("Im Wachstum (%d/%d)", growthState, maxHarvest)
        stateColor = {0.75, 0.75, 0.75, 1}
        sortKey    = growthState
    elseif ft.minPreparingGrowthState ~= nil
        and ft.minPreparingGrowthState >= 0
        and ft.minPreparingGrowthState <= growthState
        and growthState <= (ft.maxPreparingGrowthState or 0) then
        stateText  = string.format("Im Wachstum (%d/%d)", growthState, maxHarvest)
        stateColor = {0.75, 0.75, 0.75, 1}
        sortKey    = growthState
    elseif minHarvest <= growthState and growthState <= maxHarvest then
        -- Erntreif!
        stateText = string.format("Erntreif (%d/%d)", growthState, maxHarvest)
        stateColor = growthState >= maxHarvest
            and {0.3, 0.92, 0.3, 1} or {1.0, 1.0, 0.2, 1}
        sortKey = 51 + growthState
    else
        -- Fallback
        stateText  = string.format("(%d/%d)", growthState, maxHarvest)
        stateColor = {0.6, 0.6, 0.6, 1}
        sortKey    = growthState
    end

    return stateText, stateColor, sortKey, fruitName
end

---------------------------------------------------------------------------
-- Daten sammeln
---------------------------------------------------------------------------
function InGameMenuFPM:collectData()
    self.fieldData = {}
    if g_farmlandManager == nil then return end

    local myFarmId = g_localPlayer ~= nil and g_localPlayer.farmId
                     or (g_currentMission ~= nil and g_currentMission:getFarmId() or -1)

    -- Debug: BC-Settings + npcJobs einmal ausgeben
    if not InGameMenuFPM._debugDone then
        InGameMenuFPM._debugDone = true
        local cfg = self:getBCSettings()
        print(string.format("[FPM] BC-Settings=%s isMPClient=%s",
            cfg == false and "no data" or string.format("perJob=%.3f maxJobs=%d", cfg.perJob, cfg.maxJobs),
            tostring(self:isMPClient())))
        local farm = g_farmManager ~= nil and g_farmManager:getFarmById(myFarmId) or nil
        local jobs = farm ~= nil and farm.stats ~= nil and farm.stats.npcJobs or nil
        print(string.format("[FPM] myFarmId=%s farm=%s npcJobs=%s",
            tostring(myFarmId), tostring(farm ~= nil), tostring(jobs ~= nil)))
        if jobs ~= nil then
            for k,v in pairs(jobs) do
                print(string.format("[FPM]   npcJobs[%s]=%s", tostring(k), tostring(v)))
            end
        end
    end

    for _, farmland in pairs(g_farmlandManager.farmlands) do
        local ownerId = g_farmlandManager:getFarmlandOwner(farmland.id)
        local isMine  = (ownerId == myFarmId)

        if farmland.showOnFarmlandsScreen and not isMine then

            local isOwned = (ownerId ~= nil and ownerId > 0
                             and ownerId ~= FarmManager.SPECTATOR_FARM_ID)

            local price = farmland.price or 0
            local discount, discountAmt, discStatus = self:getDiscount(farmland, price, myFarmId)
            local netPrice = math.max(0, price - discountAmt)
            local area = farmland.areaInHa or 0

            local stateText    = "—"
            local stateColor   = {0.4, 0.4, 0.4, 1}
            local stateSortKey = -1
            local fruitName    = "—"
            local fieldX, fieldZ = nil, nil

            local field = farmland.field or self.fieldByFarmlandId[farmland.id]
            if field ~= nil then
                fieldX, fieldZ = field:getCenterOfFieldWorldPosition()
            elseif farmland.xWorldPos ~= nil then
                fieldX = farmland.xWorldPos
                fieldZ = farmland.zWorldPos
            end
            if fieldX ~= nil and fieldZ ~= nil then
                stateText, stateColor, stateSortKey, fruitName =
                    self:getGrowthInfo(fieldX, fieldZ, field)
            end

            local ownerName = self:getOwnerName(farmland, ownerId, myFarmId)
            local num = tonumber(farmland.name) or farmland.id

            table.insert(self.fieldData, {
                num          = num,
                name         = farmland.name or tostring(farmland.id),
                area         = area,
                price        = price,
                discount     = discount,
                discStatus   = discStatus,
                netPrice     = netPrice,
                fruitName    = fruitName,
                stateText    = stateText,
                stateColor   = stateColor,
                stateSortKey = stateSortKey,
                owner        = ownerName,
                isOwned      = isOwned,
                fieldX       = fieldX,
                fieldZ       = fieldZ,
                farmlandId   = farmland.id,
                hasNpc       = (farmland.npcIndex ~= nil),
            })
        end
    end

    print(string.format("[FPM] %d Farmlands geladen", #self.fieldData))
end

---------------------------------------------------------------------------
-- Besitzer
---------------------------------------------------------------------------
function InGameMenuFPM:getOwnerName(farmland, ownerId, myFarmId)
    if ownerId == nil or ownerId <= 0
    or ownerId == FarmManager.SPECTATOR_FARM_ID then
        if farmland.npcIndex ~= nil and g_npcManager ~= nil then
            local npc = g_npcManager:getNPCByIndex(farmland.npcIndex)
            if npc ~= nil and npc.title ~= nil then return npc.title end
        end
        return self.i18n:getText("ui_fpm_ownerFree") or "Frei"
    end
    if ownerId == myFarmId then
        return self.i18n:getText("ui_fpm_ownerYou") or "Ich"
    end
    if g_farmManager ~= nil then
        local farm = g_farmManager:getFarmById(ownerId)
        if farm ~= nil then return farm.name or ("Farm "..tostring(ownerId)) end
    end
    return "Farm "..tostring(ownerId)
end

---------------------------------------------------------------------------
-- Sortieren
---------------------------------------------------------------------------
function InGameMenuFPM:sortData()
    local col  = self.sortColumn
    local desc = self.sortDesc
    table.sort(self.fieldData, function(a, b)
        local va, vb
        if     col == SORT_ID       then va = a.num;          vb = b.num
        elseif col == SORT_AREA     then va = a.area;         vb = b.area
        elseif col == SORT_PRICE    then va = a.price;        vb = b.price
        elseif col == SORT_DISCOUNT then va = a.price - a.netPrice; vb = b.price - b.netPrice
        elseif col == SORT_NET      then va = a.netPrice;     vb = b.netPrice
        elseif col == SORT_STATE    then va = a.stateSortKey; vb = b.stateSortKey
        elseif col == SORT_FRUIT    then va = a.fruitName;    vb = b.fruitName
        elseif col == SORT_OWNER    then va = a.owner;        vb = b.owner
        else                             va = a.netPrice;     vb = b.netPrice
        end
        if desc then return va > vb else return va < vb end
    end)
end

---------------------------------------------------------------------------
-- SmoothList DataSource
---------------------------------------------------------------------------
function InGameMenuFPM:getNumberOfSections(list)          return 1 end
function InGameMenuFPM:getTitleForSectionHeader(list, s)  return nil end
function InGameMenuFPM:getNumberOfItemsInSection(list, s) return #self.fieldData end

---------------------------------------------------------------------------
-- SmoothList Delegate
---------------------------------------------------------------------------
function InGameMenuFPM:populateCellForItemInSection(list, section, index, cell)
    local d = self.fieldData[index]
    if d == nil then return end

    cell:getAttribute("cellId"):setText(d.name)
    cell:getAttribute("cellArea"):setText(string.format("%.2f ha", d.area))
    cell:getAttribute("cellPrice"):setText(
        d.price > 0 and self.i18n:formatMoney(d.price, 0) or "---")

    -- Rabatt
    local discCell = cell:getAttribute("cellDiscount")
    if d.discStatus == "host" then
        -- MP-Client: Rabatt nur auf Host bekannt
        if d.hasNpc then
            discCell:setText("nur Host")
        else
            discCell:setText("—")
        end
        discCell:setTextColor(0.5, 0.5, 0.5, 0.5)
    elseif d.discStatus == "no data" then
        if d.hasNpc then
            discCell:setText("no data")
        else
            discCell:setText("—")
        end
        discCell:setTextColor(0.5, 0.5, 0.5, 0.5)
    elseif d.discount > 0 then
        local discAmt = d.price - d.netPrice
        discCell:setText(string.format("%s  -%d%%",
            self.i18n:formatMoney(discAmt, 0), d.discount))
        discCell:setTextColor(0.95, 0.5, 0.1, 1.0)
    else
        discCell:setText("—")
        discCell:setTextColor(0.4, 0.4, 0.4, 0.6)
    end

    -- Nettopreis
    local netCell = cell:getAttribute("cellNet")
    netCell:setText(d.netPrice > 0 and self.i18n:formatMoney(d.netPrice, 0) or "---")
    netCell:setTextColor(d.isOwned
        and 0.5 or 0.3, d.isOwned and 0.5 or 0.92, d.isOwned and 0.5 or 0.3, 1.0)

    -- Zustand
    local stateCell = cell:getAttribute("cellState")
    stateCell:setText(d.stateText)
    stateCell:setTextColor(
        d.stateColor[1], d.stateColor[2], d.stateColor[3], d.stateColor[4])

    -- Frucht
    local fruitCell = cell:getAttribute("cellFruit")
    fruitCell:setText(d.fruitName)
    fruitCell:setTextColor(
        d.fruitName ~= "—" and 0.85 or 0.35,
        d.fruitName ~= "—" and 0.85 or 0.35,
        d.fruitName ~= "—" and 0.85 or 0.35, 1.0)

    -- Besitzer
    local ownerCell = cell:getAttribute("cellOwner")
    ownerCell:setText(d.owner)
    ownerCell:setTextColor(
        d.isOwned and 0.7 or 0.7,
        d.isOwned and 0.75 or 0.85,
        d.isOwned and 0.9 or 1.0, 1.0)
end

---------------------------------------------------------------------------
-- Selektion geändert → Warp-Button aktivieren/deaktivieren
---------------------------------------------------------------------------
function InGameMenuFPM:onListSelectionChanged(list, section, index)
    local d = self.fieldData[index]
    self.warpButtonInfo.disabled = (d == nil or d.fieldX == nil)
    self:setMenuButtonInfoDirty()
end

---------------------------------------------------------------------------
-- Warp zum Feld - exakt nach FarmlandOverview
---------------------------------------------------------------------------
function InGameMenuFPM:onClickWarp()
    local index = self.priceTable.selectedIndex
    if index == nil or index <= 0 then return end
    local d = self.fieldData[index]
    if d == nil or d.fieldX == nil then return end

    local warpX = d.fieldX
    local warpZ = d.fieldZ
    local warpY = getTerrainHeightAtWorldPos(
        g_currentMission.terrainRootNode, warpX, 0, warpZ)

    -- GUI schließen (exakt wie FarmlandOverview)
    g_gui:showGui("")

    -- Fahrzeug verlassen falls nötig (exakt wie FarmlandOverview)
    if g_localPlayer ~= nil and g_localPlayer:getCurrentVehicle() ~= nil then
        g_localPlayer:leaveVehicle()
    end

    g_localPlayer:teleportTo(warpX, warpY + 1.2, warpZ, false, false)
end

---------------------------------------------------------------------------
-- Header-Klicks
---------------------------------------------------------------------------
function InGameMenuFPM:onClickSort(col)
    if self.sortColumn == col then
        self.sortDesc = not self.sortDesc
    else
        self.sortColumn = col
        self.sortDesc   = (col == SORT_NET or col == SORT_PRICE
                           or col == SORT_DISCOUNT or col == SORT_AREA)
    end
    self:sortData()
    self.priceTable:reloadData()
end

function InGameMenuFPM:onClickSortId()       self:onClickSort(SORT_ID)       end
function InGameMenuFPM:onClickSortArea()     self:onClickSort(SORT_AREA)     end
function InGameMenuFPM:onClickSortPrice()    self:onClickSort(SORT_PRICE)    end
function InGameMenuFPM:onClickSortDiscount() self:onClickSort(SORT_DISCOUNT) end
function InGameMenuFPM:onClickSortNet()      self:onClickSort(SORT_NET)      end
function InGameMenuFPM:onClickSortState()    self:onClickSort(SORT_STATE)    end
function InGameMenuFPM:onClickSortFruit()    self:onClickSort(SORT_FRUIT)    end
function InGameMenuFPM:onClickSortOwner()    self:onClickSort(SORT_OWNER)    end
