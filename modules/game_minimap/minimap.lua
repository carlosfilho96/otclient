local iconTopMenu = nil
-- @ Minimap
local minimapWidget = nil -- bot fix
local otmm = true
local oldPos = nil
local fullscreenWidget
local virtualFloor = 7
local currentDayTime = {
    h = 12,
    m = 0
}

local function refreshVirtualFloors()
    if not mapController.ui or not mapController.ui.layersPanel then
        return
    end
    mapController.ui.layersPanel.layersMark:setMarginTop(((virtualFloor + 1) * 4) - 3)
    mapController.ui.layersPanel.automapLayers:setImageClip((virtualFloor * 14) .. ' 0 14 67')
end

local function onPositionChange()
    local player = g_game.getLocalPlayer()
    if not player then
        return
    end

    local pos = player:getPosition()
    if not pos then
        return
    end

    local minimapWidget = getMiniMapUi()
    if not (minimapWidget) or minimapWidget:isDragging() then
        return
    end

    if not minimapWidget.fullMapView then
        minimapWidget:setCameraPosition(pos)
    end

    minimapWidget:setCrossPosition(pos)
    virtualFloor = pos.z
    refreshVirtualFloors()
end

mapController = Controller:new()
mapController:setUI('minimap', modules.game_interface.getMainRightPanel())

function onChangeWorldTime(hour, minute)
--[[ 
check 
tfs c++ (old) : void ProtocolGame::sendWorldTime()
tfs lua (new) : function Player.sendWorldTime(self, time)
Canary: void ProtocolGame::sendTibiaTime(int32_t time)
]]

    currentDayTime = {
        h = hour % 24,
        m = minute
    }

    mapController:scheduleEvent(function()
        local nextH = currentDayTime.h
        local nextM = currentDayTime.m + 12
        if nextM >= 60 then
            nextH = nextH + 1
            nextM = nextM - 60
        end

        onChangeWorldTime(nextH, nextM)
    end, 30000, 'dayTime')

    if not mapController.ui or not mapController.ui.rosePanel or not mapController.ui.rosePanel.ambients then
        return
    end

    local position = math.floor((124 / (24 * 60)) * ((hour * 60) + minute))
    local mainWidth = 31
    local secondaryWidth = 0

    if (position + 31) >= 124 then
        secondaryWidth = ((position + 31) - 124) + 1
        mainWidth = 31 - secondaryWidth
    end

    mapController.ui.rosePanel.ambients.main:setWidth(mainWidth)
    mapController.ui.rosePanel.ambients.secondary:setWidth(secondaryWidth)

    if secondaryWidth == 0 then
        mapController.ui.rosePanel.ambients.secondary:hide()
    else
        mapController.ui.rosePanel.ambients.secondary:setImageClip('0 0 ' .. secondaryWidth .. ' 31')
        mapController.ui.rosePanel.ambients.secondary:show()
    end

    if mainWidth == 0 then
        mapController.ui.rosePanel.ambients.main:hide()
    else
        mapController.ui.rosePanel.ambients.main:setImageClip(position .. ' 0 ' .. mainWidth .. ' 31')
        mapController.ui.rosePanel.ambients.main:show()
    end
end

function mapController:onInit()
    self.ui:setup()
    self.ui.canDropAnywhere = true
    self.ui.moveOnlyToMain = false

    self.ui.minimapBorder = self.ui:recursiveGetChildById('minimapBorder')
    self.ui.layersPanel = self.ui:recursiveGetChildById('layersPanel')
    self.ui.rosePanel = self.ui:recursiveGetChildById('rosePanel')

    local minimap = getMiniMapUi()
    if minimap then
        local floorUpBtn = minimap:getChildById('floorUpButton')
        if floorUpBtn then floorUpBtn:hide() end
        local floorDownBtn = minimap:getChildById('floorDownButton')
        if floorDownBtn then floorDownBtn:hide() end
        local zoomInBtn = minimap:getChildById('zoomInButton')
        if zoomInBtn then zoomInBtn:hide() end
        local zoomOutBtn = minimap:getChildById('zoomOutButton')
        if zoomOutBtn then zoomOutBtn:hide() end
        local resetBtn = minimap:getChildById('resetButton')
        if resetBtn then resetBtn:hide() end
    end
end

function mapController:onGameStart()
    self.ui:setupOnStart()
    g_keyboard.bindKeyDown('Alt+M', toggleMinimap)

    mapController:registerEvents(g_game, {
        onChangeWorldTime = onChangeWorldTime
    })

    mapController:registerEvents(LocalPlayer, {
        onPositionChange = onPositionChange
    }):execute()

    -- Load Map
    g_minimap.clean()

    local minimapFile = '/minimap'
    local loadFnc = nil

    if otmm then
        minimapFile = minimapFile .. '.otmm'
        loadFnc = g_minimap.loadOtmm
    else
        minimapFile = minimapFile .. '_' .. g_game.getClientVersion() .. '.otcm'
        loadFnc = g_map.loadOtcm
    end

    if g_resources.fileExists(minimapFile) then
        loadFnc(minimapFile)
    end

    local minimap = getMiniMapUi()
    if minimap then
        minimap:load()
    end
end

