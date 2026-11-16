-- Settings: a page of its own in the game's Options > AddOns. A list of macros on the left, the
-- selected one on the right: its icon to drag to an action bar, name, spells, fallbacks and text.

local _, ns = ...
local L = ns.L

local Options = {}
ns.Options = Options

local Macro = ns.Macro
local Macros = ns.Macros
local Profile = ns.Profile

local LIST_WIDTH, LIST_HEIGHT, ROW_HEIGHT = 200, 330, 36
local EDITOR_X = 16 + LIST_WIDTH + 34
local GREEN, YELLOW, RED, GREY = "|cFF33DD33", "|cFFFFCC33", "|cFFFF4444", "|cFF999999"
local QUESTION_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

local STATUS_TEXT = {
	ok = GREEN .. L["in your macros: drag it to a bar"] .. "|r",
	new = YELLOW .. L["not created yet"] .. "|r",
	missing = YELLOW .. L["deleted from your macros"] .. "|r",
	empty = YELLOW .. L["no spells"] .. "|r",
	toolong = RED .. L["macro is too long"] .. "|r",
	full = RED .. L["no free macro slot"] .. "|r",
}

------------------------------------------------------------------------
-- Widget helpers
------------------------------------------------------------------------

local function Text(parent, text, template)
	local fontString = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
	fontString:SetJustifyH("LEFT")
	fontString:SetText(text or "")
	return fontString
end

local function Label(parent, text)
	return Text(parent, text, "GameFontNormalSmall")
end

local function Button(parent, text, width, onClick)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(width or 110, 22)
	button:SetText(text)
	button:SetScript("OnClick", onClick)
	return button
end

local function Check(parent, text, onClick)
	local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	check:SetSize(24, 24)
	check.Text:SetText(text)
	check:SetScript("OnClick", function(self)
		onClick(self:GetChecked() and true or false)
	end)
	return check
end

local function EditBox(parent, width, onCommit)
	local editBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	editBox:SetSize(width, 20)
	editBox:SetAutoFocus(false)
	editBox:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
	end)
	editBox:SetScript("OnEscapePressed", function(self)
		self.revert = true
		self:ClearFocus()
	end)
	editBox:SetScript("OnEditFocusLost", function(self)
		if self.revert then
			self.revert = nil
			Options:Refresh()
			return
		end
		onCommit(self:GetText())
	end)
	return editBox
end

-- Dropdown with radio entries: entries = { {text=, value=}, ... }
local function Dropdown(parent, width, entries, getValue, onSelect)
	local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
	dropdown:SetWidth(width)
	dropdown:SetupMenu(function(_, root)
		for _, entry in ipairs(entries) do
			root:CreateRadio(entry.text, function()
				return getValue() == entry.value
			end, function()
				onSelect(entry.value)
			end, entry.value)
		end
	end)
	return dropdown
end

-- Sets the text unless the user is typing in the box.
local function SetBoxText(editBox, text)
	if not editBox:HasFocus() then
		editBox:SetText(text or "")
	end
end

-- Older clients have no EditBox:SetEnabled.
local function SetWidgetEnabled(widget, enabled)
	if widget.SetEnabled then
		widget:SetEnabled(enabled)
	else
		widget:EnableMouse(enabled)
	end
	widget:SetAlpha(enabled and 1 or 0.4)
end

local function Confirm(text, onAccept)
	StaticPopupDialogs.DMOUSEOVERCASTS_CONFIRM = StaticPopupDialogs.DMOUSEOVERCASTS_CONFIRM or {
		text = "%s",
		button1 = YES,
		button2 = NO,
		OnAccept = function(_, data)
			if data then
				data()
			end
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}
	StaticPopup_Show("DMOUSEOVERCASTS_CONFIRM", text, nil, onAccept)
end

local function Tooltip(frame, text)
	frame:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(text, 1, 1, 1, 1, true)
		GameTooltip:Show()
	end)
	frame:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
end

