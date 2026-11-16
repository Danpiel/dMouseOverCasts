-- The player's spellbook as a list for the spell boxes of the settings page: every spell that can
-- be cast, once, under the text /cast takes. On WoW Forever the book holds every learned rank: the
-- name alone casts the highest one, a lower rank is cast as "Name(Rank 2)".

local _, ns = ...

local Spellbook = {}
ns.Spellbook = Spellbook

local function Flag(check, spellID)
	return (check and spellID and check(spellID)) and true or false
end

-- Known spells of a flyout: a spellbook button that opens a row of spells, like the mage portals.
local function FlyoutSpells(flyoutID, add)
	if C_Flyout and C_Flyout.GetFlyoutInfo and C_Flyout.GetFlyoutSlotInfo then
		local info = C_Flyout.GetFlyoutInfo(flyoutID)
		for index = 1, info and info.numSlots or 0 do
			local slot = C_Flyout.GetFlyoutSlotInfo(flyoutID, index)
			if slot and slot.isKnown then
				add(slot.spellID, slot.name)
			end
		end
	elseif GetFlyoutInfo and GetFlyoutSlotInfo then
		local _, _, numSlots = GetFlyoutInfo(flyoutID)
		for index = 1, numSlots or 0 do
			local spellID, _, isKnown, name = GetFlyoutSlotInfo(flyoutID, index)
			if isKnown then
				add(spellID, name)
			end
		end
	end
end

-- Reads the spellbook. Each spell is a table:
--   text     what /cast takes: the name, or "Name(Rank 2)" for a lower rank
--   name     the name alone
--   rank     the rank text of a lower rank; nil for the spell itself
--   number   the number in that text
--   icon     its icon
--   help     can be cast on friends
--   harm     can be cast on enemies
--   key, nameKey   text and name folded for searching
function Spellbook.Read()
	local spells, seen = {}, {}
	local book = C_SpellBook
	if not (book and book.GetNumSpellBookSkillLines and book.GetSpellBookSkillLineInfo and book.GetSpellBookItemInfo
		and Enum and Enum.SpellBookItemType and Enum.SpellBookSpellBank) then
		return spells
	end
	local bank = Enum.SpellBookSpellBank.Player
	local isHelpful, isHarmful = C_Spell and C_Spell.IsSpellHelpful, C_Spell and C_Spell.IsSpellHarmful

	local function add(spellID, name, icon, rank)
		if not name or name == "" then
			return
		end
		local text = rank and (name .. "(" .. rank .. ")") or name
		if seen[text] then
			return -- the same spell on two tabs of the book
		end
		seen[text] = true
		if not icon and spellID then
			icon = select(2, ns.GetSpellNameAndIcon(spellID))
		end
		spells[#spells + 1] = {
			text = text,
			name = name,
			rank = rank,
			number = rank and tonumber(rank:match("%d+")) or nil,
			icon = icon,
			help = Flag(isHelpful, spellID),
			harm = Flag(isHarmful, spellID),
			key = ns.Fold(text),
			nameKey = ns.Fold(name),
		}
	end

	for line = 1, book.GetNumSpellBookSkillLines() or 0 do
		local info = book.GetSpellBookSkillLineInfo(line)
		-- offSpecID marks the tabs of the other specializations: listed, but not castable.
		if info and not info.shouldHide and not info.offSpecID then
			for slot = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
				local item = book.GetSpellBookItemInfo(slot, bank)
				if item and not item.isPassive and not item.isOffSpec then
					if item.itemType == Enum.SpellBookItemType.Spell then
						if not (book.IsSpellBookItemLowRank and book.IsSpellBookItemLowRank(slot, bank)) then
							add(item.spellID or item.actionID, item.name, item.iconID)
						elseif item.subName and item.subName ~= "" then
							-- Without its rank text (not loaded yet) a lower rank cannot be told apart.
							add(item.actionID, item.name, item.iconID, item.subName)
						end
					elseif item.itemType == Enum.SpellBookItemType.Flyout then
						FlyoutSpells(item.actionID, add)
					end
				end
			end
		end
	end
	return spells
end

-- The spells to offer for the text typed in a spell box, best first: the ones that suit the box
-- (kind is "help" or "harm"), then names that start with the text, then by name. A lower rank is
-- offered only once the text holds the whole name of its spell. Without text: the whole book.
-- Returns a list of { spell =, fit = suits the box, first = its name starts with the text }.
function Spellbook.Search(spells, query, kind)
	query = ns.Fold(strtrim(query or ""))
	local items = {}
	for _, spell in ipairs(spells) do
		local position
		if spell.rank then
			if #query >= #spell.nameKey and spell.key:sub(1, #query) == query then
				position = 1
			end
		elseif query == "" then
			position = 1
		else
			position = spell.key:find(query, 1, true)
		end
		if position then
			items[#items + 1] = {
				spell = spell,
				fit = spell[kind] == true,
				first = position == 1,
				exact = spell.key == query,
			}
		end
	end
	table.sort(items, function(a, b)
		if a.exact ~= b.exact then
			return a.exact -- the spell typed in full is never pushed down by a better fitting one
		end
		if a.fit ~= b.fit then
			return a.fit
		end
		if a.first ~= b.first then
			return a.first
		end
		if a.spell.nameKey ~= b.spell.nameKey then
			return a.spell.nameKey < b.spell.nameKey
		end
		-- The spell itself, then its lower ranks from the highest down.
		return (a.spell.number or math.huge) > (b.spell.number or math.huge)
	end)
	return items
end
