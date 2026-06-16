-- FieldPriceMonitor.lua
-- Pattern: FS25_TSStockCheckEDIT_modified - 1:1 Kopie von fixInGameMenu

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
-- fixInGameMenu - 1:1 von STT/Courseplay, kein eigener Code
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

addModEventListener(FieldPriceMonitor)