local function Backdrop(frame)
	frame:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8X8",
		edgeFile = "Interface\\Buttons\\WHITE8X8",
		edgeSize = 1,
	})
	frame:SetBackdropColor(0, 0, 0, 0.35)
	frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
end

------------------------------------------------------------------------
-- Spell input helpers
------------------------------------------------------------------------

-- Text for /cast from whatever is on the cursor: a spell from the spellbook or an item.
local function CursorSpellText()
	local kind, id, _, spellID = GetCursorInfo()
	if kind == "spell" and spellID then
		return (ns.GetSpellNameAndIcon(spellID))
	elseif kind == "item" and id then
		if C_Item and C_Item.GetItemNameByID then
			return C_Item.GetItemNameByID(id)
		end
		return GetItemInfo and (GetItemInfo(id))
	end
end

-- Text for /cast from a shift-clicked spell or item link.
local function LinkSpellText(link)
	local spellID = tonumber(link:match("|Hspell:(%d+)") or "")
	if spellID then
		return (ns.GetSpellNameAndIcon(spellID))
	end
	if link:find("|Hitem:") then
		return link:match("|h%[(.-)%]|h")
	end
end

local function SpellIcon(text)
	local _, icon = ns.ResolveSpell(text)
	return icon
end

-- The icon of an entry on this page: its first spell. On the bar the game picks the icon itself,
-- from the spell the macro would cast right now.
local function EntryIcon(entry)
	if entry.custom then
		return nil
	end
	return SpellIcon(entry.help) or SpellIcon(entry.harm)
end

------------------------------------------------------------------------
-- Panel
------------------------------------------------------------------------

function Options:Init()
	local panel = CreateFrame("Frame")
	panel:Hide()
	panel:SetScript("OnShow", function()
		Options:Create()
		Options:Refresh()
	end)
	self.panel = panel

	if Settings and Settings.RegisterCanvasLayoutCategory then
		self.category = Settings.RegisterCanvasLayoutCategory(panel, "dMouseOverCasts")
		Settings.RegisterAddOnCategory(self.category)
	elseif InterfaceOptions_AddCategory then
		panel.name = "dMouseOverCasts"
		InterfaceOptions_AddCategory(panel)
	end

	-- Shift-click on a spell or item while a spell box has focus puts its name in the box.
	local function OnInsertLink(link)
		if type(link) ~= "string" or not self.spellBoxes then
			return
		end
		for _, box in ipairs(self.spellBoxes) do
			if box:HasFocus() then
				local text = LinkSpellText(link)
				if text then
					box:SetText(text)
					box:ClearFocus()
				end
				return
			end
		end
	end
	if ChatEdit_InsertLink then
		hooksecurefunc("ChatEdit_InsertLink", OnInsertLink)
	end
	if ChatFrameUtil and ChatFrameUtil.InsertLink then
		hooksecurefunc(ChatFrameUtil, "InsertLink", OnInsertLink)
	end
end

function Options:Open()
	if Settings and Settings.OpenToCategory and self.category then
		Settings.OpenToCategory(self.category:GetID())
	elseif InterfaceOptionsFrame_OpenToCategory then
		InterfaceOptionsFrame_OpenToCategory(self.panel)
		InterfaceOptionsFrame_OpenToCategory(self.panel)
	end
end

