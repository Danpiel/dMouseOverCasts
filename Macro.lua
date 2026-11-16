-- Builds the macro text for an entry. Pure string work, no game state.
--
-- With both spells, all fallbacks on and dead units skipped:
--   #showtooltip
--   /cast [@mouseover,help,nodead]Heal;[@mouseover,harm,nodead][harm,nodead]Smite;Heal
-- The unit under the mouse always wins (unit frames count too). With nobody suitable there an
-- enemy target gets the harmful spell; otherwise the helpful spell is cast the way its own button
-- casts it: on a friendly target, else on yourself (the game's auto self-cast).
--
-- A macro holds 255 bytes and a Cyrillic name takes two per letter, so a name is written as few
-- times as the order of the checks allows: once, or twice for the helpful spell when the target
-- counts too. Conditions of one spell share a clause: [a][b]Spell casts it if either holds.
--
-- #showtooltip and the question mark icon the macro is saved with (Macros.ICON) make the action
-- button show the spell the macro would cast right now: the harmful one over an enemy just like
-- the helpful one over a friend.

local _, ns = ...

local Macro = {}
ns.Macro = Macro

-- A game macro holds 255 bytes; Cyrillic letters take two each.
Macro.MAX_LENGTH = 255

local function Spell(text)
	text = text and strtrim(text) or ""
	if text == "" then
		return nil
	end
	-- A line break or ';' would let a spell name inject its own macro clauses.
	return (text:gsub("[\r\n;]", " "))
end

function Macro.Build(entry)
	if entry.custom then
		local text = entry.macro and strtrim(entry.macro) or ""
		return text ~= "" and text or nil
	end

	local help, harm = Spell(entry.help), Spell(entry.harm)
	if not help and not harm then
		return nil
	end
	local alive = entry.skipDead ~= false and ",nodead" or ""
	local target = entry.fallback ~= "none"

	-- The harmful spell: the enemy under the mouse, then the enemy target. Without a unit the
	-- conditions check the current target.
	local attack = harm and ("[@mouseover,harm" .. alive .. "]" .. (target and ("[harm" .. alive .. "]") or "") .. harm)

	-- The helpful spell with no friend under the mouse.
	local rest
	if target and entry.selfCast then
		rest = "[]" -- a plain cast: the friendly target, else yourself
	elseif target then
		rest = "[help" .. alive .. "]"
	elseif entry.selfCast then
		rest = "[@player]"
	else
		rest = ""
	end
	local heal = help and ("[@mouseover,help" .. alive .. "]" .. rest .. help)

	local text
	if not (heal and attack) then
		text = heal or attack
	elseif target then
		-- The enemy target goes before the rest of the helpful spell, or a hostile target would
		-- get the helpful spell cast on yourself. That takes the name twice.
		text = "[@mouseover,help" .. alive .. "]" .. help .. ";" .. attack .. ";" .. (rest == "[]" and "" or rest) .. help
	elseif rest ~= "" then
		-- The unit under the mouse is never both friend and enemy, so the enemy can be checked
		-- first: the helpful spell keeps its conditions together and its name is written once.
		text = attack .. ";" .. heal
	else
		text = heal .. ";" .. attack
	end
	return "#showtooltip\n/cast " .. text
end

-- nil if the text fits in a game macro, otherwise the reason.
function Macro.Problem(text)
	if not text then
		return "empty"
	end
	if #text > Macro.MAX_LENGTH then
		return "toolong"
	end
end
