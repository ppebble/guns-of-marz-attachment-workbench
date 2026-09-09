require "ISUI/ISCollapsableWindow"
require "ISUI/ISScrollingListBox"
require "ISUI/ISButton"
local M = require "GMAW/Model"
local P = require "GMAW/Planner"
local S = require "GMAW/Sources"
local V = require "GMAW/Presentation"
require "GMAW/Actions"
-- Do not retain require()'s transient nil during PZ client-script loading.
local A = GMAWActions
local W = ISCollapsableWindow:derive("GMAWWindow")
GMAWWindows = GMAWWindows or {}
local function tr(key) return getText("IGUI_GMAW_" .. key) end

local function fit(text, width)
    local clipped = text
    while #clipped > 0 and getTextManager():MeasureStringX(UIFont.Small, clipped .. "...") > width do
        local i = #clipped
        while i > 1 and clipped:byte(i) >= 128 and clipped:byte(i) < 192 do i = i - 1 end
        clipped = clipped:sub(1, i - 1)
    end
    return clipped == text and text or clipped .. "..."
end

local function icon(list, item, x, y, size, dim)
    local texture = item and item:getTex()
    list:drawRect(x, y, size, size, 0.45, 0.08, 0.08, 0.08)
    if texture then
        local shade = dim and 0.4 or 1
        list:drawTextureScaledAspect(texture, x + 3, y + 3, size - 6, size - 6,
            dim and 0.5 or 1, shade, shade, shade)
    else list:drawText("-", x + size / 2 - 3, y + size / 2 - 8, 0.5, 0.5, 0.5, 1, UIFont.Small) end
end

local function toolTexture(item, fallback)
    if item and item:getTex() then return item:getTex() end
    return getTexture and getTexture(fallback) or nil
end

local function frame(list, y, selected)
    local width = list.width - 16
    list:drawRect(2, y + 2, width - 4, list.itemheight - 5, 0.8, 0.12, 0.12, 0.12)
    list:drawRectBorder(2, y + 2, width - 4, list.itemheight - 5, 0.9,
        selected and 0.95 or 0.3, selected and 0.6 or 0.3, selected and 0.15 or 0.3)
    return width
end

local function visible(list, y)
    local scroll = list:getYScroll() or 0
    return y + scroll + list.itemheight >= 0 and y + scroll < list.height
end

local function drawItem(list, y, row)
    if not visible(list, y) then return y + list.itemheight end
    local d = row.item
    local width = frame(list, y, row.index == list.selected)
    local shade = d.dim and 0.45 or 0.95
    icon(list, d.item, 8, y + 8, 48, d.dim)
    list:drawText(fit(row.text, width - 70), 64, y + 9, shade, shade, shade, 1, UIFont.Small)
    local green = not d.dim and (d.current or (d.quantity and d.quantity > 0))
    list:drawText(fit(d.subtitle or "", width - 70), 64, y + 32,
        green and 0.4 or shade, green and 0.95 or shade, green and 0.3 or shade, 1, UIFont.Small)
    return y + list.itemheight
end

local function drawSlot(list, y, row)
    if not visible(list, y) then return y + list.itemheight end
    local d = row.item
    local width = frame(list, y, row.index == list.selected)
    list:drawText(fit(tr("Slot_" .. d.slot), width - 52), 10, y + 8, 0.9, 0.9, 0.9, 1, UIFont.Small)
    -- Installed-part removal; the rest of the card selects compatible options.
    local arrowShade = d.installed and not list.target.pending and 0.9 or 0.35
    list:drawRectBorder(width - 34, y + 7, 24, 24, 1, arrowShade, arrowShade, arrowShade)
    list:drawText("-", width - 26, y + 9, arrowShade, arrowShade, arrowShade, 1, UIFont.Small)
    icon(list, d.installed, 10, y + 36, 48, false)
    list:drawText(fit(d.installed and d.installed:getName() or tr("Empty"), width - 78),
        66, y + 37, 0.95, 0.95, 0.95, 1, UIFont.Small)
    list:drawText(tr("Installed"), 66, y + 60, 0.55, 0.65, 0.55, 1, UIFont.Small)
    if d.queued then
        icon(list, d.queued, 12, y + 91, 26, false)
        list:drawText(fit(tr(d.automatic and "AutoQueued" or "Queued") .. ": " .. d.queued:getName(), width - 54),
            44, y + 96, 0.95, 0.75, 0.3, 1, UIFont.Small)
    end
    return y + list.itemheight
end