function mapController:onGameEnd()
    g_keyboard.unbindKeyDown('Alt+M', toggleMinimap)

    -- Save Map
    if otmm then
        g_minimap.saveOtmm('/minimap.otmm')
    else
        g_map.saveOtcm('/minimap_' .. g_game.getClientVersion() .. '.otcm')
    end

    local minimap = getMiniMapUi()
    if minimap then
        minimap:save()
    end
end

function mapController:onTerminate()
    g_keyboard.unbindKeyDown('Alt+M', toggleMinimap)
    if iconTopMenu then
        iconTopMenu:destroy()
        iconTopMenu = nil
    end
end

function zoomIn()
    local minimap = getMiniMapUi()
    if minimap then
        minimap:zoomIn()
    end
end

function zoomOut()
    local minimap = getMiniMapUi()
    if minimap then
        minimap:zoomOut()
    end
end

function openCyclopediaMap()
    if g_game.getClientVersion() >= 1310 then
        modules.game_cyclopedia.toggle('map')
    else
        return fullscreen()
    end
end

function fullscreen()
    local minimapWidget = getMiniMapUi()
    if not minimapWidget then
        minimapWidget = fullscreenWidget
    end
    local zoom

    if not minimapWidget then
        return
    end

    if minimapWidget.fullMapView then
        fullscreenWidget = nil
        local border = mapController.ui:recursiveGetChildById('minimapBorder')
        if border then
            minimapWidget:setParent(border)
        else
            minimapWidget:setParent(mapController.ui:getChildById('contentsPanel') or mapController.ui)
        end
        minimapWidget:fill('parent')
        mapController.ui:show()
        zoom = minimapWidget.zoomMinimap
        g_keyboard.unbindKeyDown('Escape')
        minimapWidget.fullMapView = false
    else
        fullscreenWidget = minimapWidget
        mapController.ui:hide(true)
        minimapWidget:setParent(modules.game_interface.getRootPanel())
        minimapWidget:fill('parent')
        zoom = minimapWidget.zoomFullmap
        g_keyboard.bindKeyDown('Escape', fullscreen)
        minimapWidget.fullMapView = true
    end

    local pos = oldPos or minimapWidget:getCameraPosition()
    oldPos = minimapWidget:getCameraPosition()
    minimapWidget:setZoom(zoom)
    minimapWidget:setCameraPosition(pos)
end

function upLayer()
    if virtualFloor == 0 then
        return
    end

    local minimap = getMiniMapUi()
    if minimap then
        minimap:floorUp(1)
    end
    virtualFloor = virtualFloor - 1
    refreshVirtualFloors()
end

function downLayer()
    if virtualFloor == 15 then
        return
    end

    local minimap = getMiniMapUi()
    if minimap then
        minimap:floorDown(1)
    end
    virtualFloor = virtualFloor + 1
    refreshVirtualFloors()
end

function onClickRoseButton(dir)
    local minimap = getMiniMapUi()
    if not minimap then
        return
    end

    if dir == 'north' then
        minimap:move(0, 1)
    elseif dir == 'north-east' then
        minimap:move(-1, 1)
    elseif dir == 'east' then
        minimap:move(-1, 0)
    elseif dir == 'south-east' then
        minimap:move(-1, -1)
    elseif dir == 'south' then
        minimap:move(0, -1)
    elseif dir == 'south-west' then
        minimap:move(1, -1)
    elseif dir == 'west' then
        minimap:move(1, 0)
    elseif dir == 'north-west' then
        minimap:move(1, 1)
    end
end

function resetMap()
    local minimap = getMiniMapUi()
    if minimap then
        minimap:reset()
    end
    local player = g_game.getLocalPlayer()
    if player then
        virtualFloor = player:getPosition().z
        refreshVirtualFloors()
    end
end

function getMiniMapUi()
    if not mapController or not mapController.ui then
        return nil
    end
    local border = mapController.ui:recursiveGetChildById('minimapBorder')
    if border and border.minimap then
        return border.minimap
    end
    return mapController.ui:recursiveGetChildById('minimap')
end

function toggleMinimap()
    local ui = mapController and mapController.ui
    if not ui then
        return
    end

    if not ui:isVisible() then
        ui:open()
        if ui:isOn() then
            ui:maximize()
        end
    elseif ui:isOn() then
        ui:maximize()
    else
        ui:minimize()
    end
end

function extendedView(extendedView)
    if extendedView then
        if not iconTopMenu then
            iconTopMenu = modules.client_topmenu.addTopRightToggleButton('miniMap', tr('Show miniMap'),
                '/images/topbuttons/minimap', toggle)
            iconTopMenu:setOn(mapController.ui:isVisible())
            mapController.ui:setBorderColor('black')
            mapController.ui:setBorderWidth(2)
        end
    else
        if iconTopMenu then
            iconTopMenu:destroy()
            iconTopMenu = nil
        end
        mapController.ui:setBorderColor('alpha')
        mapController.ui:setBorderWidth(0)
        if not mapController.ui:getParent() then
            local mainRightPanel = modules.game_interface.getMainRightPanel()
            if not mainRightPanel:hasChild(mapController.ui) then
                mainRightPanel:insertChild(1, mapController.ui)
            end
        end
        mapController.ui:show()
    end
    mapController.ui.canDropAnywhere = true
    mapController.ui.moveOnlyToMain = false
end

function toggle()
    toggleMinimap()
    if iconTopMenu then
        iconTopMenu:setOn(mapController.ui:isVisible())
    end
end
