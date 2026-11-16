-- Localization. Keys are the English texts; missing translations fall back to the key.

local _, ns = ...

local L = setmetatable({}, {
	__index = function(_, key)
		return key
	end,
})
ns.L = L

L.HELP = "Pick a helpful spell for friends and a harmful one for enemies: the addon writes a regular macro. "
	.. "Drag its icon to an action bar. The unit under the mouse is the target, unit frames included."

if GetLocale() ~= "ruRU" then
	return
end

local R = {
	HELP = "Выберите помогающее заклинание для союзников и атакующее для врагов — аддон создаст обычный макрос. "
		.. "Перетащите его иконку на панель команд. Цель — тот, кто под мышкой, в том числе на рамках юнитов.",
	["Changes made in combat are written after combat."] = "Изменения, сделанные в бою, запишутся после боя.",
	["Click: settings"] = "Клик: настройки",
	["Commands:"] = "Команды:",
	["Delete %s from the list?"] = "Удалить %s из списка?",
	["Delete the macro %s? It disappears from your macros and action bars."] = "Удалить макрос %s? Он пропадёт из списка макросов и с панелей.",
	["Delete"] = "Удалить",
	["Drag a spell from the spellbook here. Right click: clear."] = "Перетащите сюда заклинание из книги. Правый клик — очистить.",
	["Drag this icon to an action bar. The macro is also in the game's macro window (/macro)."] =
		"Перетащите эту иконку на панель команд. Макрос также есть в окне макросов игры (/macro).",
	["Edit the macro by hand"] = "Править макрос вручную",
	["Harmful spell: enemy under the mouse"] = "Атакующее заклинание — враг под мышкой",
	["Helpful spell: friend under the mouse"] = "Помогающее заклинание — союзник под мышкой",
	["Macro name"] = "Название макроса",
	["Macros cannot be changed in combat."] = "В бою макросы менять нельзя.",
	["New macro"] = "Новый макрос",
	["No free macro slot there."] = "Там нет свободного места для макроса.",
	["No macros yet. Open the settings with /dmo."] = "Макросов пока нет. Настройки: /dmo.",
	["No macros yet: press \"New macro\"."] = "Макросов пока нет: нажмите «Новый макрос».",
	["Nothing suitable under the mouse"] = "Под мышкой никого подходящего",
	["Otherwise the helpful spell on yourself"] = "Иначе помогающее — на себя",
	["Pick a spell from your spellbook. Or just type in the box: the list shows the matching spells."] =
		"Выбрать заклинание из книги. Можно и просто печатать в поле: список покажет подходящие заклинания.",
	["Pick up the macro"] = "Взять макрос",
	["Stored in"] = "Где хранить",
	["There is already a macro named %s."] = "Макрос с названием %s уже есть.",
	["Too long: pick \"do nothing\" above, then each spell is named once. Or shorten the macro by hand."] =
		"Слишком длинный: выберите выше «ничего не делать», тогда каждое заклинание пишется один раз. Или сократите макрос вручную.",
	["Skip dead units (turn off for resurrection)"] = "Пропускать мёртвых (выключите для воскрешения)",
	["Unknown spell: %s"] = "Неизвестное заклинание: %s",
	["cast on the target"] = "колдовать на текущую цель",
	["character macros"] = "макросы персонажа",
	["deleted from your macros"] = "удалён из списка макросов",
	["do nothing"] = "ничего не делать",
	["general macros"] = "общие макросы",
	["in your macros: drag it to a bar"] = "готов — перетащите на панель",
	["macro is too long"] = "слишком длинный макрос",
	["no free macro slot"] = "нет места для макроса",
	["no spells"] = "нет заклинаний",
	["not created yet"] = "ещё не создан",
	["not in your spellbook"] = "нет в книге заклинаний",
	["open settings"] = "открыть настройки",
	["own macro"] = "свой макрос",
	["show the macros in chat"] = "показать макросы в чате",
}

for key, value in pairs(R) do
	L[key] = value
end
