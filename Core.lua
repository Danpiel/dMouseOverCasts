--[[
	dMouseOverCasts by Danpiel
	Mouseover macros without writing them: pick a helpful spell for friends and a harmful spell for
	enemies, the addon writes a regular game macro and you drag it to your action bar.
]]

local ADDON, ns = ...
_G.dMouseOverCasts = ns

local L = ns.L

local tocversion = select(4, GetBuildInfo())
ns.tocversion = tocversion
ns.isForever = (WOW_PROJECT_CAMELOT ~= nil and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT)
	or (tocversion >= 16000 and tocversion < 20000)
ns.version = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version")) or "dev"

------------------------------------------------------------------------
-- Utilities
------------------------------------------------------------------------

function ns:Print(...)
	print("|cFF33BBFFdMouseOverCasts|r:", ...)
end

function ns.CopyTable(src)
	if type(src) ~= "table" then
		return src
	end
	local dst = {}
	for k, v in pairs(src) do
		dst[k] = ns.CopyTable(v)
	end
	return dst
end

-- First count characters of a UTF-8 string.
function ns.Utf8Truncate(text, count)
	local chars, bytes = 0, 0
	for char in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
		chars = chars + 1
		if chars > count then
			break
		end
		bytes = bytes + #char
	end
	return text:sub(1, bytes)
end

-- Lower case for comparing names. string.lower is only sure about ASCII, so the capitals of
-- Cyrillic and of accented Latin are folded by hand (their UTF-8 bytes, lead byte 208 or 195).
function ns.Fold(text)
	text = text:lower()
	text = text:gsub("\208([\144-\159])", function(byte) -- А-П
		return "\208" .. string.char(byte:byte() + 32)
	end)
	text = text:gsub("\208([\160-\175])", function(byte) -- Р-Я
		return "\209" .. string.char(byte:byte() - 32)
	end)
	text = text:gsub("\208\129", "\209\145") -- Ё
	text = text:gsub("\195([\128-\158])", function(byte) -- À-Þ
		return "\195" .. string.char(byte:byte() + 32)
	end)
	return text
end

-- Returns name and icon of a spell ID, or nil while the spell data is not cached.
function ns.GetSpellNameAndIcon(spellID)
	if C_Spell and C_Spell.GetSpellName then
		return C_Spell.GetSpellName(spellID), C_Spell.GetSpellTexture(spellID)
	end
	if GetSpellInfo then
		local name, _, icon = GetSpellInfo(spellID)
		return name, icon
	end
end

-- Looks a spell up by name in the spellbook. Returns spellID and icon, or nil if it is unknown.
function ns.FindSpellByName(name)
	if C_Spell and C_Spell.GetSpellInfo then
		local info = C_Spell.GetSpellInfo(name)
		if info then
			return info.spellID, info.iconID
		end
	elseif GetSpellInfo then
		local _, _, icon, _, _, _, spellID = GetSpellInfo(name)
		if spellID or icon then
			return spellID, icon
		end
	end
end

-- Turns user input (name, "Name(Rank 2)", spell ID or spell link) into the text /cast needs.
-- Returns text, icon, known: known is false for names the spellbook does not have (items,
-- spells not learned yet); such text is still cast as typed.
function ns.ResolveSpell(input)
	local text = strtrim(input or "")
	if text == "" then
		return nil
	end
	local id = tonumber(text) or tonumber(text:match("|Hspell:(%d+)") or text:match("^spell:(%d+)") or "")
	if id then
		local name, icon = ns.GetSpellNameAndIcon(id)
		if name then
			return name, icon, true
		end
		return nil
	end
	local base = text:gsub("%s*%(.-%)%s*$", "")
	local spellID, icon = ns.FindSpellByName(base)
	return text, icon, spellID ~= nil
end

------------------------------------------------------------------------
-- Slash commands and addon compartment
------------------------------------------------------------------------

local function HandleSlash(msg)
	local command = strtrim((msg or ""):lower())
	if command == "" or command == "config" or command == "options" then
		ns.Options:Open()
	elseif command == "list" then
		ns.Macros:PrintAll()
	else
		ns:Print(L["Commands:"])
		print("  /dmo - " .. L["open settings"])
		print("  /dmo list - " .. L["show the macros in chat"])
	end
end

SLASH_DMOUSEOVERCASTS1 = "/dmo"
SLASH_DMOUSEOVERCASTS2 = "/dmouseover"
SlashCmdList.DMOUSEOVERCASTS = HandleSlash

function dMouseOverCasts_OnAddonCompartmentClick()
	ns.Options:Open()
end

function dMouseOverCasts_OnAddonCompartmentEnter(_, menuButtonFrame)
	GameTooltip:SetOwner(menuButtonFrame, "ANCHOR_LEFT")
	GameTooltip:SetText("dMouseOverCasts")
	GameTooltip:AddLine(L["Click: settings"], 1, 1, 1)
	GameTooltip:Show()
end

function dMouseOverCasts_OnAddonCompartmentLeave()
	GameTooltip:Hide()
end

------------------------------------------------------------------------
-- Startup
------------------------------------------------------------------------

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(_, event, name)
	if event == "ADDON_LOADED" then
		if name == ADDON then
			ns.Profile:Init()
			ns.Options:Init()
		end
	elseif event == "PLAYER_LOGIN" then
		ns.Macros:Init()
	end
end)
