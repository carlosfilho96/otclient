-- @docclass
UIResizeBorder = extends(UIWidget, 'UIResizeBorder')

function UIResizeBorder.create()
    local resizeborder = UIResizeBorder.internalCreate()
    resizeborder:setFocusable(false)
    resizeborder.minimum = 0
    resizeborder.maximum = 1000
    return resizeborder
end

function UIResizeBorder:onSetup()
    if self.edge then
        if self.edge == 'right' or self.edge == 'left' then
            self.cursortype = 'horizontal'
            self.vertical = false
        elseif self.edge == 'top' or self.edge == 'bottom' then
            self.cursortype = 'vertical'
            self.vertical = true
        elseif self.edge == 'topleft' or self.edge == 'bottomright' then
            self.cursortype = 'diagonal1'
        elseif self.edge == 'topright' or self.edge == 'bottomleft' then
            self.cursortype = 'diagonal2'
        end
    elseif self:getWidth() > self:getHeight() then
        self.vertical = true
        self.cursortype = 'vertical'
    else
        self.vertical = false
        self.cursortype = 'horizontal'
    end
end

function UIResizeBorder:onDestroy()
    if self.hovering then
        -- Restore cursor when widget is destroyed while hovering
        if modules.client_options and modules.client_options.getOption('nativeCursor') then
            g_window.restoreMouseCursor()
        else
            g_mouse.popCursor(self.cursortype)
            g_window.restoreMouseCursor()
        end
    end
end

function UIResizeBorder:onHoverChange(hovered)
    if hovered then
        local nativeCursor = modules.client_options and modules.client_options.getOption('nativeCursor')
        
        -- Check isCursorChanged only when NOT using native cursor
        if not nativeCursor and (g_mouse.isCursorChanged() or g_mouse.isPressed()) then
            return
        end
        
        if self.edge then
            if self.edge == 'right' or self.edge == 'left' then
                self.cursortype = 'horizontal'
                self.vertical = false
            elseif self.edge == 'top' or self.edge == 'bottom' then
                self.cursortype = 'vertical'
                self.vertical = true
            elseif self.edge == 'topleft' or self.edge == 'bottomright' then
                self.cursortype = 'diagonal1'
            elseif self.edge == 'topright' or self.edge == 'bottomleft' then
                self.cursortype = 'diagonal2'
            end
        else
            if self:getWidth() > self:getHeight() then
                self.vertical = true
                self.cursortype = 'vertical'
            else
                self.vertical = false
                self.cursortype = 'horizontal'
            end
        end
        
        -- Use native cursor when enabled, otherwise try custom then native fallback
        if nativeCursor then
            g_window.setSystemCursor(self.cursortype)
        else
            if not g_mouse.pushCursor(self.cursortype) then
                g_window.setSystemCursor(self.cursortype)
            end
        end
        
        self.hovering = true
        if not self:isPressed() then
            g_effects.fadeIn(self)
        end
    else
        if not self:isPressed() and self.hovering then
            -- Restore cursor when hovering ends
            if modules.client_options and modules.client_options.getOption('nativeCursor') then
                g_window.restoreMouseCursor()
            else
                g_mouse.popCursor(self.cursortype)
                g_window.restoreMouseCursor()
            end
            g_effects.fadeOut(self)
            self.hovering = false
        end
    end
end

