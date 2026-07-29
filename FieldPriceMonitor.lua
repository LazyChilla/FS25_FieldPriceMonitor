-- FieldPriceMonitor.lua
-- Pattern: FS25_TSStockCheckEDIT_modified (fixInGameMenu, nach dem Vorbild neu implementiert)

FieldPriceMonitor = {}
FieldPriceMonitor.dir     = g_currentModDirectory
FieldPriceMonitor.modName = g_currentModName

-- InGameMenuFPM wird via modDesc.xml extraSourceFiles geladen!

---------------------------------------------------------------------------
-- loadMap: exakt nach STT Pattern
---------------------------------------------------------------------------
function FieldPriceMonitor:loadMap()
    local ok, err = pcall(function()
        g_gui:loadProfiles(FieldPriceMonitor.dir .. "gui/guiProfiles.xml")

        local frame = InGameMenuFPM.new(g_i18n)
        InGameMenuFPM.instance = frame  -- fuer g_farmCore-Export (analog Saatplan-Pattern)
        print("[FPM-DIAG] loadMap: InGameMenuFPM.instance gesetzt auf " .. tostring(frame))
        g_gui:loadGui(FieldPriceMonitor.dir .. "gui/InGameMenuFPM.xml", "ingameMenuFPM", frame, true)

        FieldPriceMonitor.fixInGameMenu(
            frame,
            "ingameMenuFPM",
            {0, 0, 1024, 1024},
            2,
            function() return true end
        )

        frame:initialize()
    end)
    if not ok then
        print("[FPM] FEHLER in loadMap: " .. tostring(err))
    else
        print("[FPM] loadMap erfolgreich!")
    end
end

---------------------------------------------------------------------------
-- fixInGameMenu - nach dem Vorbild von STT/Courseplay neu implementiert
---------------------------------------------------------------------------
function FieldPriceMonitor.fixInGameMenu(frame, pageName, uvs, position, predicateFunc)
    local inGameMenu = g_gui.screenControllers[InGameMenu]
    local abovePrices = 0

    -- controlID löschen um Warnings zu vermeiden
    for k, v in pairs({pageName}) do
        inGameMenu.controlIDs[v] = nil
    end

    -- Position von pageStatistics finden
    for i = 1, #inGameMenu.pagingElement.elements do
        local child = inGameMenu.pagingElement.elements[i]
        if child == inGameMenu["pageStatistics"] then
            abovePrices = i
        end
    end

    if abovePrices == 0 then
        abovePrices = position
    end

    inGameMenu[pageName] = frame
    inGameMenu.pagingElement:addElement(inGameMenu[pageName])
    inGameMenu:exposeControlsAsFields(pageName)

    -- elements umsortieren
    for i = 1, #inGameMenu.pagingElement.elements do
        local child = inGameMenu.pagingElement.elements[i]
        if child == inGameMenu[pageName] then
            table.remove(inGameMenu.pagingElement.elements, i)
            table.insert(inGameMenu.pagingElement.elements, abovePrices, child)
            break
        end
    end

    -- pages umsortieren (BUG FIX: child VOR remove speichern!)
    for i = 1, #inGameMenu.pagingElement.pages do
        local child = inGameMenu.pagingElement.pages[i]
        if child.element == inGameMenu[pageName] then
            table.remove(inGameMenu.pagingElement.pages, i)
            table.insert(inGameMenu.pagingElement.pages, abovePrices, child)
            break
        end
    end

    inGameMenu.pagingElement:updateAbsolutePosition()
    inGameMenu.pagingElement:updatePageMapping()

    inGameMenu:registerPage(inGameMenu[pageName], position, predicateFunc)

    local iconFileName = Utils.getFilename("images/menuIcon.png", FieldPriceMonitor.dir)
    inGameMenu:addPageTab(inGameMenu[pageName], iconFileName, GuiUtils.getUVs(uvs))

    -- pageFrames umsortieren
    for i = 1, #inGameMenu.pageFrames do
        local child = inGameMenu.pageFrames[i]
        if child == inGameMenu[pageName] then
            table.remove(inGameMenu.pageFrames, i)
            table.insert(inGameMenu.pageFrames, abovePrices, child)
            break
        end
    end

    inGameMenu:rebuildTabList()

    print("[FPM] ESC-Menü Tab erfolgreich registriert!")
end

---------------------------------------------------------------------------
-- Pflicht-Stubs
---------------------------------------------------------------------------
function FieldPriceMonitor:deleteMap()   end
function FieldPriceMonitor:onLoad()      end
function FieldPriceMonitor:onUpdate(dt)  end
function FieldPriceMonitor:keyEvent(unicode, sym, modifier, isDown) end
function FieldPriceMonitor:mouseEvent(posX, posY, isDown, isUp, button) end

-- ============================================================
--  g_farmCore Export (fuer FarmAssistant / Dachmod)
--  Kein Hard-Dependency: dieser Mod funktioniert genauso ohne
--  FarmCore-Mod installiert.
--
--  EINSCHRAENKUNG (verifiziert im Sourcecode):
--  Rabatt-Berechnung (getDiscount) liefert nur als HOST echte
--  Werte. Als reiner MP-Client kommt IMMER status="host_only"
--  zurueck -- das ist kein Bug, sondern Absicht im Original-Mod.
--
--  v1.0.0.2: Export berechnet fieldData selbst (buildFieldLookup +
--  collectData), unabhaengig davon ob der Tab je geoeffnet wurde.
-- ============================================================
g_farmCore = g_farmCore or { modules = {} }
g_farmCore.modules.fieldPriceMonitor = {

    -- Rueckgabe: fieldDataListe, status
    -- status ist einer von: "ok", "host_only"
    getFieldDiscounts = function()
        local frame = InGameMenuFPM.instance
        if frame == nil then return {}, "not_ready" end

        if frame:isMPClient() then
            return frame.fieldData or {}, "host_only"
        end

        -- Aktiv neu berechnen statt auf fieldData-Zustand zu vertrauen
        -- (Tab muss nicht geoeffnet gewesen sein)
        frame._bcSettings = nil  -- Cache zuruecksetzen
        local ok, err = pcall(function()
            frame:buildFieldLookup()
            frame:collectData()
        end)
        if not ok then
            print("[FPM] Fehler in getFieldDiscounts: " .. tostring(err))
            return {}, "not_ready"
        end

        return frame.fieldData, "ok"
    end,
}

addModEventListener(FieldPriceMonitor)
