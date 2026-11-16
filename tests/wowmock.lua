-- Minimal World of Warcraft API mock for running dMouseOverCasts under plain Lua 5.1.
local M = {}
M.events = {}

------------------------------------------------------------------------
-- Widgets
------------------------------------------------------------------------

local Widget = {}
local WidgetMeta = { __index = Widget }

local function newWidget(kind, name, parent, template)
	local w = setmetatable({
		__kind = kind, __name = name, __parent = parent, __template = template,
		__shown = true, __points = {}, __scripts = {}, __children = {},
		__text = "", __width = 0, __height = 0, __level = 1, __alpha = 1, __enabled = true,
	}, WidgetMeta)
	if parent then
		table.insert(parent.__children, w)
		w.__level = (parent.__level or 1) + 1
	end
	return w
end
M.newWidget = newWidget

local function noop() end
for _, name in ipairs({
	"SetJustifyH", "SetTextColor", "SetWordWrap", "SetColorTexture", "SetTexCoord", "SetDesaturated",
	"SetAutoFocus", "HighlightText", "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor", "AddLine",
	"SetOwner", "SetMultiLine", "SetMaxLetters", "SetFontObject", "SetFrameStrata", "RegisterForDrag",
	"SetAltArrowKeyMode", "SetClampedToScreen",
}) do
	Widget[name] = noop
end

function Widget:SetPoint(...) table.insert(self.__points, { ... }) end
function Widget:ClearAllPoints() self.__points = {} end
function Widget:SetAllPoints(rel) self.__points = { { "ALL", rel } } end
function Widget:SetSize(w, h) self.__width, self.__height = w, h end
function Widget:SetWidth(w) self.__width = w end
function Widget:SetHeight(h) self.__height = h end
function Widget:Show()
	local was = self.__shown
	self.__shown = true
	if not was and self.__scripts.OnShow then self.__scripts.OnShow(self) end
end
function Widget:Hide()
	local was = self.__shown
	self.__shown = false
	if was and self.__scripts.OnHide then self.__scripts.OnHide(self) end
end
function Widget:SetShown(s) if s then self:Show() else self:Hide() end end
function Widget:IsShown() return self.__shown end
function Widget:SetAlpha(a) self.__alpha = a end
function Widget:GetAlpha() return self.__alpha end
function Widget:SetScript(n, f) self.__scripts[n] = f end
function Widget:GetScript(n) return self.__scripts[n] end
function Widget:HookScript(n, f)
	local old = self.__scripts[n]
	self.__scripts[n] = old and function(...) old(...); f(...) end or f
end
function Widget:CreateTexture() return newWidget("Texture", nil, self) end
function Widget:CreateFontString() return newWidget("FontString", nil, self) end
function Widget:SetText(t)
	self.__text = t
	-- Like the game: text set by code reaches OnTextChanged too, marked as not typed.
	if self.__scripts.OnTextChanged then self.__scripts.OnTextChanged(self, false) end
end
function Widget:GetText() return self.__text end
function Widget:SetTexture(t) self.__texture = t end
function Widget:GetTexture() return self.__texture end
function Widget:GetFrameLevel() return self.__level end
function Widget:SetFrameLevel(l) self.__level = l end
function Widget:GetName() return self.__name end
function Widget:SetEnabled(e) self.__enabled = e and true or false end
function Widget:IsEnabled() return self.__enabled end
function Widget:EnableMouse(e) self.__mouse = e end
function Widget:SetChecked(c) self.__checked = c and true or false end
function Widget:GetChecked() return self.__checked end
function Widget:RegisterForClicks(...) self.__clicks = { ... } end
function Widget:IsMouseOver() return self.__mouseOver or false end
function Widget:SetFocus()
	if M.focus and M.focus ~= self then M.focus:ClearFocus() end -- one box has the keyboard
	M.focus = self
end
function Widget:ClearFocus()
	if M.focus == self then
		M.focus = nil
		if self.__scripts.OnEditFocusLost then self.__scripts.OnEditFocusLost(self) end
	end
end
function Widget:HasFocus() return M.focus == self end
function Widget:RegisterEvent(e)
	if M.unknownEvents and M.unknownEvents[e] then error("unknown event " .. e) end
	M.events[e] = M.events[e] or {}
	M.events[e][self] = true
end
function Widget:SetupMenu(gen) self.__menu = gen end
function Widget:GenerateMenu()
	if self.__menu then
		local root = M.FakeMenuRoot()
		self.__menu(self, root)
		self.__lastMenu = root
	end
