-- dMouseOverCasts tests. Globals provided by the runner: TEST_DIR, ADDON_DIR, SCENARIO.
package.path = TEST_DIR .. "/?.lua;" .. package.path
local M = require("wowmock")

M.toc = SCENARIO == "retail" and 120100 or 16001
M.locale = SCENARIO == "retail" and "enUS" or "ruRU"
M.Install(_G)

if SCENARIO == "saved" then
	-- Saved by version 1, which bound keys per specialization.
	dMouseOverCastsDB = {
		version = 1,
		enabled = true,
		chars = {
			["Danpiel-Forever"] = { specs = {
				[1] = { binds = {
					{ key = "E", help = "Flash Heal", harm = "Smite", fallback = "bogus", selfCast = "yes" },
					"garbage",
				} },
				[2] = { binds = {
					{ key = "Q", help = "Flash Heal", harm = "Smite" },
					{ key = "R", harm = "Mind Blast", skipDead = false },
				} },
			} },
			["Broken-Realm"] = "garbage",
		},
	}
end

-- Macros as data versions 2 and 3 wrote them, and the text they get now.
local RENEW_BODY = "#showtooltip\n/cast [@mouseover,help,nodead]Flash Heal;[@mouseover,harm,nodead]Smite;"
	.. "[help,nodead]Flash Heal;[harm,nodead]Smite;[@player]Flash Heal"
local SMITE_BODY = "#showtooltip\n/cast [@mouseover,harm,nodead]Smite;[harm,nodead]Smite"
local RENEW_SHORT = "#showtooltip\n/cast [@mouseover,help,nodead]Flash Heal;[@mouseover,harm,nodead][harm,nodead]Smite;Flash Heal"
local SMITE_SHORT = "#showtooltip\n/cast [@mouseover,harm,nodead][harm,nodead]Smite"
local FLAMESTRIKE = "/cast [@cursor] Flamestrike"

if SCENARIO == "long" then
	-- Saved by data version 3, which named the helpful spell three times and the harmful one twice.
	dMouseOverCastsDB = {
		version = 3,
		chars = {
			["Danpiel-Forever"] = { macros = {
				{ name = "Renew", customName = "Renew", scope = "general", created = true, help = "Flash Heal", harm = "Smite" },
				-- These spells did not fit, so the game macro still has the text of the pair before.
				{ name = "Touch", customName = "Touch", scope = "char", created = true, help = "Целительное прикосновение", harm = "Лунный огонь" },
				{ name = "Own", customName = "Own", scope = "char", created = true, custom = true, macro = FLAMESTRIKE },
				-- And these never did: no game macro yet.
				{ name = "", scope = "char", created = false, help = "Целительное прикосновение", harm = "Гнев" },
			} },
		},
	}
	M.macros.general[1] = { name = "Renew", icon = M.QUESTION_MARK, body = RENEW_BODY }
	M.macros.char[1] = { name = "Touch", icon = M.QUESTION_MARK, body = RENEW_BODY }
	M.macros.char[2] = { name = "Own", icon = M.QUESTION_MARK, body = FLAMESTRIKE }
end

if SCENARIO == "pinned" then
	-- Saved by data version 2, which wrote the icon of the spell shown at that moment into every
	-- macro it edited: the buttons were stuck on the helpful spell.
	dMouseOverCastsDB = {
		version = 2,
		chars = {
			["Danpiel-Forever"] = { macros = {
				{ name = "Renew", customName = "Renew", scope = "general", created = true, help = "Flash Heal", harm = "Smite" },
				{ name = "Smite", scope = "char", created = true, harm = "Smite" },
				{ name = "Gone", customName = "Gone", scope = "char", created = true, help = "Lesser Heal" },
				{ name = "", scope = "char", created = false, help = "Resurrection" },
			} },
			["Alt-Forever"] = { macros = {
				{ name = "Alt", scope = "char", created = true, harm = "Mind Blast" },
			} },
		},
	}
	M.macros.general[1] = { name = "Renew", icon = 3061, body = RENEW_BODY }
	M.macros.char[1] = { name = "Smite", icon = 1585, body = SMITE_BODY }
	M.macros.char[2] = { name = "Mine", icon = 3061, body = "#showtooltip\n/cast Flash Heal" }
	M.inCombat = true -- /reload in the middle of a fight
end

local passed, failed = 0, 0
local function check(cond, label)
	if cond then
		passed = passed + 1
	else
		failed = failed + 1
		print("FAIL [" .. SCENARIO .. "] " .. label)
	end
end