function W:createChildren()
    ISCollapsableWindow.createChildren(self)
    local function list(x, y, width, height, rowHeight, draw)
        local box = ISScrollingListBox:new(x, y, width, height)
        box:initialise(); box:instantiate()
        box.itemheight = rowHeight
        box.doDrawItem = draw
        self:addChild(box)
        return box
    end
    local usable = self.width - 40
    self.leftWidth = math.floor(usable * 0.24)
    self.middleWidth = math.floor(usable * 0.39)
    self.middleX = 20 + self.leftWidth
    self.optionsX = self.middleX + self.middleWidth + 10
    self.optionsWidth = self.width - self.optionsX - 10
    self.mountWidth = math.floor((self.optionsWidth - 6) / 2)
    self.partsX = self.optionsX + self.mountWidth + 6
    -- Reserve a compact tool-status strip between the lists and cart.
    local height = self.height - 306
    self.toolY = 66 + height + 6
    self.weapons = list(10, 66, self.leftWidth, height, 66, drawItem)
    self.slots = list(self.middleX, 66, self.middleWidth, height, 124, drawSlot)
    self.mounts = list(self.optionsX, 66, self.mountWidth, height, 66, drawItem)
    self.parts = list(self.partsX, 66, self.optionsWidth - self.mountWidth - 6, height, 66, drawItem)
    self.cart = list(10, self.height - 152, self.width - 20, 100, 66, drawItem)
    self.weapons:setOnMouseDownFunction(self, W.selectWeapon)
    self.slots:setOnMouseDownFunction(self, W.selectSlot)
    self.slots:setOnMouseDoubleClick(self, W.removePart)
    self.slots.onMouseDown = function(box, x, y)
        local index = box:rowAt(x, y)
        local row = box.items[index]
        local rowY = (index - 1) * box.itemheight
        if row and x >= box.width - 50 and x <= box.width - 26
            and y >= rowY + 7 and y <= rowY + 31 then
            self:removePart(row.item)
            return true
        end
        return ISScrollingListBox.onMouseDown(box, x, y)
    end
    self.mounts:setOnMouseDownFunction(self, W.choosePart)
    self.parts:setOnMouseDownFunction(self, W.choosePart)
    local function button(x, width, key, callback)
        local b = ISButton:new(x, self.height - 42, width, 26, tr(key), self, callback)
        b:initialise(); b:instantiate(); self:addChild(b)
        return b
    end
    self.applyButton = button(10, 150, "Apply", W.apply)
    self.refreshButton = button(170, 120, "Refresh", W.reload)
    self.clearButton = button(300, 120, "Clear", W.clear)
    button(self.width - 130, 120, "Close", W.close)
    self:reload()
end

function W:refreshTools(scan)
    scan = scan or S.scan(self.player)
    self.screwdriver = S.firstWorkingTag(scan, {ItemTag and ItemTag.SCREWDRIVER})
    self.wrench = S.firstWorkingTag(scan, {ItemTag and ItemTag.WRENCH, ItemTag and ItemTag.PIPE_WRENCH})
end

function W:resetView(code)
    self.target, self.plan, self.choices, self.activeSlot = nil, nil, {}, nil
    self.slots:clear(); self.mounts:clear(); self.parts:clear(); self.cart:clear()
    self.applyButton:setEnable(false); self.status = tr(code)
end

function W:selectWeapon(entry)
    if self.pending then return end
    self.target, self.choices, self.plan, self.activeSlot = entry, {}, nil, nil
    self.expected = M.fingerprint(entry.item)
    local ok, catalog = pcall(M.candidates, entry.item)
    if not ok then self:resetView("Unsupported"); return end
    self.catalog = catalog
    self.status = tr("Hint")
    for i, row in ipairs(self.weapons.items) do if row.item == entry then self.weapons.selected = i end end
    self:rebuild()
end

function W:reload()
    if self.pending then return end
    local wanted = self.target and self.target.item:getID() or self.initialID
    local ok, scan = pcall(S.scan, self.player)
    self.weapons:clear()
    if not ok then self:resetView("Unsupported"); return end
    self.scan = scan
    self:refreshTools(scan)
    local selection
    for _, entry in ipairs(scan.entries) do
        if M.supported(entry.item) then
            entry.subtitle = tr(entry.kind)
            self.weapons:addItem(entry.item:getName(), entry, entry.item:getName() .. " <LINE> " .. entry.subtitle)
            if entry.item:getID() == wanted then selection = entry end
        end
    end
    selection = selection or (self.weapons.items[1] and self.weapons.items[1].item)
    if selection then self:selectWeapon(selection) else self:resetView("NoWeapon") end