function UIResizeBorder:onMouseMove(mousePos, mouseMoved)
    if self:isPressed() then
        local parent = self:getParent()
        if not parent then
            return false
        end

        local edge = self.edge
        if not edge then
            local newSize = 0
            if self.vertical then
                local delta = mousePos.y - self:getY() - self:getHeight() / 2
                newSize = math.min(math.max(parent:getHeight() + delta, self.minimum), self.maximum)
                if self:getAnchorType(AnchorBottom) ~= AnchorNone then
                    newSize = math.min(math.max(parent:getHeight() + delta, self.minimum), self.maximum)
                elseif self:getAnchorType(AnchorTop) ~= AnchorNone then
                    newSize = math.min(math.max(parent:getHeight() - delta, self.minimum), self.maximum)
                end
                parent:setHeight(newSize)
            else
                local delta = mousePos.x - self:getX() - self:getWidth() / 2
                newSize = math.min(math.max(parent:getWidth() + delta, self.minimum), self.maximum)
                if self:getAnchorType(AnchorRight) ~= AnchorNone then
                    newSize = math.min(math.max(parent:getWidth() + delta, self.minimum), self.maximum)
                elseif self:getAnchorType(AnchorLeft) ~= AnchorNone then
                    newSize = math.min(math.max(parent:getWidth() - delta, self.minimum), self.maximum)
                end
                parent:setWidth(newSize)
            end

            self:checkBoundary(newSize)
            return true
        end

        -- Edge / Corner resize logic
        if not self.startMousePos or not self.startParentRect then
            self.startMousePos = { x = mousePos.x, y = mousePos.y }
            self.startParentRect = {
                x = parent:getX(),
                y = parent:getY(),
                width = parent:getWidth(),
                height = parent:getHeight()
            }
        end

        local deltaX = mousePos.x - self.startMousePos.x
        local deltaY = mousePos.y - self.startMousePos.y
        local start = self.startParentRect
        local minW = self.minimum or 120
        local maxW = self.maximum or 2000
        local minH = self.minimum or 120
        local maxH = self.maximum or 2000

        if edge == 'right' then
            local newW = math.min(math.max(start.width + deltaX, minW), maxW)
            parent:setWidth(newW)
        elseif edge == 'bottom' then
            local newH = math.min(math.max(start.height + deltaY, minH), maxH)
            parent:setHeight(newH)
        elseif edge == 'left' then
            local newW = math.min(math.max(start.width - deltaX, minW), maxW)
            local actualDeltaX = start.width - newW
            parent:setX(start.x + actualDeltaX)
            parent:setWidth(newW)
        elseif edge == 'top' then
            local newH = math.min(math.max(start.height - deltaY, minH), maxH)
            local actualDeltaY = start.height - newH
            parent:setY(start.y + actualDeltaY)
            parent:setHeight(newH)
        elseif edge == 'bottomright' then
            local newW = math.min(math.max(start.width + deltaX, minW), maxW)
            local newH = math.min(math.max(start.height + deltaY, minH), maxH)
            parent:setWidth(newW)
            parent:setHeight(newH)
        elseif edge == 'bottomleft' then
            local newW = math.min(math.max(start.width - deltaX, minW), maxW)
            local actualDeltaX = start.width - newW
            local newH = math.min(math.max(start.height + deltaY, minH), maxH)
            parent:setX(start.x + actualDeltaX)
            parent:setWidth(newW)
            parent:setHeight(newH)
        elseif edge == 'topright' then
            local newW = math.min(math.max(start.width + deltaX, minW), maxW)
            local newH = math.min(math.max(start.height - deltaY, minH), maxH)
            local actualDeltaY = start.height - newH
            parent:setY(start.y + actualDeltaY)
            parent:setWidth(newW)
            parent:setHeight(newH)
        elseif edge == 'topleft' then
            local newW = math.min(math.max(start.width - deltaX, minW), maxW)
            local actualDeltaX = start.width - newW
            local newH = math.min(math.max(start.height - deltaY, minH), maxH)
            local actualDeltaY = start.height - newH
            parent:setX(start.x + actualDeltaX)
            parent:setY(start.y + actualDeltaY)
            parent:setWidth(newW)
            parent:setHeight(newH)
        end

        return true
    end
end

function UIResizeBorder:onMouseRelease(mousePos, mouseButton)
    if self.startParentRect then
        local parent = self:getParent()
        if parent and parent.saveParent then
            parent:saveParent(parent:getParent())
        end
    end
    self.startMousePos = nil
    self.startParentRect = nil

    if not self:isHovered() then
        -- Restore cursor when mouse is released outside the border
        if modules.client_options and modules.client_options.getOption('nativeCursor') then
            g_window.restoreMouseCursor()
        else
            g_mouse.popCursor(self.cursortype)
            g_window.restoreMouseCursor()
        end
        g_effects.fadeOut(self)
        self.hovering = false
    end
end

function UIResizeBorder:onStyleApply(styleName, styleNode)
    for name, value in pairs(styleNode) do
        if name == 'maximum' then
            self:setMaximum(tonumber(value))
        elseif name == 'minimum' then
            self:setMinimum(tonumber(value))
        elseif name == 'edge' then
            self.edge = tostring(value)
            if self.edge == 'right' or self.edge == 'left' then
                self.cursortype = 'horizontal'
                self.vertical = false
            elseif self.edge == 'top' or self.edge == 'bottom' then
                self.cursortype = 'vertical'
                self.vertical = true
            elseif self.edge == 'topleft' or self.edge == 'bottomright' then
                self.cursortype = 'diagonal1'
            elseif self.edge == 'topright' or self.edge == 'bottomleft' then
                self.cursortype = 'diagonal2'
            end
        end
    end
end

function UIResizeBorder:onVisibilityChange(visible)
    if visible and self.maximum == self.minimum then
        self:hide()
    end
end

function UIResizeBorder:setMaximum(maximum)
    self.maximum = maximum
    self:checkBoundary()
end

function UIResizeBorder:setMinimum(minimum)
    self.minimum = minimum
    self:checkBoundary()
end

function UIResizeBorder:getMaximum()
    return self.maximum
end
function UIResizeBorder:getMinimum()
    return self.minimum
end

function UIResizeBorder:setParentSize(size)
    local parent = self:getParent()
    if self.vertical then
        parent:setHeight(size)
    else
        parent:setWidth(size)
    end
    self:checkBoundary(size)
end

function UIResizeBorder:getParentSize()
    local parent = self:getParent()
    if self.vertical then
        return parent:getHeight()
    else
        return parent:getWidth()
    end
end

function UIResizeBorder:checkBoundary(size)
    size = size or self:getParentSize()
    if self.maximum == self.minimum and size == self.maximum then
        self:hide()
    else
        self:show()
    end
end
