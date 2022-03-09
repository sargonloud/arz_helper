script_name("FastGun")
script_author("Cosmo")
local se = require "samp.events"

-- // Максимальное время ожидания после отправки действия на сервер (Клик по текстдраву или его ожидание)
-- // Не рекомендуется ставить маленькое значение, на фуловом онлайне будет работать через раз
local TIMEOUT = 1.00

-- // ID кнопок страниц инвентаря
local page = { 
	[1] = 2107,
	[2] = 2108,
	[3] = 2109,
	["cur"] = 1
}

-- // Команды и нужная информация о текстдраве оружия (модель, угол поворота и название)
local Weapon = {
	["fgc"] 	= { model = 346, x = 0, y = 20, z = 189, name = "Colts" },
	["de"] 	= { model = 348, x = 0, y = 32, z = 189, name = "Desert Eagle" },
	["sh"] 	= { model = 349, x = 0, y = 23, z = 140, name = "ShotGun" },
	["uzi"] 	= { model = 352, x = 0, y = 360, z = 188, name = "Micro Uzi" },
	["mp5"] 	= { model = 353, x = 0, y = 17, z = 181, name = "MP5" },
	["ak"] 	= { model = 355, x = 0, y = 27, z = 134, name = "AK-47" },
	["m4"] 	= { model = 356, x = 0, y = 27, z = 134, name = "M4" },
	["rl"] 	= { model = 357, x = 0, y = 13, z = 120, name = "Rifle" }
}

for name, _ in pairs(Weapon) do
	setmetatable(Weapon[name], {
		__call = function(self, count)
			return {
				step = 0,
				model = self.model,
				rot = { x = self.x, y = self.y, z = self.z },
				count = count,
				clock = os.clock()
			}
		end
	})
end

function getHelpText()
	result = "{EEEEEE}Название\t{EEEEEE}Команда\n"
	for cmd, info in pairs(Weapon) do
		result = result .. string.format("{AAAAAA}%s:\t{EEEEEE}/%s {FFAA80}[Кол-во]\n", info.name, cmd)
	end
	return result
end

function close_inventory()
	for i = 0, 1 do
		if i <= info.step then sampSendClickTextdraw(0xFFFF) end
	end
	info = nil
end

function se.onSendCommand(input)
	local cmd, args = string.match(input, "^/([^%s]+)"), {}
	local cmd_len = string.len("/" .. cmd)
	local arg_text = string.sub(input, cmd_len + 2, string.len(input))
	for arg in string.gmatch(arg_text, "[^%s]+") do args[#args + 1] = arg end

	if cmd == "fg" then
		local text = getHelpText()
		sampShowDialog(0, "{FFAA80}Команды для выдачи оружия", text, "Понял", "", 5)
		return false
	end

	if Weapon[cmd] ~= nil then
		if info ~= nil then
			sampAddChatMessage("» Подождите немного!", 0xAA3030)
			return false
		end

		local count = tonumber(args[1]) or 50
		if count > 500 then
			sampAddChatMessage("» Нельзя доставать более 500 ед. за раз!", 0xAA3030)
			return false
		elseif count < 1 then
			sampAddChatMessage("» Введено некорректное количество!", 0xAA3030)
			return false
		end

		page.cur = 1
		lua_thread.create(function()
			while true do wait(0)
				if info ~= nil then
					printStringNow("~w~Wait a moment...", 50)
					if os.clock() - info.clock >= TIMEOUT then
						if info.step == 0 and page.cur < 3 then
							page.cur = page.cur + 1
							info.clock = os.clock()
							sampSendClickTextdraw(page[page.cur])
						elseif page.cur > 1 then
							sampAddChatMessage("» В вашем инвентаре не найдено это оружие!", 0xAA3030)
							close_inventory()
						else
							sampAddChatMessage("» Вышло время ожидания, попробуйте ещё раз!", 0xAA3030)
							close_inventory()
						end
					end
				end
			end
		end)

		info = Weapon[cmd](count)
		return { "/invent" }
	end
end

function se.onShowTextDraw(id, data)
	if info ~= nil then
		if info.step == 0 then
			if data.modelId == info.model then
				local rot = data.rotation
				if rot.x == info.rot.x and rot.y == info.rot.y and rot.z == info.rot.z then
					sampSendClickTextdraw(id)
					info.clock = os.clock()
					info.step = 1
				end
			end
		elseif info.step == 1 then
			if id == 2302 then
				sampSendClickTextdraw(id)
				sampSendClickTextdraw(0xFFFF)
				info.clock = os.clock()
				info.step = 3
			end
		end
		return false
	end
end

function onReceiveRpc(id, bs)
	if info ~= nil and id == 83 then -- // SelectTextDraw RPC
		return false -- // Не даём курсору появится
	end
end

function se.onShowDialog(id, style, title, but_1, but_2, text)
	if info ~= nil then
		if info.step == 3 and string.find(text, "Введите количество") then
			sampSendDialogResponse(id, 1, nil, info.count)
			info = nil
			return false
		end
	end
end

function se.onServerMessage(color, message)
	if info ~= nil and string.find(message, "У вас нет доступных ячеек на этой странице!") then
		sampAddChatMessage("» В вашем инвентаре не найдено это оружие!", 0xAA3030)
		close_inventory()
		return false
	end
end