M.spells = {
	[2050] = { name = "Lesser Heal", rank = "Rank 1", help = true }, [2052] = { name = "Lesser Heal", rank = "Rank 2", help = true },
	[2061] = { name = "Flash Heal", help = true }, [585] = { name = "Smite", harm = true },
	[2006] = { name = "Resurrection", help = true }, [8092] = { name = "Mind Blast", harm = true },
	[47540] = { name = "Penance", help = true, harm = true }, [15473] = { name = "Shadowform" },
	[774] = { name = "Омоложение", help = true }, [8921] = { name = "Лунный огонь", harm = true },
	[20711] = { name = "Spirit of Redemption" }, [34914] = { name = "Vampiric Touch", harm = true },
	[6603] = { name = "Auto Attack", harm = true }, [9999] = { name = "Greater Heal", help = true },
	[10059] = { name = "Portal: Stormwind" }, [11416] = { name = "Portal: Ironforge" },
}
-- The spellbook: a spell on two tabs, a passive one, a lower rank, a rank not learned yet, a
-- flyout with one known portal, the tab of another specialization and a hidden tab.
M.book = {
	{ name = "General", items = { { id = 2061 }, { id = 20711, passive = true } } },
	{ name = "Priest", items = {
		{ id = 2052 }, { id = 2050, lowRank = true }, { id = 2061 }, { id = 585 }, { id = 8092 }, { id = 2006 },
		{ id = 47540 }, { id = 15473 }, { id = 774 }, { id = 8921 }, { id = 9999, future = true }, { flyout = 1 },
	} },
	{ name = "Shadow", offSpec = 258, items = { { id = 34914 } } },
	{ name = "Hidden", hidden = true, items = { { id = 6603 } } },
}
M.flyouts = { [1] = { { id = 10059, known = true }, { id = 11416 } } }
local HAS_RANKS = M.toc == 16001 -- only WoW Forever lists lower ranks