function Options:Create()
	if self.created then
		return
	end
	self.created = true
	local panel = self.panel

	local title = Text(panel, "dMouseOverCasts", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	local version = Text(panel, GREY .. "v" .. ns.version .. "  " .. (ns.isForever and "World of Warcraft: Forever" or "Retail") .. "|r", "GameFontHighlightSmall")
	version:SetPoint("LEFT", title, "RIGHT", 10, -1)

	local help = Text(panel, L["HELP"], "GameFontHighlightSmall")
	help:SetPoint("TOPLEFT", 16, -46)
	help:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
	help:SetTextColor(0.8, 0.8, 0.8)

	self:BuildList(panel)
	self:BuildEditor(panel)
end

------------------------------------------------------------------------
-- Macro list
------------------------------------------------------------------------

local function SetupRow(row)
	if row.created then
		return
	end
	row.created = true
	row:SetHeight(ROW_HEIGHT)

	row.selectedTexture = row:CreateTexture(nil, "BACKGROUND")
	row.selectedTexture:SetAllPoints()
	row.selectedTexture:SetColorTexture(0.2, 0.73, 1, 0.25)

	row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
	row.highlight:SetAllPoints()
	row.highlight:SetColorTexture(1, 1, 1, 0.08)

	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(ROW_HEIGHT - 6, ROW_HEIGHT - 6)
	row.icon:SetPoint("LEFT", 4, 0)
	row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	row.title = Text(row, "")
	row.title:SetPoint("TOPLEFT", ROW_HEIGHT + 4, -3)
	row.title:SetPoint("RIGHT", -4, 0)
	row.title:SetWordWrap(false)

	row.sub = Text(row, "", "GameFontHighlightSmall")
	row.sub:SetPoint("BOTTOMLEFT", ROW_HEIGHT + 4, 4)
	row.sub:SetPoint("RIGHT", -4, 0)
	row.sub:SetWordWrap(false)
end

local function EntryName(entry)
	if entry.created then
		return entry.name
	end
	return entry.customName ~= "" and entry.customName or Macros.AutoName(entry)
end

function Options:BuildList(panel)
	local scrollBox = CreateFrame("Frame", nil, panel, "WowScrollBoxList")
	scrollBox:SetSize(LIST_WIDTH, LIST_HEIGHT)
	scrollBox:SetPoint("TOPLEFT", 16, -80)
	local scrollBar = CreateFrame("EventFrame", nil, panel, "MinimalScrollBar")
	scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 6, 0)
	scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 6, 0)

	local view = CreateScrollBoxListLinearView()
	view:SetElementExtent(ROW_HEIGHT)
	view:SetElementInitializer("Button", function(row, entry)
		SetupRow(row)
		local status = Macros:Status(entry)
		row.selectedTexture:SetShown(entry == Options.selected)
		row.icon:SetTexture(EntryIcon(entry) or QUESTION_ICON)
		row.title:SetText(EntryName(entry))
		local spells = {}
		if entry.custom then
			spells[1] = L["own macro"]
		else
			if entry.help ~= "" then
				spells[#spells + 1] = "|cFF66FF66" .. entry.help .. "|r"
			end
			if entry.harm ~= "" then
				spells[#spells + 1] = "|cFFFF6666" .. entry.harm .. "|r"
			end
		end
		row.sub:SetText(status == "ok" and table.concat(spells, " / ") or STATUS_TEXT[status])
		row:SetScript("OnClick", function()
			Options:Select(entry)
		end)
	end)
	ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
	function scrollBox:SetItems(items)
		self:SetDataProvider(CreateDataProvider(items), ScrollBoxConstants.RetainScrollPosition)
	end

	local background = CreateFrame("Frame", nil, panel, "BackdropTemplate")
	background:SetPoint("TOPLEFT", scrollBox, -3, 3)
	background:SetPoint("BOTTOMRIGHT", scrollBox, 3, -3)
	background:SetFrameLevel(math.max(scrollBox:GetFrameLevel() - 1, 0))
	Backdrop(background)
	self.list = scrollBox

	self.emptyText = Text(panel, L["No macros yet: press \"New macro\"."], "GameFontDisableSmall")
	self.emptyText:SetPoint("TOP", scrollBox, "TOP", 0, -20)

	local add = Button(panel, L["New macro"], (LIST_WIDTH - 4) / 2, function()
		local entry = Profile:AddEntry()
		if entry then
			Options:Select(entry)
		end
	end)
	add:SetPoint("TOPLEFT", scrollBox, "BOTTOMLEFT", -2, -10)
	self.addButton = add

	self.deleteButton = Button(panel, L["Delete"], (LIST_WIDTH - 4) / 2, function()
		local entry = Options.selected
		if not entry then
			return
		end
		local question = Macros:Find(entry) and L["Delete the macro %s? It disappears from your macros and action bars."]
			or L["Delete %s from the list?"]
		Confirm(string.format(question, EntryName(entry)), function()
			if Macros:Delete(entry) then
				Profile:RemoveEntry(entry)
			end
		end)
	end)
	self.deleteButton:SetPoint("LEFT", add, "RIGHT", 4, 0)
end

function Options:Select(entry)
	self.selected = entry
	self:Refresh()
end

------------------------------------------------------------------------
-- Macro editor
------------------------------------------------------------------------

local function Commit(field, value)
	local entry = Options.selected
	if entry then
		entry[field] = value
		Profile:Changed(entry)
	end
end

-- Stores a spell typed, pasted, dropped or linked into a spell box.
local function CommitSpell(field, input)
	local text = strtrim(input or "")
	if text == "" then
		Commit(field, "")
		return
	end
	local resolved = ns.ResolveSpell(text)
	if not resolved then
		ns:Print(string.format(L["Unknown spell: %s"], text))
		Options:Refresh()
		return
	end
	Commit(field, resolved)
end

local function CommitName(input)
	local entry = Options.selected
	if not entry then
		return
	end
	local name = ns.Utf8Truncate(strtrim(input or ""), Macros.NAME_LENGTH)
	if name ~= "" and Macros.IsNameTaken(name, entry) then
		ns:Print(string.format(L["There is already a macro named %s."], name))
		Options:Refresh()
		return
	end
	Commit("customName", name)
end

------------------------------------------------------------------------
-- Spell suggestions
------------------------------------------------------------------------

-- The list under a spell box: the spellbook, narrowed down by the text typed in the box. It opens
-- when the user types or presses the arrow next to the box. Up and Down move the highlight, Enter
-- takes the highlighted spell, Tab the highlighted or the first one, a click any of them. A click
-- anywhere else closes it.
local Suggest = { items = {} }
Options.Suggest = Suggest

local SPELL_BOX_WIDTH = 260
local SUGGEST_ROWS, SUGGEST_ROW_HEIGHT = 8, 22
local SUGGEST_WIDTH = SPELL_BOX_WIDTH + 30 -- the box and the arrow next to it

local function SetupSuggestRow(row)
	if row.created then
		return
	end
	row.created = true
	row:SetHeight(SUGGEST_ROW_HEIGHT)

	row.selectedTexture = row:CreateTexture(nil, "BACKGROUND")
	row.selectedTexture:SetAllPoints()
	row.selectedTexture:SetColorTexture(0.2, 0.73, 1, 0.3)

	row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
	row.highlight:SetAllPoints()
	row.highlight:SetColorTexture(1, 1, 1, 0.1)

	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(SUGGEST_ROW_HEIGHT - 4, SUGGEST_ROW_HEIGHT - 4)
	row.icon:SetPoint("LEFT", 2, 0)
	row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	row.text = Text(row, "")
	row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
	row.text:SetPoint("RIGHT", -4, 0)
	row.text:SetWordWrap(false)
end

function Suggest:Create(parent)
	local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	frame:SetFrameStrata("DIALOG") -- over the widgets below the box
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	Backdrop(frame)
	frame:SetBackdropColor(0.06, 0.06, 0.06, 0.97)
	frame:Hide()
	-- Also when the page is closed with the list open: it must not come back with the page.
	frame:SetScript("OnHide", function()
		Suggest:Close()
	end)

	local scrollBox = CreateFrame("Frame", nil, frame, "WowScrollBoxList")
	scrollBox:SetPoint("TOPLEFT", 3, -3)
	scrollBox:SetPoint("BOTTOMRIGHT", -14, 3)
	local scrollBar = CreateFrame("EventFrame", nil, frame, "MinimalScrollBar")
	scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 3, 0)
	scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 3, 0)

	local view = CreateScrollBoxListLinearView()
	view:SetElementExtent(SUGGEST_ROW_HEIGHT)
	view:SetElementInitializer("Button", function(row, item)
		SetupSuggestRow(row)
		local spell = item.spell
		row.icon:SetTexture(spell.icon or QUESTION_ICON)
		row.text:SetText(spell.rank and (spell.name .. " " .. GREY .. spell.rank .. "|r") or spell.name)
		-- Spells that do not suit the box (a harmful one for friends) are listed last and dimmed.
		local shade = item.fit and 1 or 0.6
		row.text:SetTextColor(shade, shade, shade)
		row.selectedTexture:SetShown(item == Suggest.items[Suggest.selected])
		row:SetScript("OnClick", function()
			Suggest:Pick(item)
		end)
	end)
	ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
	if scrollBar.SetHideIfUnscrollable then
		scrollBar:SetHideIfUnscrollable(true)
	end

	frame:RegisterEvent("GLOBAL_MOUSE_DOWN")
	frame:SetScript("OnEvent", function()
		local row = Suggest.row
		if row and not (frame:IsMouseOver() or row.box:IsMouseOver() or row.browse:IsMouseOver()) then
			Suggest:Close()
		end
	end)

	self.frame, self.list = frame, scrollBox
