-- SavedVariables. The list of macros is kept per character:
-- dMouseOverCastsDB = { version, chars = { ["Name-Realm"] = { macros = { entry, ... } } } }

local _, ns = ...

local Profile = {}
ns.Profile = Profile

local DB_VERSION = 4
local MAX_ENTRIES = 60

Profile.FALLBACKS = { "target", "none" }
Profile.SCOPES = { "char", "general" }

local function NewEntry()
	return {
		name = "", -- name of the game macro
		customName = "", -- name typed by the user; empty: named after the spell
		scope = "char", -- "char": character macros, "general": macros of all characters
		created = false, -- the game macro was created by the addon
		help = "", -- cast on friends
		harm = "", -- cast on enemies
		fallback = "target", -- nothing under the mouse: "target" or "none"
		selfCast = true, -- helpful spell on yourself as the last resort
		skipDead = true, -- off for resurrection spells
		custom = false, -- macro edited by hand
		macro = "",
	}
end
Profile.NewEntry = NewEntry

local function Sanitize(entry)
	if type(entry) ~= "table" then
		return nil
	end
	local clean = NewEntry()
	for key, default in pairs(clean) do
		if type(entry[key]) == type(default) then
			clean[key] = entry[key]
		end
	end
	if clean.fallback ~= "target" and clean.fallback ~= "none" then
		clean.fallback = "target"
	end
	if clean.scope ~= "char" and clean.scope ~= "general" then
		clean.scope = "char"
	end
	if clean.name == "" then
		clean.created = false
	end
	-- Not a setting: the game macro was written by an older data version and has to be written
	-- again. Macros:Sync clears it when it writes the macro.
	clean.rewrite = entry.rewrite == true or nil
	return clean
end

local function CharacterKey()
	local name, realm = UnitFullName("player")
	realm = (realm and realm ~= "") and realm or GetRealmName()
	return (name or "?") .. "-" .. (realm or "?")
end

-- Version 1 bound keys per specialization; its binds become macros of the character.
local function MigrateV1(char)
	local entries, seen = {}, {}
	local indexes = {}
	for index in pairs(char.specs) do
		indexes[#indexes + 1] = index
	end
	table.sort(indexes, function(a, b)
		return tostring(a) < tostring(b)
	end)
	for _, index in ipairs(indexes) do
		local spec = char.specs[index]
		for _, bind in ipairs(type(spec) == "table" and type(spec.binds) == "table" and spec.binds or {}) do
			local entry = Sanitize(bind)
			if entry then
				local signature = table.concat({ entry.help, entry.harm, tostring(entry.custom), entry.macro }, "\1")
				if not seen[signature] then
					seen[signature] = true
					entry.name, entry.created = "", false
					entries[#entries + 1] = entry
				end
			end
		end
	end
	return { macros = entries }
end

function Profile:Init()
	local db = dMouseOverCastsDB
	if type(db) ~= "table" or type(db.chars) ~= "table" then
		db = { chars = {} }
	end
	-- Version 2 pinned the icon of the macros it edited and version 3 wrote a longer macro text:
	-- see Macros:RewriteOld.
	local old = db.version == 2 or db.version == 3
	for charKey, char in pairs(db.chars) do
		if type(char) ~= "table" then
			db.chars[charKey] = nil
		else
			if type(char.macros) ~= "table" and type(char.specs) == "table" then
				char = MigrateV1(char)
			end
			local entries = {}
			for _, entry in ipairs(type(char.macros) == "table" and char.macros or {}) do
				entry = Sanitize(entry)
				if entry then
					if old and entry.created then
						entry.rewrite = true
					end
					entries[#entries + 1] = entry
				end
			end
			db.chars[charKey] = { macros = entries }
		end
	end
	db.version = DB_VERSION
	db.enabled = nil
	dMouseOverCastsDB = db
	ns.db = db
	self.charKey = CharacterKey()
	db.chars[self.charKey] = db.chars[self.charKey] or { macros = {} }
	self.entries = db.chars[self.charKey].macros
end

function Profile:GetEntries()
	return self.entries
end

-- Any change to an entry goes through here: writes its game macro and refreshes the settings page.
function Profile:Changed(entry)
	if entry then
		ns.Macros:Sync(entry)
	end
	ns.Options:Refresh()
end

function Profile:AddEntry()
	if #self.entries >= MAX_ENTRIES then
		return nil
	end
	local entry = NewEntry()
	self.entries[#self.entries + 1] = entry
	self:Changed()
	return entry
end

function Profile:RemoveEntry(entry)
	for index, existing in ipairs(self.entries) do
		if existing == entry then
			table.remove(self.entries, index)
			break
		end
	end
	self:Changed()
end