-- Load the addon in TOC order ---------------------------------------------
local ns = {}
local files = {}
for line in io.lines(ADDON_DIR .. "/dMouseOverCasts.toc") do
	if line:match("%.lua%s*$") then
		files[#files + 1] = line:gsub("%s+$", "")
	end
end
check(#files == 7, "toc lists 7 lua files")
for _, file in ipairs(files) do
	local chunk = assert(loadfile(ADDON_DIR .. "/" .. file))
	chunk("dMouseOverCasts", ns)
end

local Macro, Macros, Profile, Options = ns.Macro, ns.Macros, ns.Profile, ns.Options

-- Macro builder ------------------------------------------------------------
local function entry(fields)
	local e = Profile.NewEntry()
	for k, v in pairs(fields) do e[k] = v end
	return e
end

check(Macro.Build(entry({ help = "Flash Heal", harm = "Smite" }))
	== "#showtooltip\n/cast [@mouseover,help,nodead]Flash Heal;[@mouseover,harm,nodead][harm,nodead]Smite;Flash Heal",
	"both spells, all fallbacks: the mouse, the enemy target, a plain cast")
check(Macro.Build(entry({ help = "Flash Heal", harm = "Smite", selfCast = false }))
	== "#showtooltip\n/cast [@mouseover,help,nodead]Flash Heal;[@mouseover,harm,nodead][harm,nodead]Smite;[help,nodead]Flash Heal",
	"both spells, no self-cast: only a friendly target gets the helpful spell")
check(Macro.Build(entry({ help = "Flash Heal", harm = "Smite", fallback = "none" }))
	== "#showtooltip\n/cast [@mouseover,harm,nodead]Smite;[@mouseover,help,nodead][@player]Flash Heal",
	"both spells, the mouse or yourself: each name once")
check(Macro.Build(entry({ help = "Flash Heal", harm = "Smite", fallback = "none", selfCast = false }))
	== "#showtooltip\n/cast [@mouseover,help,nodead]Flash Heal;[@mouseover,harm,nodead]Smite", "both spells, the mouse only")
check(Macro.Build(entry({ help = "Flash Heal" }))
	== "#showtooltip\n/cast [@mouseover,help,nodead][]Flash Heal", "helpful only, all fallbacks")
check(Macro.Build(entry({ help = "Flash Heal", fallback = "none" }))
	== "#showtooltip\n/cast [@mouseover,help,nodead][@player]Flash Heal", "helpful only, the mouse or yourself")
check(Macro.Build(entry({ help = "Flash Heal", fallback = "none", selfCast = false }))
	== "#showtooltip\n/cast [@mouseover,help,nodead]Flash Heal", "helpful only, no fallbacks")
check(Macro.Build(entry({ harm = "Smite" }))
	== "#showtooltip\n/cast [@mouseover,harm,nodead][harm,nodead]Smite", "harmful only: no self-cast")
check(Macro.Build(entry({ help = "Resurrection", skipDead = false, selfCast = false }))
	== "#showtooltip\n/cast [@mouseover,help][help]Resurrection", "resurrection keeps dead units")
check(Macro.Build(entry({ help = "  " })) == nil, "no spells, no macro")
check(not Macro.Build(entry({ harm = "Smite; [@player] Evil\n/run x()" })):find("[;\n]/run"), "spell text cannot add clauses or lines")
check(Macro.Build(entry({ custom = true, macro = " /cast [@cursor] Flamestrike ", help = "x" })) == "/cast [@cursor] Flamestrike", "custom macro")
local russian = Macro.Build(entry({ help = "Быстрое исцеление", harm = "Кара" }))
check(#russian <= 255 and Macro.Problem(russian) == nil, "typical Russian macro fits in 255 bytes (" .. #russian .. ")")
-- Long names: 49 and 23 bytes. Named three and two times, as before, they took 299 bytes.
local long = Macro.Build(entry({ help = "Целительное прикосновение", harm = "Лунный огонь" }))
check(long == "#showtooltip\n/cast [@mouseover,help,nodead]Целительное прикосновение;"
	.. "[@mouseover,harm,nodead][harm,nodead]Лунный огонь;Целительное прикосновение" and #long == 203 and Macro.Problem(long) == nil,
	"long Russian names fit: the helpful spell twice, the harmful one once")
local function times(text, name)
	return select(2, text:gsub(name, ""))
end
for _, selfCast in ipairs({ true, false }) do
	local once = Macro.Build(entry({ help = "Flash Heal", harm = "Smite", fallback = "none", selfCast = selfCast }))
	check(times(once, "Flash Heal") == 1 and times(once, "Smite") == 1, "without the target every name is written once")
	for _, fallback in ipairs({ "target", "none" }) do
		local single = Macro.Build(entry({ help = "Flash Heal", fallback = fallback, selfCast = selfCast }))
		check(times(single, "Flash Heal") == 1, "one spell is always written once")
	end
end
check(Macro.Problem(string.rep("a", 256)) == "toolong" and Macro.Problem(nil) == "empty", "macro problems")
check(ns.Utf8Truncate("Быстрое исцеление", 7) == "Быстрое" and ns.Utf8Truncate("abc", 16) == "abc", "UTF-8 truncation")

-- What the generated macro casts, read the way the game reads it --------------
local function casts(fields, units)
	M.units = units
	local spell = M.MacroSpell(Macro.Build(entry(fields)))
	M.units = {}
	return spell
end
local FRIEND, ENEMY, CORPSE = { friend = true }, { friend = false }, { friend = false, dead = true }
local both = { help = "Flash Heal", harm = "Smite" }
check(casts(both, { mouseover = FRIEND }) == "Flash Heal", "friend under the mouse: helpful spell")
check(casts(both, { mouseover = ENEMY }) == "Smite", "enemy under the mouse: harmful spell")
check(casts(both, { mouseover = ENEMY, target = FRIEND }) == "Smite", "enemy under the mouse wins over a friendly target")
check(casts(both, { mouseover = FRIEND, target = ENEMY }) == "Flash Heal", "friend under the mouse wins over an enemy target")
check(casts(both, { target = ENEMY }) == "Smite", "nothing under the mouse: harmful spell on the enemy target")
check(casts(both, { target = FRIEND }) == "Flash Heal", "nothing under the mouse: helpful spell on the friendly target")
check(casts(both, {}) == "Flash Heal", "nobody around: the helpful spell, cast the way its button casts it")
check(casts(both, { mouseover = CORPSE }) == "Flash Heal", "dead enemy under the mouse is skipped")
check(casts({ harm = "Smite" }, { mouseover = ENEMY }) == "Smite", "harmful only: enemy under the mouse")
check(casts({ harm = "Smite" }, { mouseover = FRIEND }) == nil, "harmful only: nothing cast on a friend")
check(casts({ harm = "Smite", fallback = "none" }, { target = ENEMY }) == nil, "no fallback: the target is ignored")
check(casts({ help = "Flash Heal", harm = "Smite", selfCast = false }, {}) == nil, "no self-cast: nothing cast with nobody around")

-- Every set of options and spells, with every unit under the mouse and in the target, against the
-- order the options stand for: the unit under the mouse, then the target, then yourself. The
-- second value is the unit the macro names; nil is a cast the game aims itself.
local DEAD_FRIEND = { friend = true, dead = true }
local UNITS = { false, FRIEND, ENEMY, DEAD_FRIEND, CORPSE }
local function wanted(fields, units)
	local function suits(unit, friend)
		return unit and unit.friend == friend and not (fields.skipDead and unit.dead)
	end
	local help, harm, target = fields.help, fields.harm, fields.fallback == "target"
	if help and suits(units.mouseover, true) then
		return help, "mouseover"
	elseif harm and suits(units.mouseover, false) then
		return harm, "mouseover"
	elseif target and harm and suits(units.target, false) then
		return harm
	elseif target and help and (fields.selfCast or suits(units.target, true)) then
		return help -- with the self-cast a plain cast: the friendly target, else yourself
	elseif help and fields.selfCast then
		return help, "player"
	end
end
local cases, wrong = 0, {}
for _, spells in ipairs({ both, { help = "Flash Heal" }, { harm = "Smite" } }) do
	for _, fallback in ipairs({ "target", "none" }) do
		for _, selfCast in ipairs({ true, false }) do
			for _, skipDead in ipairs({ true, false }) do
				local fields = { help = spells.help, harm = spells.harm, fallback = fallback, selfCast = selfCast, skipDead = skipDead }
				local text = Macro.Build(entry(fields))
				for _, mouseover in ipairs(UNITS) do
					for _, target in ipairs(UNITS) do
						M.units = { mouseover = mouseover or nil, target = target or nil }
						local spell, unit = M.MacroSpell(text)
						local wantedSpell, wantedUnit = wanted(fields, M.units)
						cases = cases + 1
						if spell ~= wantedSpell or unit ~= wantedUnit then
							wrong[#wrong + 1] = text
						end
					end
				end
			end
		end
	end
end
M.units = {}
check(cases == 600 and #wrong == 0, "every set of options casts the right spell at the right unit (" .. #wrong .. " of " .. cases .. " wrong: " .. tostring(wrong[1]) .. ")")

-- Spell input ---------------------------------------------------------------
local text, icon, known = ns.ResolveSpell("2061")
check(text == "Flash Heal" and icon == 3061 and known, "spell ID resolves to its name")
check(ns.ResolveSpell("|cff71d5ff|Hspell:585:0|h[Smite]|h|r") == "Smite", "spell link resolves")
text, icon, known = ns.ResolveSpell("Lesser Heal(Rank 1)")
check(text == "Lesser Heal(Rank 1)" and known and icon == 3052, "explicit rank is kept")
text, icon, known = ns.ResolveSpell("Healthstone")
check(text == "Healthstone" and not known, "unknown names are kept as typed")
check(ns.ResolveSpell("999999") == nil, "unknown spell ID is rejected")

-- Spellbook list: what is offered -----------------------------------------------
local function texts(items)
	local list = {}
	for i, item in ipairs(items) do
		list[i] = (item.spell or item).text
	end
	return table.concat(list, ", ")
end
local RANK1 = HAS_RANKS and ", Lesser Heal(Rank 1)" or ""
local book = ns.Spellbook.Read()
check(texts(book) == "Flash Heal, Lesser Heal" .. RANK1 .. ", Smite, Mind Blast, Resurrection, Penance, Shadowform, Омоложение, Лунный огонь, Portal: Stormwind",
	"spellbook: castable spells once, known flyout spells, nothing passive, unlearned, off-spec or hidden")
check(book[1].icon == 3061 and book[#book].icon == 11059, "spellbook icons")
local function search(query, kind)
	return texts(ns.Spellbook.Search(book, query, kind))
end
check(search("", "help") == "Flash Heal, Lesser Heal, Penance, Resurrection, Омоложение, Mind Blast, Portal: Stormwind, Shadowform, Smite, Лунный огонь",
	"no text: the whole book, spells for friends first")
check(search("", "harm") == "Mind Blast, Penance, Smite, Лунный огонь, Flash Heal, Lesser Heal, Portal: Stormwind, Resurrection, Shadowform, Омоложение",
	"no text: the whole book, spells for enemies first")
check(search("he", "help") == "Flash Heal, Lesser Heal", "text anywhere in the name")
check(search("s", "harm") == "Smite, Mind Blast, Shadowform, Flash Heal, Lesser Heal, Portal: Stormwind, Resurrection",
	"fitting spells first, then names starting with the text")
check(search("ОМОЛ", "help") == "Омоложение" and search(" лунный О", "harm") == "Лунный огонь", "Cyrillic letters match in any case")
check(ns.Fold("ЁЖ в ÄÖ Abc") == "ёж в äö abc", "capitals folded")
check(search("lesser h", "help") == "Lesser Heal", "lower ranks stay out while the name is being typed")
check(search("Lesser Heal", "help") == "Lesser Heal" .. RANK1, "whole name typed: its lower ranks follow")
check(search("lesser heal(rank 1)", "help") == (HAS_RANKS and "Lesser Heal(Rank 1)" or ""), "a rank typed in full")
check(search("healthstone", "help") == "", "nothing for a name the book does not have")
local heals = {
	{ text = "Healing Rain", name = "Healing Rain", key = "healing rain", nameKey = "healing rain", harm = true },
	{ text = "Heal", name = "Heal", key = "heal", nameKey = "heal" },
}
check(texts(ns.Spellbook.Search(heals, "heal", "harm")) == "Heal, Healing Rain", "the spell typed in full comes first")
C_SpellBook.GetSpellBookItemInfo, heals = nil, C_SpellBook.GetSpellBookItemInfo
check(#ns.Spellbook.Read() == 0, "a client without this spellbook API: no list, no error")
C_SpellBook.GetSpellBookItemInfo = heals

-- Startup ------------------------------------------------------------------
M.FireEvent("ADDON_LOADED", "dMouseOverCasts")
M.FireEvent("PLAYER_LOGIN")
check(ns.isForever == (SCENARIO ~= "retail"), "game detection")
check(dMouseOverCastsDB.version == 4 and dMouseOverCastsDB.chars["Danpiel-Forever"], "character profile created")
check(#M.categories == 1 and M.categories[1].name == "dMouseOverCasts", "own page in Options > AddOns")

-- The icon the game shows for a macro right now.
local function shown(name)
	local _, icon = GetMacroInfo(GetMacroIndexByName(name))
	return icon
end

if SCENARIO == "pinned" then
	local entries = Profile:GetEntries()
	check(#entries == 4 and (M.macroWrites or 0) == 0 and M.Macro("Renew").icon == 3061, "no macro touched in combat")
	M.units = { mouseover = ENEMY }
	check(shown("Renew") == 3061, "pinned icon ignores the enemy under the mouse")
	M.inCombat = false
	M.FireEvent("PLAYER_REGEN_ENABLED")
	check(M.Macro("Renew").icon == Macros.ICON and M.Macro("Smite").icon == Macros.ICON, "pinned icons replaced by the question mark after combat")
	check(M.Macro("Renew").body == RENEW_SHORT and M.Macro("Renew").scope == "general" and M.Macro("Smite").body == SMITE_SHORT,
		"the same write shortens the text, the place is untouched")
	check(M.Macro("Mine").icon == 3061, "the player's own macro keeps its icon")
	check(M.macroWrites == 2 and #M.macros.char == 2 and #M.macros.general == 1, "one write per pinned macro, none created")
	check(shown("Renew") == 1585, "enemy under the mouse: the button shows the harmful spell")
	M.units = { mouseover = FRIEND }
	check(shown("Renew") == 3061, "friend under the mouse: the button shows the helpful spell")
	M.units = {}
	check(shown("Smite") == Macros.ICON, "harmful only, nobody to hit: question mark")
	check(not entries[1].rewrite and not entries[2].rewrite, "restored macros are not flagged any more")
	check(entries[3].rewrite == true and not entries[4].rewrite, "a deleted macro waits, a macro never created needs nothing")
	check(dMouseOverCastsDB.chars["Alt-Forever"].macros[1].rewrite == true, "another character's macro waits for that character")
	M.FireEvent("UPDATE_MACROS")
	M.FireEvent("PLAYER_REGEN_ENABLED")
	check(M.macroWrites == 2, "icons restored once")
	Macros:PickUp(entries[3])
	check(M.Macro("Gone").icon == Macros.ICON and not entries[3].rewrite and M.macroWrites == 3, "deleted macro created again with the question mark")
	-- Next login: the data is of the current version now.
	Profile:Init()
	M.FireEvent("PLAYER_LOGIN")
	local flagged = 0
	for _, e in ipairs(Profile:GetEntries()) do
		flagged = flagged + (e.rewrite and 1 or 0)
	end
	check(flagged == 0 and M.macroWrites == 3, "nothing left to restore on the next login")
	check(dMouseOverCastsDB.chars["Alt-Forever"].macros[1].rewrite == true, "the other character is still waiting")
	return print(string.format("RESULT %s passed=%d failed=%d", SCENARIO, passed, failed))
end

if SCENARIO == "long" then
	local entries = Profile:GetEntries()
	check(M.Macro("Renew").body == RENEW_SHORT and M.Macro("Renew").scope == "general", "macro of data version 3 shortened on login")
	local touch = M.Macro("Touch").body
	check(touch == Macro.Build(entries[2]) and touch:find("Целительное прикосновение", 1, true) and #touch == 203,
		"spells that did not fit before are in the macro now")
	check(M.Macro("Own").body == FLAMESTRIKE, "a macro edited by hand keeps its text")
	check(M.macroWrites == 3 and #M.macros.char == 2 and #M.macros.general == 1, "one write per macro, none created")
	check(Macros:Status(entries[4]) == "new" and not entries[4].created, "spells that never fit: the macro can be created now")
	local flagged = 0
	for _, e in ipairs(entries) do
		flagged = flagged + (e.rewrite and 1 or 0)
	end
	check(flagged == 0, "no macro left to write again")
	Profile:Init()
	M.FireEvent("PLAYER_LOGIN")
	M.FireEvent("UPDATE_MACROS")
	check(M.macroWrites == 3, "nothing written on the next login")
	return print(string.format("RESULT %s passed=%d failed=%d", SCENARIO, passed, failed))
end

if SCENARIO == "saved" then
	check(dMouseOverCastsDB.chars["Broken-Realm"] == nil and dMouseOverCastsDB.enabled == nil, "old data cleaned up")
	local entries = Profile:GetEntries()
	check(#entries == 2, "binds of both specs became macros, duplicates merged")
	check(entries[1].help == "Flash Heal" and entries[1].fallback == "target" and entries[1].selfCast == true and entries[1].key == nil, "bind converted")
	check(entries[2].harm == "Mind Blast" and entries[2].skipDead == false, "second spec bind kept")
	check(not entries[1].created and #M.macros.char == 0, "no game macros written on login")
	check(Macros:Status(entries[1]) == "new", "converted entry waits to be created")
	Macros:PickUp(entries[1])
	check(M.Macro("Flash Heal") and M.cursor[1] == "macro", "picking it up creates the macro")
	return print(string.format("RESULT %s passed=%d failed=%d", SCENARIO, passed, failed))
end

-- The player's own macros, which the addon must never touch.
M.macros.char[1] = { name = "Flash Heal", icon = 1, body = "/cast Flash Heal" }
M.macros.general[1] = { name = "Mount", icon = 2, body = "/cast Swift Horse" }

-- Settings page --------------------------------------------------------------
SlashCmdList.DMOUSEOVERCASTS("")
check(M.openedCategory == 77 and Options.created, "/dmo opens the settings page")
check(not Options.editor:IsShown() and Options.emptyText:IsShown(), "empty list")

M.Click(Options.addButton)
local e1 = Profile:GetEntries()[1]
check(e1 and Options.selected == e1 and Options.editor:IsShown(), "new macro selected")
check(Macros:Status(e1) == "empty" and #M.macros.char == 1, "no game macro without spells")
check(not Options.pickupButton:IsEnabled(), "nothing to pick up yet")

-- Spells create the macro
M.Type(Options.helpRow.box, "2061")
check(e1.help == "Flash Heal", "typed spell ID stored as name")
check(e1.created and e1.name == "Flash Heal 2", "macro named after the spell, the player's own name avoided")
local own = M.Macro("Flash Heal")
check(own.body == "/cast Flash Heal" and own.icon == 1, "the player's macro untouched")
local mine = M.Macro("Flash Heal 2")
check(mine and mine.scope == "char" and mine.icon == Macros.ICON and mine.body == Macro.Build(e1), "character macro created")
check(Macros:Status(e1) == "ok" and Options.pickupButton:IsEnabled(), "ready to drag")

M.Type(Options.harmRow.box, "Smite")
check(M.Macro("Flash Heal 2").body == Macro.Build(e1) and #M.macros.char == 2, "macro updated in place")

-- The button follows the spell: the macro keeps the question mark icon through every edit
check(M.Macro("Flash Heal 2").icon == Macros.ICON, "edited macro keeps the question mark icon")
check(shown("Flash Heal 2") == 3061, "nobody around: the button shows the helpful spell")
M.units = { mouseover = ENEMY }
check(shown("Flash Heal 2") == 1585, "enemy under the mouse: the button shows the harmful spell")
M.Type(Options.harmRow.box, "Mind Blast")
check(M.Macro("Flash Heal 2").icon == Macros.ICON and shown("Flash Heal 2") == 9092, "edit with an enemy under the mouse does not pin the icon")
M.Type(Options.harmRow.box, "Smite")
M.units = { mouseover = FRIEND }
check(M.Macro("Flash Heal 2").icon == Macros.ICON and shown("Flash Heal 2") == 3061, "friend under the mouse: the button shows the helpful spell")
M.units = {}
M.Type(Options.helpRow.box, "999999")
check(e1.help == "Flash Heal" and Options.helpRow.box:GetText() == "Flash Heal", "unknown ID rejected")

-- Drag to the action bar
M.cursor = nil
Options.macroIcon.__scripts.OnDragStart(Options.macroIcon)
check(M.cursor and M.cursor[1] == "macro" and select(1, GetMacroInfo(M.cursor[2])) == "Flash Heal 2", "icon drag picks up the macro")
M.cursor = nil
M.Click(Options.pickupButton)
check(M.cursor and M.cursor[1] == "macro", "button picks up the macro")
M.cursor = nil

-- Name
M.Type(Options.nameBox, "Mount")
check(e1.customName == "" and M.Macro("Mount").body == "/cast Swift Horse", "name of another macro rejected")
M.Type(Options.nameBox, "Хил и Кара по маусоверу")
check(e1.customName == "Хил и Кара по ма" and M.Macro("Хил и Кара по ма") and #M.macros.char == 2, "own name, cut to 16 letters, macro renamed")
M.Type(Options.nameBox, "")
check(e1.customName == "" and e1.name == "Flash Heal 2", "empty name: back to the spell name")

-- Options
local writes = M.macroWrites
check(M.Macro("Flash Heal 2").body == RENEW_SHORT, "all fallbacks: the macro ends with a plain cast of the helpful spell")
Options.selfCheck:SetChecked(false)
M.Click(Options.selfCheck)
check(e1.selfCast == false and M.Macro("Flash Heal 2").body == RENEW_SHORT:gsub(";Flash Heal$", ";[help,nodead]Flash Heal"),
	"self-cast option: off, only a friendly target gets the helpful spell")
check(M.macroWrites == writes + 1, "one write per change")
Options.deadCheck:SetChecked(false)
M.Click(Options.deadCheck)
check(e1.skipDead == false and not M.Macro("Flash Heal 2").body:find("nodead"), "dead units option")
local menu = Options.fallbackDropdown.__lastMenu
check(menu and #menu.items == 2, "fallback dropdown has two choices")
menu.items[2][3]()
check(e1.fallback == "none" and M.Macro("Flash Heal 2").body == "#showtooltip\n/cast [@mouseover,help]Flash Heal;[@mouseover,harm]Smite", "fallback set to none")
check(Options.macroBox:GetText() == Macro.Build(e1), "macro preview")

-- Scope
Options.scopeDropdown.__lastMenu.items[2][3]()
local moved = M.Macro("Flash Heal 2")
check(e1.scope == "general" and moved and moved.scope == "general" and #M.macros.char == 1, "moved to general macros")

-- Generated macro is read-only; custom macro is editable
M.Type(Options.macroBox, "/cast hacked")
check(not e1.custom and Options.macroBox:GetText() == Macro.Build(e1), "generated macro cannot be edited")
Options.customCheck:SetChecked(true)
M.Click(Options.customCheck)
check(e1.custom and e1.macro == "#showtooltip\n/cast [@mouseover,help]Flash Heal;[@mouseover,harm]Smite", "custom macro seeded from the generated one")
M.Type(Options.macroBox, "#showtooltip\n/cast [@cursor] Blizzard")
check(M.Macro("Flash Heal 2").body == "#showtooltip\n/cast [@cursor] Blizzard", "custom macro written")
M.Type(Options.macroBox, "/cast " .. string.rep("x", 300))
check(Macros:Status(e1) == "toolong" and M.Macro("Flash Heal 2").body == "#showtooltip\n/cast [@cursor] Blizzard", "too long macro not written")
check(Options.macroNote:GetText():find("306 / 255", 1, true), "length counter")
Options.customCheck:SetChecked(false)
M.Click(Options.customCheck)

-- Deleted in the macro window
DeleteMacro(GetMacroIndexByName("Flash Heal 2"))
M.FireEvent("UPDATE_MACROS")
check(Macros:Status(e1) == "missing", "deleted macro noticed")
M.Click(Options.pickupButton)
check(M.Macro("Flash Heal 2") and M.cursor and M.cursor[1] == "macro", "picking it up creates it again")
M.cursor = nil

-- Combat
M.inCombat = true
local ok, err = pcall(M.Type, Options.helpRow.box, "Lesser Heal")
check(ok, "change in combat does not call protected API: " .. tostring(err))
check(Macros.pending[e1] and M.Macro("Flash Heal 2"), "change waits for the end of combat")
check(Options.statusText:GetText():find("\n", 1, true), "combat note shown")
M.inCombat = false
M.FireEvent("PLAYER_REGEN_ENABLED")
check(not Macros.pending[e1] and M.Macro("Lesser Heal") and not M.Macro("Flash Heal 2"), "written after combat")

-- Spell input by drag and link
M.Click(Options.addButton)
local e2 = Options.selected
check(e2 ~= e1 and #Profile:GetEntries() == 2, "second macro")
M.cursor = { "spell", 12, "spell", 8092 }
Options.harmRow.icon.__scripts.OnReceiveDrag(Options.harmRow.icon)
check(e2.harm == "Mind Blast" and M.cursor == nil and M.Macro("Mind Blast").scope == "char", "spell dragged from the spellbook")
Options.helpRow.box:SetFocus()
ChatEdit_InsertLink("|cff71d5ff|Hspell:2006:0|h[Resurrection]|h|r")
check(e2.help == "Resurrection" and not Options.helpRow.box:HasFocus(), "shift-clicked spell link inserted")
check(e2.name == "Resurrection" and M.Macro("Resurrection") and not M.Macro("Mind Blast"), "name follows the first spell")
M.cursor = { "item", 5512, "|Hitem:5512|h[Healthstone]|h" }
M.Click(Options.helpRow.icon, "LeftButton")
check(e2.help == "Healthstone" and Options.helpRow.note:GetText() ~= "", "item dropped, flagged as not a spell")
M.Click(Options.helpRow.icon, "RightButton")
check(e2.help == "" and M.Macro("Mind Blast"), "right click clears spell")

-- Spellbook list under the spell boxes ---------------------------------------
local Suggest, helpBox, harmBox = Options.Suggest, Options.helpRow.box, Options.harmRow.box
local function open()
	return Suggest.frame:IsShown()
end
local function offered()
	return texts(Suggest.items)
end
local function highlighted()
	for index, row in ipairs(Suggest.list.__rows) do
		if row.selectedTexture:IsShown() then
			return index
		end
	end
end
check(not open(), "no list until asked for")

-- Typing: Enter takes the highlighted spell
M.Input(helpBox, "fl")
check(open() and offered() == "Flash Heal" and Suggest.selected == 1 and highlighted() == 1, "typing opens the list, the spell starting with the text is highlighted")
check(Suggest.list.__rows[1].text:GetText() == "Flash Heal" and Suggest.list.__rows[1].icon:GetTexture() == 3061, "row shows the icon and the name")
M.Key(helpBox, "ENTER")
check(e2.help == "Flash Heal" and not open() and not helpBox:HasFocus(), "Enter takes the highlighted spell")
check(M.Macro(e2.name).body == Macro.Build(e2) and Macro.Build(e2):find("]Flash Heal;", 1, true), "and it goes into the macro")

-- Text inside the names: nothing highlighted, Tab takes the first, Enter keeps the text
M.Input(helpBox, "sur")
check(offered() == "Resurrection" and Suggest.selected == nil and highlighted() == nil, "text inside a name: nothing highlighted")
M.Key(helpBox, "TAB")
check(e2.help == "Resurrection" and not open() and not helpBox:HasFocus(), "Tab takes the first spell")
M.Input(helpBox, "heal")
check(offered() == "Flash Heal, Lesser Heal", "two spells offered")
M.Key(helpBox, "ENTER")
check(e2.help == "heal" and not open() and Options.helpRow.note:GetText() ~= "", "Enter without a highlight keeps the text as typed")

-- Up and Down
M.Input(harmBox, "s")
check(offered() == "Smite, Mind Blast, Shadowform, Flash Heal, Lesser Heal, Portal: Stormwind, Resurrection" and Suggest.selected == 1, "harmful box: spells for enemies first")
M.Key(harmBox, "DOWN")
check(Suggest.selected == 2 and highlighted() == 2 and Suggest.list.__scrolledTo == 2, "Down moves the highlight and keeps it in view")
M.Key(harmBox, "UP")
M.Key(harmBox, "UP")
check(Suggest.selected == nil and highlighted() == nil, "Up past the first row: nothing highlighted")
M.Key(harmBox, "UP")
check(Suggest.selected == 7 and highlighted() == 7, "and on to the last row")
M.Key(harmBox, "ENTER")
check(e2.harm == "Resurrection" and not open(), "Enter takes the row chosen with the arrows")

-- Mouse
M.Input(helpBox, "p")
check(offered() == "Penance, Portal: Stormwind", "helpful box: spells for friends first")
M.Click(Suggest.list.__rows[2])
check(e2.help == "Portal: Stormwind" and not open() and not helpBox:HasFocus() and helpBox:GetText() == "Portal: Stormwind", "a click takes the spell")

-- The arrow button: the whole book
M.Click(Options.harmRow.browse)
check(open() and harmBox:HasFocus() and Suggest.selected == nil, "arrow button opens the list and gives the box the keyboard")
check(offered() == "Mind Blast, Penance, Smite, Лунный огонь, Flash Heal, Lesser Heal, Portal: Stormwind, Resurrection, Shadowform, Омоложение", "whole book in the list")
M.Input(harmBox, "лун")
check(offered() == "Лунный огонь" and Suggest.selected == 1, "typing narrows the open list down")
M.Click(Options.harmRow.browse)
check(not open() and e2.harm == "Resurrection", "arrow button again closes the list")
M.Key(harmBox, "ESCAPE")
check(e2.harm == "Resurrection" and harmBox:GetText() == "Resurrection", "Escape puts the spell back in the box")
harmBox:SetFocus()
M.Key(harmBox, "UP")
check(not open(), "Up does not open the list")
M.Key(harmBox, "DOWN")
check(open() and #Suggest.items == 10 and Suggest.selected == nil, "Down opens the whole book")
M.Key(harmBox, "DOWN")
M.Key(harmBox, "ENTER")
check(e2.harm == "Mind Blast" and not open(), "Down and Enter take the first spell of the book")

-- Ways out that change nothing
M.Input(helpBox, "fl")
M.Key(helpBox, "ESCAPE")
check(not open() and not helpBox:HasFocus() and e2.help == "Portal: Stormwind" and helpBox:GetText() == "Portal: Stormwind", "Escape closes the list and keeps the spell")
M.Input(helpBox, "fl")
Suggest.frame.__mouseOver = true
M.FireEvent("GLOBAL_MOUSE_DOWN", "LeftButton")
check(open(), "a click on the list does not close it")
Suggest.frame.__mouseOver = nil
M.FireEvent("GLOBAL_MOUSE_DOWN", "LeftButton")
check(not open() and helpBox:HasFocus(), "a click anywhere else does")
M.Key(helpBox, "ENTER")
check(e2.help == "fl", "with the list closed Enter keeps the text")
M.Input(helpBox, "fl")
harmBox:SetFocus()
check(not open() and not Suggest:IsOpen(Options.harmRow), "the list goes away with the keyboard")
harmBox:ClearFocus()

-- Not in the book
M.Input(helpBox, "Healthstone")
check(not open(), "no list for a name the book does not have")
M.Key(helpBox, "ENTER")
check(e2.help == "Healthstone", "such a name is kept: items work too")
M.Input(helpBox, "")
check(open() and #Suggest.items == 10 and Suggest.selected == nil, "emptied box: the whole book")
M.Key(helpBox, "ENTER")
check(e2.help == "" and not open(), "Enter in an empty box clears the spell")

if HAS_RANKS then
	M.Input(helpBox, "lesser heal")
	check(offered() == "Lesser Heal, Lesser Heal(Rank 1)" and Suggest.list.__rows[2].text:GetText():find("Rank 1", 1, true), "lower ranks listed under their spell")
	M.Key(helpBox, "DOWN")
	M.Key(helpBox, "ENTER")
	check(e2.help == "Lesser Heal(Rank 1)" and M.Macro(e2.name).body:find("]Lesser Heal(Rank 1);", 1, true), "a lower rank goes into the macro with its rank")
	M.Click(Options.helpRow.icon, "RightButton")
end

-- A hand-written macro has no spell boxes to fill
Options.customCheck:SetChecked(true)
M.Click(Options.customCheck)
check(not Options.helpRow.browse:IsEnabled() and not Options.harmRow.browse:IsEnabled(), "no list for a hand-written macro")
Options.customCheck:SetChecked(false)
M.Click(Options.customCheck)
check(Options.helpRow.browse:IsEnabled() and e2.help == "" and e2.harm == "Mind Blast" and M.Macro("Mind Blast"), "back to the generated macro")

-- No room
for i = #M.macros.char + 1, 18 do M.macros.char[i] = { name = "Filler" .. i, icon = 1, body = "" } end
M.Click(Options.addButton)
local e3 = Options.selected
M.Type(Options.helpRow.box, "Flash Heal")
check(Macros:Status(e3) == "full" and not e3.created, "full macro list reported")

-- List rows
check(#Options.list.__rows == 3, "list shows macros")
M.Click(Options.list.__rows[1])
check(Options.selected == e1, "row click selects")

-- Delete
M.Click(Options.deleteButton)
check(M.lastPopup and M.lastPopup.which == "DMOUSEOVERCASTS_CONFIRM", "delete asks first")
M.inCombat = true
M.lastPopup.data()
check(#Profile:GetEntries() == 3 and M.Macro("Lesser Heal"), "no delete in combat")
M.inCombat = false
M.lastPopup.data()
check(#Profile:GetEntries() == 2 and not M.Macro("Lesser Heal") and Options.selected == e2, "entry and game macro deleted")
check(M.Macro("Flash Heal").body == "/cast Flash Heal" and M.Macro("Mount"), "the player's macros survived")

-- Slash commands
ok, err = pcall(SlashCmdList.DMOUSEOVERCASTS, "list")
check(ok, "/dmo list: " .. tostring(err))
ok, err = pcall(SlashCmdList.DMOUSEOVERCASTS, "help")
check(ok, "/dmo help: " .. tostring(err))

print(string.format("RESULT %s passed=%d failed=%d", SCENARIO, passed, failed))