end

-- Shows the spells for the text under the box of a spell row; closes the list if there are none.
function Suggest:Show(row, query)
	if self.row ~= row then
		self:Close()
		self.row = row
	end
	self.spells = self.spells or ns.Spellbook.Read()
	local items = ns.Spellbook.Search(self.spells, query, row.field)
	if #items == 0 then
		self:Close()
		return
	end
	self.items = items
	-- What Enter takes: the first spell if its name starts with the text typed. Otherwise nothing
	-- is highlighted and Enter keeps the text, which may well be an item.
	self.selected = (strtrim(query) ~= "" and items[1].first) and 1 or nil

	local frame = self.frame
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", row.box, "BOTTOMLEFT", -6, -2)
	frame:SetSize(SUGGEST_WIDTH, math.min(#items, SUGGEST_ROWS) * SUGGEST_ROW_HEIGHT + 6)
	frame:Show()
	self.list:SetDataProvider(CreateDataProvider(items), ScrollBoxConstants.DiscardScrollPosition)
end

function Suggest:Close()
	self.row, self.spells, self.items, self.selected = nil, nil, {}, nil
	self.frame:Hide()
end

function Suggest:IsOpen(row)
	return self.row == row
end

-- Moves the highlight. Past either end nothing is highlighted: Enter keeps the text as typed.
function Suggest:Move(step)
	local index = ((self.selected or 0) + step) % (#self.items + 1)
	self.selected = index > 0 and index or nil
	if self.selected then
		self.list:ScrollToElementDataIndex(index, ScrollBoxConstants.AlignNearest, 0, ScrollBoxConstants.NoScrollInterpolation)
	end
	local chosen = self.items[index]
	self.list:ForEachFrame(function(frame, item)
		frame.selectedTexture:SetShown(item == chosen)
	end)
end

-- Takes the highlighted spell of a row's list, or with any the first one if none is highlighted.
-- False if there is nothing to take.
function Suggest:Take(row, any)
	if self.row ~= row then
		return false
	end
	local item = self.items[self.selected] or (any and self.items[1])
	if not item then
		return false
	end
	self:Pick(item)
	return true
end

-- Puts a spell of the list into its box and stores it.
function Suggest:Pick(item)
	local row = self.row
	if not row then
		return
	end
	local text = item.spell.text
	self:Close()
	row.box:SetText(text)
	if row.box:HasFocus() then
		row.box:ClearFocus() -- stores the text of the box
	else
		CommitSpell(row.field, text)
	end
end

function Options:BuildSpellRow(parent, field, label, anchor)
	local labelText = Label(parent, label)
	labelText:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -14)

	local icon = CreateFrame("Button", nil, parent)
	icon:SetSize(26, 26)
	icon:SetPoint("TOPLEFT", labelText, "BOTTOMLEFT", 0, -4)
	icon:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	icon.texture = icon:CreateTexture(nil, "ARTWORK")
	icon.texture:SetAllPoints()
	icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	local function Drop()
		local text = CursorSpellText()
		if text then
			ClearCursor()
			Commit(field, text)
		end
	end
	icon:SetScript("OnReceiveDrag", Drop)
	icon:SetScript("OnClick", function(_, mouse)
		if mouse == "RightButton" then
			Commit(field, "")
		elseif GetCursorInfo() then
			Drop()
		end
	end)
	Tooltip(icon, L["Drag a spell from the spellbook here. Right click: clear."])

	local box = EditBox(parent, SPELL_BOX_WIDTH, function(text)
		CommitSpell(field, text)
	end)
	box:SetPoint("LEFT", icon, "RIGHT", 10, 0)
	box:SetScript("OnReceiveDrag", Drop)

	local note = Text(parent, "", "GameFontHighlightSmall")
	note:SetPoint("LEFT", labelText, "RIGHT", 8, 0)

	local row = { label = labelText, icon = icon, box = box, note = note, field = field }

	-- The spellbook list: the arrow opens the whole book, typing narrows it down.
	local browse = CreateFrame("Button", nil, parent, "UIPanelScrollDownButtonTemplate")
	browse:SetPoint("LEFT", box, "RIGHT", 4, 0)
	browse:SetScript("OnClick", function()
		if Suggest:IsOpen(row) then
			Suggest:Close()
		else
			box:SetFocus()
			Suggest:Show(row, "")
		end
	end)
	Tooltip(browse, L["Pick a spell from your spellbook. Or just type in the box: the list shows the matching spells."])
	row.browse = browse

	box:SetAltArrowKeyMode(false) -- Up and Down without Alt
	box:HookScript("OnTextChanged", function(self, userInput)
		if userInput then
			Suggest:Show(row, self:GetText())
		end
	end)
	box:SetScript("OnArrowPressed", function(_, key)
		if key == "UP" or key == "DOWN" then
			if Suggest:IsOpen(row) then
				Suggest:Move(key == "DOWN" and 1 or -1)
			elseif key == "DOWN" then
				Suggest:Show(row, "")
			end
		end
	end)
	box:SetScript("OnTabPressed", function()
		Suggest:Take(row, true)
	end)
	box:SetScript("OnEnterPressed", function(self)
		if not Suggest:Take(row) then
			self:ClearFocus()
		end
	end)
	box:HookScript("OnEditFocusLost", function()
		if Suggest:IsOpen(row) then
			Suggest:Close()
		end
	end)

	self.spellBoxes = self.spellBoxes or {}
	self.spellBoxes[#self.spellBoxes + 1] = box
	return row
end

function Options:BuildEditor(panel)
	local editor = CreateFrame("Frame", nil, panel)
	editor:SetPoint("TOPLEFT", EDITOR_X, -80)
	editor:SetPoint("BOTTOMRIGHT", -16, 16)
	self.editor = editor

	-- The macro itself: drag the icon to an action bar.
	local macroIcon = CreateFrame("Button", nil, editor)
	macroIcon:SetSize(44, 44)
	macroIcon:SetPoint("TOPLEFT", 0, 0)
	macroIcon:RegisterForDrag("LeftButton")
	macroIcon.texture = macroIcon:CreateTexture(nil, "ARTWORK")
	macroIcon.texture:SetAllPoints()
	macroIcon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	local highlight = macroIcon:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetAllPoints()
	highlight:SetColorTexture(1, 1, 1, 0.15)
	local function PickUp()
		if Options.selected then
			Macros:PickUp(Options.selected)
		end
	end
	macroIcon:SetScript("OnDragStart", PickUp)
	macroIcon:SetScript("OnClick", PickUp)
	Tooltip(macroIcon, L["Drag this icon to an action bar. The macro is also in the game's macro window (/macro)."])
	self.macroIcon = macroIcon

	local nameLabel = Label(editor, L["Macro name"])
	nameLabel:SetPoint("TOPLEFT", macroIcon, "TOPRIGHT", 12, 0)
	self.nameBox = EditBox(editor, 140, CommitName)
	self.nameBox:SetMaxLetters(Macros.NAME_LENGTH)
	self.nameBox:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 4, -6)

	local scopeLabel = Label(editor, L["Stored in"])
	scopeLabel:SetPoint("TOPLEFT", nameLabel, "TOPLEFT", 156, 0)
	self.scopeDropdown = Dropdown(editor, 150, {
		{ text = L["character macros"], value = "char" },
		{ text = L["general macros"], value = "general" },
	}, function()
		return Options.selected and Options.selected.scope
	end, function(scope)
		if Options.selected then
			Macros:SetScope(Options.selected, scope)
		end
	end)
	self.scopeDropdown:SetPoint("TOPLEFT", scopeLabel, "BOTTOMLEFT", 0, -2)

	self.pickupButton = Button(editor, L["Pick up the macro"], 170, PickUp)
	self.pickupButton:SetPoint("TOPLEFT", macroIcon, "BOTTOMLEFT", 0, -8)
	self.statusText = Text(editor, "", "GameFontHighlightSmall")
	self.statusText:SetPoint("LEFT", self.pickupButton, "RIGHT", 10, 0)
	self.statusText:SetPoint("RIGHT", editor, "RIGHT", 0, 0)

	-- Spells
	Suggest:Create(editor)
	self.helpRow = self:BuildSpellRow(editor, "help", L["Helpful spell: friend under the mouse"], self.pickupButton)
	self.harmRow = self:BuildSpellRow(editor, "harm", L["Harmful spell: enemy under the mouse"], self.helpRow.icon)

	-- Fallbacks
	local fallbackLabel = Label(editor, L["Nothing suitable under the mouse"])
	fallbackLabel:SetPoint("TOPLEFT", self.harmRow.icon, "BOTTOMLEFT", 0, -14)
	self.fallbackDropdown = Dropdown(editor, 220, {
		{ text = L["cast on the target"], value = "target" },
		{ text = L["do nothing"], value = "none" },
	}, function()
		return Options.selected and Options.selected.fallback
	end, function(value)
		Commit("fallback", value)
	end)
	self.fallbackDropdown:SetPoint("TOPLEFT", fallbackLabel, "BOTTOMLEFT", 0, -4)

	self.selfCheck = Check(editor, L["Otherwise the helpful spell on yourself"], function(checked)
		Commit("selfCast", checked)
	end)
	self.selfCheck:SetPoint("TOPLEFT", self.fallbackDropdown, "BOTTOMLEFT", -4, -6)

	self.deadCheck = Check(editor, L["Skip dead units (turn off for resurrection)"], function(checked)
		Commit("skipDead", checked)
	end)
	self.deadCheck:SetPoint("TOPLEFT", self.selfCheck, "BOTTOMLEFT", 0, 0)

	self.customCheck = Check(editor, L["Edit the macro by hand"], function(checked)
		local entry = Options.selected
		if entry and checked and strtrim(entry.macro) == "" then
			entry.macro = Macro.Build(entry) or "#showtooltip\n/cast "
		end
		Commit("custom", checked)
	end)
	self.customCheck:SetPoint("TOPLEFT", self.deadCheck, "BOTTOMLEFT", 0, 0)

	-- Macro text
	local holder = CreateFrame("Frame", nil, editor, "BackdropTemplate")
	holder:SetPoint("TOPLEFT", self.customCheck, "BOTTOMLEFT", 4, -4)
	holder:SetPoint("RIGHT", editor, "RIGHT", 0, 0)
	holder:SetHeight(64)
	Backdrop(holder)
	holder:EnableMouse(true)

	local macroBox = CreateFrame("EditBox", nil, holder)
	macroBox:SetPoint("TOPLEFT", 6, -5)
	macroBox:SetPoint("BOTTOMRIGHT", -6, 5)
	macroBox:SetMultiLine(true)
	macroBox:SetAutoFocus(false)
	macroBox:SetFontObject(ChatFontNormal or "GameFontHighlightSmall")
	macroBox:SetScript("OnEscapePressed", function(self)
		self.revert = true
		self:ClearFocus()
	end)
	macroBox:SetScript("OnTextChanged", function(self, userInput)
		local entry = Options.selected
		if userInput and not (entry and entry.custom) then
			-- Generated macros are read-only: turn on "Edit the macro by hand" to change one.
			self:SetText(Options.macroText or "")
		end
	end)
	macroBox:SetScript("OnEditFocusLost", function(self)
		local entry = Options.selected
		if self.revert then
			self.revert = nil
			Options:Refresh()
		elseif entry and entry.custom then
			Commit("macro", self:GetText())
		end
	end)
	holder:SetScript("OnMouseDown", function()
		macroBox:SetFocus()
	end)
	self.macroBox = macroBox

	self.macroNote = Text(editor, "", "GameFontHighlightSmall")
	self.macroNote:SetPoint("TOPLEFT", holder, "BOTTOMLEFT", 0, -6)
	self.macroNote:SetPoint("RIGHT", editor, "RIGHT", 0, 0)
end

------------------------------------------------------------------------
-- Refresh
------------------------------------------------------------------------

function Options:Refresh()
	if not (self.created and self.panel:IsShown()) then
		return
	end
	local entries = Profile:GetEntries()
	local found = false
	for _, entry in ipairs(entries) do
		if entry == self.selected then
			found = true
		end
	end
	if not found then
		self.selected = entries[1]
	end

	self.list:SetItems(entries)
	self.emptyText:SetShown(#entries == 0)
	self.deleteButton:SetEnabled(self.selected ~= nil)
	self.editor:SetShown(self.selected ~= nil)
	if self.selected then
		self:RefreshEditor(self.selected)
	end
end

function Options:RefreshSpellRow(row, entry)
	local text = entry[row.field]
	local _, icon, known = ns.ResolveSpell(text)
	row.icon.texture:SetTexture(icon or QUESTION_ICON)
	row.icon.texture:SetDesaturated(text == "")
	SetBoxText(row.box, text)
	if text ~= "" and not known then
		row.note:SetText(YELLOW .. L["not in your spellbook"] .. "|r")
	else
		row.note:SetText("")
	end
	SetWidgetEnabled(row.box, not entry.custom)
	SetWidgetEnabled(row.icon, not entry.custom)
	SetWidgetEnabled(row.browse, not entry.custom)
	row.label:SetAlpha(entry.custom and 0.4 or 1)
end

function Options:RefreshEditor(entry)
	local status = Macros:Status(entry)
	local usable = status == "ok" or status == "new" or status == "missing"

	self.macroIcon.texture:SetTexture(EntryIcon(entry) or QUESTION_ICON)
	self.macroIcon.texture:SetDesaturated(not usable)
	SetBoxText(self.nameBox, EntryName(entry))
	self.scopeDropdown:GenerateMenu()
	self.pickupButton:SetEnabled(usable)
	local statusText = STATUS_TEXT[status]
	if Macros.pending[entry] then
		statusText = statusText .. "\n" .. YELLOW .. L["Changes made in combat are written after combat."] .. "|r"
	end
	self.statusText:SetText(statusText)

	self:RefreshSpellRow(self.helpRow, entry)
	self:RefreshSpellRow(self.harmRow, entry)

	self.fallbackDropdown:GenerateMenu()
	self.fallbackDropdown:SetEnabled(not entry.custom)
	self.selfCheck:SetChecked(entry.selfCast)
	self.selfCheck:SetEnabled(not entry.custom)
	self.deadCheck:SetChecked(entry.skipDead)
	self.deadCheck:SetEnabled(not entry.custom)
	self.customCheck:SetChecked(entry.custom)

	local text = Macro.Build(entry)
	self.macroText = text or ""
	SetBoxText(self.macroBox, self.macroText)
	local shade = entry.custom and 1 or 0.75
	self.macroBox:SetTextColor(shade, shade, shade)

	local note = string.format("%d / %d", #self.macroText, Macro.MAX_LENGTH)
	if status == "toolong" then
		note = note .. "   " .. RED .. L["Too long: pick \"do nothing\" above, then each spell is named once. Or shorten the macro by hand."] .. "|r"
	end
	self.macroNote:SetText(note)
end