end
function Widget:SetDataProvider(dp, retainScrollPosition)
	self.__rows = {}
	if not retainScrollPosition then self.__scrolledTo = nil end
	for _, item in ipairs(dp.items) do
		local row = newWidget("Button", nil, self)
		row.__data = item
		self.__view.initializer(row, item)
		table.insert(self.__rows, row)
	end
end
function Widget:ForEachFrame(func)
	for _, row in ipairs(self.__rows or {}) do func(row, row.__data) end
end
function Widget:ScrollToElementDataIndex(index) self.__scrolledTo = index end

-- User actions
function M.Click(w, mouse) w.__scripts.OnClick(w, mouse or "LeftButton", false) end
-- Typing into a box that keeps the keyboard afterwards.
function M.Input(box, text)
	box:SetFocus()
	box.__text = text
	if box.__scripts.OnTextChanged then box.__scripts.OnTextChanged(box, true) end
end
-- Typing and leaving the box without Enter.
function M.Type(box, text)
	M.Input(box, text)
	box:ClearFocus()
end
-- A key pressed in the box that has the keyboard.
local KEY_SCRIPTS = { ENTER = "OnEnterPressed", ESCAPE = "OnEscapePressed", TAB = "OnTabPressed", UP = "OnArrowPressed", DOWN = "OnArrowPressed" }
function M.Key(box, key)
	assert(M.focus == box, "the box does not have the keyboard")
	local script = box.__scripts[assert(KEY_SCRIPTS[key], key)]
	if script then script(box, key) end
end

function M.FakeMenuRoot()
	local root = { items = {} }
	function root:CreateTitle(t) table.insert(self.items, { "title", t }) end
	function root:CreateButton(t, f) table.insert(self.items, { "button", t, f }) end
	function root:CreateRadio(t, isSel, f, v) table.insert(self.items, { "radio", t, f, v, isSel(v) }) end
	return root
end

function M.FireEvent(event, ...)
	for frame in pairs(M.events[event] or {}) do
		if frame.__scripts.OnEvent then
			frame.__scripts.OnEvent(frame, event, ...)
		end
	end
end

------------------------------------------------------------------------
-- Macro conditions
------------------------------------------------------------------------

M.QUESTION_MARK = 134400

-- Units the macro conditions look at: M.units.mouseover = { friend = true, dead = false }.
-- A unit that is not listed does not exist; the player always does.
M.units = {}

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

-- True if the conditions between [ and ] hold, the way the game reads @unit, help, harm, nodead.
local function holds(conditions)
	local name = conditions:match("@(%a+)") or "target"
	local unit = name == "player" and { friend = true } or M.units[name]
	for condition in conditions:gmatch("[^,]+") do
		condition = trim(condition)
		if condition == "help" then
			if not (unit and unit.friend) then return false end
		elseif condition == "harm" then
			if not unit or unit.friend then return false end
		elseif condition == "nodead" then
			if unit and unit.dead then return false end
		elseif condition:sub(1, 1) ~= "@" then
			error("macro condition not mocked: " .. condition)
		end
	end
	return true
end

