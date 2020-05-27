
local LevelTimingsUI = {rows = {}}

SLASH_LevelTimingsUI1 = "/ltui"
SlashCmdList['LevelTimingsUI'] = function(msg)
	LevelTimingsUI:Show()
end

function LevelTimingsUI:Show()
	ShowUIPanel(LevelTimingsUI_Frame)
end

function LevelTimingsUI:PopulateLevelRows()
	LevelTimingsUI.rows = LevelTimingsUI:DetermineLevelRows()
end

function LevelTimingsUI:DetermineLevelRows()
	local guid = UnitGUID('player')

	if not LevelTimingsDB or not LevelTimingsDB[guid] or not LevelTimingsDB[guid].timings then
		return {}
	end

	local timings = LevelTimingsDB[guid].timings
	local levels = {}
	local n = 1
	for level, _ in pairs(timings) do
		levels[n] = level
		n = n + 1
	end
	table.sort(levels)

	local levelRows = {}
	for n, level in ipairs(levels) do
		local t = timings[level]
		levelRows[n] = {
			level = level,
			timings = t
		}
	end
	return levelRows
end

function LevelTimingsUI:FormatPlayed(played)
	local remaining = played
	local times = {}
	times[1] = {amount = math.floor(remaining / 86400), suffix = "d"}
	remaining = math.fmod(remaining, 86400)
	times[2] = {amount = math.floor(remaining / 3600), suffix = "h"}
	remaining = math.fmod(remaining, 3600)
	times[3] = {amount = math.floor(remaining / 60), suffix = "m"}
	times[4] = {amount = math.fmod(remaining, 60), suffix = "s"}
	
	local display = false
	local result = ""
	for _, v in ipairs(times) do
		if v.amount > 0 then
			display = true
		end

		if display then
			if result ~= "" then
				result = result .. " "
			end
			result = result .. v.amount .. v.suffix
		end
	end

	return result
end

function LevelTimingsUI:UpdateList()
	local levelRows = LevelTimingsUI.rows
	local scrollFrame = LevelTimingsUI_ScrollFrame
	local offset = HybridScrollFrame_GetOffset(scrollFrame)
	local buttons = scrollFrame.buttons
	local buttonCount = #buttons
	local rowCount = #levelRows
	local usedHeight = 0
	local buttonHeight = 16

	for i = 1, buttonCount do
		local button = buttons[i]
		local index = offset + i
		if index <= rowCount then
			local row = levelRows[index]
			local timings = row.timings

			button.Level:SetText(row.level)
			button.Timestamp:SetText(date("%Y-%m-%d %H:%M:%S", timings.timestamp))
			button.Played:SetText(LevelTimingsUI:FormatPlayed(timings.played))

			local zone, subzone = timings.zone, timings.subzone
			local zoneText = ""
			if zone then
				zoneText = zone
				if subzone and subzone ~= "" then
					zoneText = zoneText .. " (" .. subzone .. ")"
				end
				button.Zone:SetTextColor(1, 1, 1)
			else
				zoneText = "(Unknown)"
				button.Zone:SetTextColor(0.5, 0.5, 0.5)
			end

			button.Zone:SetText(zoneText)

			button.index = index
			button:Show()
			usedHeight = usedHeight + buttonHeight
		else
			button.index = nil
			button:Hide()
		end
	end

	HybridScrollFrame_Update(scrollFrame, rowCount * buttonHeight, usedHeight)
end

function LevelTimingsUI_OnLoad(self)
	self:RegisterForDrag('LeftButton')
	LevelTimingsUI_FrameTitleText:SetText("Level Timings")
	LevelTimingsUI_ScrollFrame.update = LevelTimingsUI.UpdateList
	HybridScrollFrame_CreateButtons(LevelTimingsUI_ScrollFrame, 'LevelTimingsUI_ButtonTemplate')

	if true then
		-- TODO: Debug stuff
		self:RegisterEvent('ADDON_LOADED')
		self:SetScript('OnEvent', function(self, msg, addonName)
			if addonName ~= 'LevelTimings' then
				return
			end
			self:UnregisterEvent('ADDON_LOADED')
			print('LevelTimingsUI_OnLoad OnEvent', self, msg, addonName)
			LevelTimingsUI:Show()
		end)
	else
		-- This will make the frame close when pressing the Escape button
		tinsert(UISpecialFrames, self:GetName())
	end
end

function LevelTimingsUI_OnShow(self)
	LevelTimingsUI:PopulateLevelRows()
	LevelTimingsUI:UpdateList()
end
