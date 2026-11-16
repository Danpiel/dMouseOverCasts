-- Game macros. Every entry owns one regular macro (character or general) that the addon creates
-- and keeps up to date; the player drags it to an action bar like any other macro. The addon finds
-- its macro by name and never touches macros it did not create. Macros cannot be created or
-- edited in combat: changes made then are written right after it.

local _, ns = ...
local L = ns.L

local Macros = {}
ns.Macros = Macros

local Macro = ns.Macro
local Profile = ns.Profile

-- The question mark. Only a macro with this icon shows the spell it would cast right now, the
-- helpful one over a friend and the harmful one over an enemy; with any other icon the button
-- shows that icon whatever #showtooltip says. Every macro the addon writes gets it.
Macros.ICON = 134400
Macros.NAME_LENGTH = 16
Macros.pending = {}

function Macros:Init()
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("PLAYER_REGEN_ENABLED")
	frame:RegisterEvent("UPDATE_MACROS")
	frame:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_REGEN_ENABLED" then
			local pending = Macros.pending
			Macros.pending = {}
			for _, entry in ipairs(Profile:GetEntries()) do
				if pending[entry] then
					Macros:Sync(entry)
				end
			end
		end
		Macros:RewriteOld()
		ns.Options:Refresh()
	end)
	self:RewriteOld()
end

-- Macros written by an older version of the addon are written again once, as soon as they are
-- loaded and combat is over. Data version 2 wrote the icon of the helpful spell into every macro
-- it edited (see Sync), so the button stopped changing over an enemy; version 3 wrote a longer
-- text with each spell named up to three times. Profile flags the entries saved by them.
function Macros:RewriteOld()
	if InCombatLockdown() then
		return -- PLAYER_REGEN_ENABLED comes back here
	end
	for _, entry in ipairs(Profile:GetEntries()) do
		if entry.rewrite and self:Find(entry) then
			self:Sync(entry)
		end
	end
end

local function IndexByName(name)
	local index = name and name ~= "" and GetMacroIndexByName(name)
	return (index and index > 0) and index or nil
end

-- Index of the entry's game macro, or nil if it has none (yet or any more).
function Macros:Find(entry)
	return entry.created and IndexByName(entry.name) or nil
end

-- Default name: the spell without its rank.
function Macros.AutoName(entry)
	local base = entry.help ~= "" and entry.help or entry.harm
	base = strtrim((base:gsub("%s*%(.-%)%s*$", "")))
	if base == "" then
		base = "dMouseOver"
	end
	return ns.Utf8Truncate(base, Macros.NAME_LENGTH)
end

-- A name no other macro has. ownIndex is the entry's own macro, which may keep its name.
function Macros.FreeName(base, ownIndex)
	base = ns.Utf8Truncate(base, Macros.NAME_LENGTH)
	for number = 1, 99 do
		local candidate = base
		if number > 1 then
			candidate = ns.Utf8Truncate(base, Macros.NAME_LENGTH - #tostring(number) - 1) .. " " .. number
		end
		local index = IndexByName(candidate)
		if not index or index == ownIndex then
			return candidate
		end
	end
end

function Macros.IsNameTaken(name, entry)
	local index = IndexByName(name)
	return index ~= nil and index ~= Macros:Find(entry)
end

function Macros.HasFreeSlot(scope)
	local general, character = GetNumMacros()
	if scope == "general" then
		return general < (MAX_ACCOUNT_MACROS or 120)
	end
	return character < (MAX_CHARACTER_MACROS or 18)
end

-- "ok", "new" (not created yet), "missing" (deleted in the macro window), "empty" (no spells),
-- "toolong" or "full" (no free macro slot).
function Macros:Status(entry)
	local problem = Macro.Problem(Macro.Build(entry))
	if problem then
		return problem
	end
	if self:Find(entry) then
		return "ok"
	end
	if not Macros.HasFreeSlot(entry.scope) then
		return "full"
	end
	return entry.created and "missing" or "new"
end

-- Creates or updates the entry's game macro. Returns true if the macro is up to date.
function Macros:Sync(entry)
	local text = Macro.Build(entry)
	if Macro.Problem(text) then
		return false
	end
	if InCombatLockdown() then
		self.pending[entry] = true
		return false
	end
	self.pending[entry] = nil

	local index = self:Find(entry)
	local name = Macros.FreeName(entry.customName ~= "" and entry.customName or Macros.AutoName(entry), index)
	if index then
		local oldName, _, oldBody = GetMacroInfo(index)
		if oldName ~= name or oldBody ~= text or entry.rewrite then
			-- Cleared first: EditMacro fires UPDATE_MACROS, which looks at the flag again.
			entry.rewrite = nil
			-- Never the icon GetMacroInfo returns: for a macro with the question mark that is the
			-- icon of the spell shown at this moment, and writing it back pins the button to it.
			EditMacro(index, name, Macros.ICON, text)
		end
	else
		if not Macros.HasFreeSlot(entry.scope) then
			return false
		end
		entry.rewrite = nil
		CreateMacro(name, Macros.ICON, text, entry.scope == "char")
		entry.created = true
	end
	entry.name = name
	return true
end

-- Moves the macro between character and general macros. The game has no way to move one, so it
-- is created anew and has to be put on the bar again.
function Macros:SetScope(entry, scope)
	if entry.scope == scope then
		return
	end
	if InCombatLockdown() then
		ns:Print(L["Macros cannot be changed in combat."])
		return
	end
	if not Macros.HasFreeSlot(scope) then
		ns:Print(L["No free macro slot there."])
		return
	end
	local index = self:Find(entry)
	if index then
		DeleteMacro(index)
		entry.created = false
	end
	entry.scope = scope
	Profile:Changed(entry)
end

-- Deletes the entry's game macro. False in combat.
function Macros:Delete(entry)
	if InCombatLockdown() then
		ns:Print(L["Macros cannot be changed in combat."])
		return false
	end
	local index = self:Find(entry)
	if index then
		DeleteMacro(index)
	end
	self.pending[entry] = nil
	return true
end

-- Puts the macro on the cursor so it can be dropped on an action bar; creates it first if needed.
function Macros:PickUp(entry)
	if not self:Find(entry) then
		if InCombatLockdown() then
			ns:Print(L["Macros cannot be changed in combat."])
			return
		end
		self:Sync(entry)
		ns.Options:Refresh()
	end
	local index = self:Find(entry)
	if index then
		PickupMacro(index)
	end
end

function Macros:PrintAll()
	local entries = Profile:GetEntries()
	if #entries == 0 then
		ns:Print(L["No macros yet. Open the settings with /dmo."])
		return
	end
	for _, entry in ipairs(entries) do
		local status = self:Status(entry)
		local color = status == "ok" and "|cFF33DD33" or "|cFFFFCC33"
		local text = (Macro.Build(entry) or L["no spells"]):gsub("\n", " ")
		print(color .. (entry.created and entry.name or Macros.AutoName(entry)) .. "|r  " .. text)
	end
end