-- The spell a macro would cast right now: the first clause of its /cast line with a set of
-- conditions that holds. A clause is "[a][b]Spell" (either set will do), "[]Spell" or just
-- "Spell" (always). Nil if no clause holds or the macro has no /cast line. Also returns the unit
-- of that set ("mouseover", "player"); nil is a plain cast, which the game aims itself.
function M.MacroSpell(body)
	local line = ("\n" .. body):match("\n/cast ([^\n]*)")
	for clause in ((line or "") .. ";"):gmatch("([^;]*);") do
		local sets, spell = {}, clause
		while true do
			local conditions, rest = spell:match("^%s*%[(.-)%](.*)$")
			if not conditions then
				break
			end
			sets[#sets + 1], spell = conditions, rest
		end
		if #sets == 0 then
			sets[1] = ""
		end
		spell = trim(spell)
		for _, conditions in ipairs(sets) do
			if holds(conditions) then
				if spell == "" then
					return nil
				end
				return spell, conditions:match("@(%a+)")
			end
		end
	end
end

------------------------------------------------------------------------
-- Globals
------------------------------------------------------------------------

function M.Install(env)
	env.UIParent = newWidget("Frame", "UIParent")
	env.GameTooltip = newWidget("GameTooltip", "GameTooltip")
	env.CreateFrame = function(kind, name, parent, template)
		local w = newWidget(kind, name, parent, template)
		if template == "UICheckButtonTemplate" then
			w.Text = newWidget("FontString", nil, w)
		end
		if name then env[name] = w end
		return w
	end

	env.GetBuildInfo = function() return "1.60.1", "70205", "Oct 3 2026", M.toc end
	env.WOW_PROJECT_CAMELOT = 99
	env.WOW_PROJECT_ID = M.toc == 16001 and 99 or 1
	env.GetLocale = function() return M.locale end
	env.strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
	env.YES, env.NO = "Yes", "No"
	env.SlashCmdList = {}
	env.InCombatLockdown = function() return M.inCombat or false end
	env.UnitFullName = function() return "Danpiel", nil end
	env.GetRealmName = function() return "Forever" end
	env.C_AddOns = { GetAddOnMetadata = function() return "1.0.0" end }
	env.StaticPopupDialogs = {}
	env.StaticPopup_Show = function(which, text, _, data) M.lastPopup = { which = which, text = text, data = data } end
	M.categories = {}
	env.Settings = {
		RegisterCanvasLayoutCategory = function(panel, name)
			local category = { panel = panel, name = name, GetID = function() return 77 end }
			table.insert(M.categories, category)
			return category
		end,
		RegisterAddOnCategory = noop,
		OpenToCategory = function(id) M.openedCategory = id; M.categories[1].panel:Show() end,
	}
	env.MenuUtil = { CreateContextMenu = function(owner, gen) local root = M.FakeMenuRoot(); gen(owner, root); M.lastMenu = root end }
	env.CreateScrollBoxListLinearView = function()
		local view = {}
		function view:SetElementExtent() end
		function view:SetElementInitializer(_, fn) self.initializer = fn end
		return view
	end
	env.ScrollUtil = { InitScrollBoxListWithScrollBar = function(box, _, view) box.__view = view end }
	env.CreateDataProvider = function(items) return { items = items } end
	env.ScrollBoxConstants = { RetainScrollPosition = true, DiscardScrollPosition = false, AlignNearest = -1, NoScrollInterpolation = true }
	env.hooksecurefunc = function(tbl, name, fn)
		if type(tbl) == "string" then tbl, name, fn = env, tbl, name end
		local orig = tbl[name]
		tbl[name] = function(...) local r = { orig(...) }; fn(...); return unpack(r) end
	end
	env.ChatEdit_InsertLink = function() return false end

	-- Spells: by name the game returns the highest known rank.
	M.spells = {}
	env.C_Spell = {
		GetSpellName = function(id) local s = M.spells[id]; return s and s.name end,
		GetSpellTexture = function(id) return M.spells[id] and (1000 + id) end,
		GetSpellInfo = function(x)
			if type(x) == "number" then
				return M.spells[x] and { spellID = x, name = M.spells[x].name, iconID = 1000 + x } or nil
			end
			local best
			for id, s in pairs(M.spells) do if s.name:lower() == x:lower() and (not best or id > best) then best = id end end
			return best and { spellID = best, name = M.spells[best].name, iconID = 1000 + best } or nil
		end,
	}
	env.C_Spell.IsSpellHelpful = function(id) return M.spells[id] and M.spells[id].help or false end
	env.C_Spell.IsSpellHarmful = function(id) return M.spells[id] and M.spells[id].harm or false end
	env.C_Item = { GetItemNameByID = function(id) return id == 5512 and "Healthstone" or nil end }

	-- Spellbook. M.book is a list of tabs: { name =, hidden =, offSpec = specID, items = { ... } };
	-- an item is { id = spellID, passive =, lowRank =, future =, offSpec = } or { flyout = id }.
	-- Items are numbered through all tabs, like in the game. M.flyouts[id] = { { id =, known = } }.
	M.book, M.flyouts = {}, {}
	local function bookItem(slot)
		for _, tab in ipairs(M.book) do
			if slot <= #tab.items then return tab.items[slot] end
			slot = slot - #tab.items
		end
	end
	env.Enum = {
		SpellBookItemType = { None = 0, Spell = 1, FutureSpell = 2, PetAction = 3, Flyout = 4 },
		SpellBookSpellBank = { Player = 0, Pet = 1 },
	}
	env.C_SpellBook = {
		GetNumSpellBookSkillLines = function() return #M.book end,
		GetSpellBookSkillLineInfo = function(index)
			local offset = 0
			for i = 1, index - 1 do offset = offset + #M.book[i].items end
			local tab = M.book[index]
			return tab and {
				name = tab.name, iconID = 1, itemIndexOffset = offset, numSpellBookItems = #tab.items,
				isGuild = false, shouldHide = tab.hidden or false, offSpecID = tab.offSpec,
			}
		end,
		GetSpellBookItemInfo = function(slot, bank)
			local item = bank == 0 and bookItem(slot)
			if not item then return nil end
			if item.flyout then
				return { actionID = item.flyout, itemType = 4, name = "Flyout", subName = "", iconID = 1, isPassive = false, isOffSpec = false }
			end
			local spell = M.spells[item.id]
			return {
				actionID = item.id, spellID = item.id, itemType = item.future and 2 or 1, name = spell.name,
				subName = spell.rank or "", iconID = 1000 + item.id, isPassive = item.passive or false, isOffSpec = item.offSpec or false,
			}
		end,
	}
	local function flyoutSlot(id, index)
		local slot = (M.flyouts[id] or {})[index]
		return slot, slot and M.spells[slot.id].name
	end
	if M.toc == 16001 then
		-- Only WoW Forever has ranks, and it has the flyouts in a namespace.
		env.C_SpellBook.IsSpellBookItemLowRank = function(slot, bank)
			local item = bank == 0 and bookItem(slot)
			return item and item.lowRank or false
		end
		env.C_Flyout = {
			GetFlyoutInfo = function(id) return { name = "Flyout", description = "", numSlots = #(M.flyouts[id] or {}), isKnown = true } end,
			GetFlyoutSlotInfo = function(id, index)
				local slot, name = flyoutSlot(id, index)
				return slot and { spellID = slot.id, overrideSpellID = slot.id, isKnown = slot.known or false, name = name }
			end,
		}
	else
		env.GetFlyoutInfo = function(id) return "Flyout", "", #(M.flyouts[id] or {}), true end
		env.GetFlyoutSlotInfo = function(id, index)
			local slot, name = flyoutSlot(id, index)
			if slot then return slot.id, slot.id, slot.known or false, name end
		end
	end

	-- Cursor
	env.GetCursorInfo = function() if M.cursor then return unpack(M.cursor) end end
	env.ClearCursor = function() M.cursor = nil end

	-- Macros: general ones at indexes 1-120, character ones from 121 on, like the game.
	M.macros = { general = {}, char = {} }
	env.MAX_ACCOUNT_MACROS, env.MAX_CHARACTER_MACROS = 120, 18
	local function slot(index)
		if index > 120 then return M.macros.char, index - 120 end
		return M.macros.general, index
	end
	local function blocked(name)
		if M.inCombat then error("ADDON_ACTION_BLOCKED: " .. name) end
	end
	env.GetNumMacros = function() return #M.macros.general, #M.macros.char end
	env.GetMacroIndexByName = function(name)
		for i, m in ipairs(M.macros.general) do if m.name == name then return i end end
		for i, m in ipairs(M.macros.char) do if m.name == name then return 120 + i end end
		return 0
	end
	-- Like the game, a macro with the question mark icon reports the icon of the spell it would
	-- cast right now (the question mark itself if there is none). Any other icon is fixed: the
	-- macro reports and shows it whatever it would cast.
	local function shownIcon(m)
		if m.icon ~= M.QUESTION_MARK then return m.icon end
		local spell = M.MacroSpell(m.body)
		local info = spell and env.C_Spell.GetSpellInfo((spell:gsub("%s*%(.-%)%s*$", "")))
		return info and info.iconID or M.QUESTION_MARK
	end
	env.GetMacroInfo = function(index)
		local list, i = slot(index)
		local m = list[i]
		if m then return m.name, shownIcon(m), m.body end
	end
	env.CreateMacro = function(name, icon, body, perCharacter)
		blocked("CreateMacro")
		local list = perCharacter and M.macros.char or M.macros.general
		assert(#list < (perCharacter and 18 or 120), "macro list full")
		assert(#name <= 64, "name too long")
		table.insert(list, { name = name, icon = icon, body = body })
		M.macroWrites = (M.macroWrites or 0) + 1
		M.FireEvent("UPDATE_MACROS") -- right inside the call, the hardest case for the addon
		return (perCharacter and 120 or 0) + #list
	end
	env.EditMacro = function(index, name, icon, body)
		blocked("EditMacro")
		local list, i = slot(index)
		local m = assert(list[i], "no macro at " .. index)
		m.name, m.icon, m.body = name or m.name, icon or m.icon, body or m.body
		M.macroWrites = (M.macroWrites or 0) + 1
		M.FireEvent("UPDATE_MACROS")
	end
	env.DeleteMacro = function(index)
		blocked("DeleteMacro")
		local list, i = slot(index)
		assert(list[i], "no macro at " .. index)
		table.remove(list, i)
		M.FireEvent("UPDATE_MACROS")
	end
	env.PickupMacro = function(index) M.cursor = { "macro", index } end
	return env
end

-- The game macro with this name as it is stored: { name, icon, body, scope } or nil.
function M.Macro(name)
	for scope, list in pairs(M.macros) do
		for _, m in ipairs(list) do
			if m.name == name then return { name = m.name, icon = m.icon, body = m.body, scope = scope } end
		end
	end
end

return M