end

function W:choiceList(extra)
    return V.choices(self.choices, self.catalog, extra)
end

function W:selectSlot(card)
    if self.pending then return end
    self.activeSlot = card.slot
    self:showOptions()
end

function W:addOption(list, option)
    if option.current then option.subtitle = tr("Installed")
    elseif option.queued then option.subtitle = tr("Queued")
    elseif option.quantity == 0 then option.subtitle = tr("NotOwned")
    elseif option.dim then option.subtitle = tr(option.reason or "Unavailable")
    else option.subtitle = tr("Available") end
    option.subtitle = option.subtitle .. "  x" .. tostring(option.quantity)
    local c = self.catalog[option.fullType]
    local parents = {}
    for _, parent in ipairs(M.keys(c.all)) do parents[#parents + 1] = getItemNameFromFullType(parent) end
    for _, parent in ipairs(M.keys(c.any)) do parents[#parents + 1] = getItemNameFromFullType(parent) end
    local tooltip = option.item:getName() .. " <LINE> " .. option.subtitle .. " <LINE> " .. tr(M.toolKey(option.item))
    if #parents > 0 then tooltip = tooltip .. " <LINE> " .. tr("Requires") .. ": " .. table.concat(parents, "/") end
    list:addItem(option.item:getName(), option, tooltip)
    if option.queued or option.current then list.selected = #list.items end
end

function W:showMounts()
    self.mounts:clear()
    if not self.view then return end
    for _, fullType in ipairs(M.keys(self.catalog)) do
        if M.isMountCandidate(self.catalog, fullType) then
            local card = self.view.bySlot[self.catalog[fullType].slot]
            if card then
                for _, option in ipairs(card.options) do
                    if option.fullType == fullType then self:addOption(self.mounts, option); break end
                end
            end
        end
    end
end

function W:showOptions()
    self.parts:clear()
    local card = self.view and self.view.bySlot[self.activeSlot]
    if not card then return end
    for _, option in ipairs(card.options) do
        if not M.isMountCandidate(self.catalog, option.fullType) then self:addOption(self.parts, option) end
    end
end

function W:rebuild()
    if not self.target then return end
    local scroll = self.slots:getYScroll()
    self.slots:clear(); self.cart:clear()
    self.view = V.build(self.catalog, M.installed(self.target.item), M.availability(self.catalog, self.scan),
        self.choices, self.player, self.target.item, self.scan)
    self.plan, self.reason = self.view.plan, self.view.reason
    if not self.view.bySlot[self.activeSlot] then self.activeSlot = self.view.slots[1] and self.view.slots[1].slot end
    for _, card in ipairs(self.view.slots) do
        local tooltip = tr("Slot_" .. card.slot) .. " <LINE> " .. tr("Installed") .. ": "
            .. (card.installed and card.installed:getName() or tr("Empty"))
        if card.queued then tooltip = tooltip .. " <LINE> " .. tr("Queued") .. ": " .. card.queued:getName() end
        self.slots:addItem(tr("Slot_" .. card.slot), card, tooltip)
        if card.slot == self.activeSlot then self.slots.selected = #self.slots.items end
    end
    self.slots:setYScroll(scroll)
    self:showMounts()
    self:showOptions()
    for _, step in ipairs(self.plan or {}) do
        local name = self.catalog[step.fullType].part:getName()
        local subtitle = tr(step.source.kind)
        if step.old then subtitle = subtitle .. " / " .. tr("Replace") .. ": " .. step.old:getName() end
        self.cart:addItem(name, {item=self.catalog[step.fullType].part, subtitle=subtitle}, name .. " <LINE> " .. subtitle)
    end
    if not self.plan then self.status = tr(self.reason)
    elseif #self.view.slots == 0 then self.status = tr("NoSlots") end
    self.applyButton:setEnable(not self.pending and self.plan ~= nil and #self.plan > 0)
end

function W:choosePart(row)
    if self.pending or not row.fullType then return end
    local slot = self.catalog[row.fullType].slot
    if row.current or self.choices[slot] == row.fullType then self.choices[slot] = nil
    elseif row.dim then self.status = tr(row.reason or "Missing"); return
    else self.choices[slot] = row.fullType end
    self.status = tr("Hint")
    self:rebuild()
end

function W:clear()
    if self.pending then return end
    self.choices = {}; self.status = tr("Hint"); self:rebuild()
end

function W:removePart(card)
    if self.pending or not card or not card.installed or not self.target then return end
    local ok, queued, reason = pcall(A.remove, self.player, self.target, self.expected, card.slot)
    if not ok then self.status = tr("Unsupported"); return end
    if not queued then self.status = tr(reason); return end
    self.pending = true
    self.applyButton:setEnable(false)
    self.status = tr("ActionsQueued")
end

function W:apply()
    if self.pending or not self.plan or #self.plan == 0 then return end
    local ok, queued, reason = pcall(A.begin, self.player, self.target, self.expected,
        self:choiceList(), P.signature(self.plan))
    if not ok then self.status = tr("Unsupported"); return end
    if not queued then self.status = tr(reason); return end
    self.pending = true
    self.applyButton:setEnable(false)
    self.status = tr("ActionsQueued")
end

function W:update()
    ISCollapsableWindow.update(self)
    self.toolRefreshFrames = (self.toolRefreshFrames or 0) + 1
    if self.toolRefreshFrames >= 30 then
        self.toolRefreshFrames = 0
        self:refreshTools()
    end
    -- A stale/pre-reload window can outlive the Actions script briefly.
    -- Rebind the published API and skip this frame rather than error-looping.
    A = GMAWActions or A
    if not A then return end
    local code = A.poll(self.player)
    if code then self:result(code)
    elseif A.busy(self.player) then
        self.pending = true
        self.applyButton:setEnable(false)
        self.status = tr("ActionsQueued")
    end
end

function W:result(code)
    self.pending = false
    self:reload()
    self.status = tr(code)
end

function W:drawToolStatus(x, source, fallback)
    local available = source ~= nil
    local red = available and 0.3 or 0.95
    local green = available and 0.9 or 0.2
    self:drawRect(x, self.toolY, 28, 28, available and 0.45 or 0.65, 0.08, 0.08, 0.08)
    self:drawRectBorder(x, self.toolY, 28, 28, 1, red, green, 0.2)
    local texture = toolTexture(source and source.item, fallback)
    if texture then
        local shade = available and 1 or 0.35
        self:drawTextureScaledAspect(texture, x + 3, self.toolY + 3, 22, 22,
            available and 1 or 0.4, shade, shade, shade)
    end
end

function W:prerender()
    ISCollapsableWindow.prerender(self)
    self:drawText(tr("Weapons"), 10, 42, 1, 1, 1, 1, UIFont.Small)
    self:drawText(tr("Slots"), self.middleX, 42, 1, 1, 1, 1, UIFont.Small)
    self:drawText(fit(tr("Mounts"), self.mounts.width), self.optionsX, 42, 1, 1, 1, 1, UIFont.Small)
    local label = self.activeSlot and tr("Slot_" .. self.activeSlot) or tr("Options")
    self:drawText(fit(label, self.parts.width), self.partsX, 42, 1, 1, 1, 1, UIFont.Small)
    self:drawText(fit(self.status or tr("ChooseSlot"), self.width - 20), 10, self.height - 194, 1, 0.85, 0.5, 1, UIFont.Small)
    local toolsX = self.width - 72
    self:drawToolStatus(toolsX, self.screwdriver, "Item_Screwdriver")
    self:drawToolStatus(toolsX + 36, self.wrench, "Item_Wrench")
    self:drawText(tr("Cart"), 10, self.height - 174, 0.8, 0.8, 0.8, 1, UIFont.Small)
end

function W:close()
    for _, list in ipairs({self.weapons, self.slots, self.mounts, self.parts, self.cart}) do
        if list.tooltipUI then list.tooltipUI:setVisible(false); list.tooltipUI:removeFromUIManager() end
    end
    self:setVisible(false); self:removeFromUIManager()
    GMAWWindows[self.player:getPlayerNum()] = nil
end

function W.open(player, weapon)
    local number = player:getPlayerNum()
    if GMAWWindows[number] then GMAWWindows[number]:close() end
    local width = math.min(1120, getCore():getScreenWidth() - 30)
    local height = math.min(760, getCore():getScreenHeight() - 40)
    local o = W:new(15, 20, width, height)
    o.player, o.initialID = player, weapon:getID()
    o.title, o.resizable = tr("Title"), false
    o:initialise(); o:addToUIManager()
    GMAWWindows[number] = o
end

Events.OnFillInventoryObjectContextMenu.Add(function(number, context, items)
    if not M.enabled() then return end
    for _, selected in ipairs(items) do
        local item = instanceof(selected, "InventoryItem") and selected or (selected.items and selected.items[1])
        if M.supported(item) then
            context:addOption(tr("Open"), getSpecificPlayer(number), W.open, item)
            return
        end
    end
end)

return W
