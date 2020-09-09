-- Copyright © 2020 vzx8. All rights reserved.
-- Licensed under GPLv3 (see license.txt).

local LevelTimingsUI = {
	selectedGuid = UnitGUID("player"),
	compareGuid = "",
	displayRows = {},
	fromLevel = 0
}

SLASH_LevelTimings1 = "/leveltimings"
SlashCmdList["LevelTimings"] = function(msg)
	LevelTimingsUI:Show()
end

StaticPopupDialogs["LEVELTIMINGS_DELETE_CONFIRMATION"] = {
	text = "",
	button1 = "Yes",
	button2 = "No",
	OnAccept = function(self, guid)
		LevelTimingsUI:DeleteFromDB(guid)
	end,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3
}

function LevelTimingsUI:InitiateDelete()
	local myGuid = UnitGUID("player")
	local guid = self.selectedGuid

	if myGuid == guid then
		-- Prevent deletion of this/last character
		return
	end

	if not LevelTimingsDB["players"][guid] then
		-- Should never happen but eh you never know
		return
	end

	local item = LevelTimingsDB["players"][guid]
	local name = LevelTimingsUI:ColoredName(item)
	local realm = GetFactionColor(item.faction):WrapTextInColorCode(item.realm)

	StaticPopupDialogs["LEVELTIMINGS_DELETE_CONFIRMATION"].text = "Are you sure you want to permanently delete all level timings for:\n\n"
		.. name .. " (" .. realm .. ")" .. "\n\nWARNING: this is irreversible!"
	local popup = StaticPopup_Show("LEVELTIMINGS_DELETE_CONFIRMATION")
	if popup then
		popup.data = guid
	end
end

function LevelTimingsUI:DeleteFromDB(guid)
	LevelTimingsDB["players"][guid] = nil
	LevelTimingsUI:SelectCharacter(UnitGUID("player"))
	if guid == LevelTimingsUI.compareGuid then
		LevelTimingsUI:SelectCompare("")
	end
end

function LevelTimingsUI_ToggleShown()
	LevelTimingsUI_Frame:SetShown(not LevelTimingsUI_Frame:IsShown())
end

function LevelTimingsUI:Show()
	LevelTimingsUI_Frame:Show()
end

function LevelTimingsUI:SelectCharacter(guid)
	LevelTimingsUI.selectedGuid = guid
	LevelTimingsUI:SetSelectedCharacterInDropDown()
	LevelTimingsUI:RefreshList()
end

function LevelTimingsUI:SelectCompare(guid)
	LevelTimingsUI.compareGuid = guid
	LevelTimingsUI:SetSelectedCompareInDropDown()
	LevelTimingsUI:RefreshList()
end

function LevelTimingsUI:SetSelectedCharacterInDropDown()
	UIDropDownMenu_SetSelectedValue(LevelTimingsUI_CharactersDropDown, LevelTimingsUI.selectedGuid)
	LevelTimingsUI_DeleteCharacterButton:SetEnabled(LevelTimingsUI.selectedGuid ~= UnitGUID("player"))
end

function LevelTimingsUI:SetSelectedCompareInDropDown()
	UIDropDownMenu_SetSelectedValue(LevelTimingsUI_CompareDropDown, LevelTimingsUI.compareGuid)
end

function LevelTimingsUI_SetFromLevel(self, level)
	LevelTimingsUI_FromLevelText:SetText(level)
	LevelTimingsUI.fromLevel = level
	LevelTimingsUI:RefreshList()
end

function LevelTimingsUI_RefreshList()
	LevelTimingsUI:RefreshList()
end

function LevelTimingsUI:RefreshList()
	local guid = LevelTimingsUI.selectedGuid
	local entry = LevelTimingsDB["players"][guid]
	local compareEntry = nil
	local titleText = "Level Timings for " .. LevelTimingsUI:ColoredName(entry)

	if LevelTimingsUI.compareGuid ~= "" then
		compareEntry = LevelTimingsDB["players"][LevelTimingsUI.compareGuid]
		titleText = titleText .. " vs " .. LevelTimingsUI:ColoredName(compareEntry)
		LevelTimingsUI_ListFrameColumnHeaderPlayedTotal:SetText(LevelTimingsUI:ColoredName(entry))
		LevelTimingsUI_ListFrameColumnHeaderZoneOrCompare:SetText(LevelTimingsUI:ColoredName(compareEntry))
	else
		LevelTimingsUI_ListFrameColumnHeaderPlayedTotal:SetText("Total played")
		LevelTimingsUI_ListFrameColumnHeaderZoneOrCompare:SetText(ZONE)
	end

	LevelTimingsUI_FrameTitleText:SetText(titleText)
	local sortedRows = LevelTimingsUI:BuildSortedLevelRows(entry, compareEntry, LevelTimingsUI.fromLevel)
	LevelTimingsUI.displayRows = LevelTimingsUI:BuildDisplayRows(sortedRows)
	HybridScrollFrame_SetOffset(LevelTimingsUI_ScrollFrame, 0)
	LevelTimingsUI_ScrollFrame.scrollBar:SetValue(0)
	LevelTimingsUI:UpdateList()
end


function LevelTimingsUI:BuildSortedLevelRows(entry, compareEntry, fromLevel)
	local timings = entry.timings
	local compareTimings = {}
	if compareEntry then
		compareTimings = compareEntry.timings
	end

	local sortedTimings = {}
	local n = 1
	for _, v in ipairs(timings) do
		if v.level >= fromLevel then
			sortedTimings[n] = v
			n = n + 1
		end
	end

	table.sort(sortedTimings, function(l, r) 
		return l.played < r.played
	end)

	local levelRows = {}
	for i, entry in ipairs(sortedTimings) do
		local level = entry.level
		local compareEntry = nil
		for _, ce in ipairs(compareTimings) do
			if ce.level == level and LevelTimingsUI:IsSimilarGameVersion(entry.tocVersion, ce.tocVersion) then
				compareEntry = ce
				break
			end
		end

		levelRows[i] = {
			level = level,
			timings = entry,
			compareTimings = compareEntry
		}
	end
	return levelRows
end

function LevelTimingsUI:IsSimilarGameVersion(v1, v2)
	-- If either entry is nil, assume they are in BfA (toc version 80300)
	v1 = v1 or 80300
	v2 = v2 or 80300

	-- Shadowlands is version 9 (toc version 9xxxx) and had a level squish
	-- Entries are similar if they are both either pre-Shadowlands or post-Shadowlands
	return (v1 < 90000) == (v2 < 90000)
end

function LevelTimingsUI:BuildDisplayRows(levelRows)
	local displayRows = {}
	local playedOffset = 0
	local compareOffset = 0
	for index in ipairs(levelRows) do
		local row = levelRows[index]
		local level = row.level
		local timings = row.timings
		local compareTimings = row.compareTimings

		if level == LevelTimingsUI.fromLevel then
			playedOffset = timings.played
			if compareTimings then
				compareOffset = compareTimings.played
			end
		end

		local played = timings.played - playedOffset
		local playedLevel = "|cFF808080?|r" -- grey
		if levelRows[index+1] ~= nil then
			local nextPlayed = levelRows[index+1].timings.played
			playedLevel = LevelTimingsUI:FormatPlayed(nextPlayed - timings.played)
		end

		local entry = {}
		displayRows[index] = entry

		entry.level = row.level
		entry.timestamp = date("%Y-%m-%d %H:%M:%S", timings.timestamp)
		entry.played = LevelTimingsUI:FormatPlayed(played)
		entry.playedLevel = playedLevel

		local zoneOrCompare = {justifyH = "LEFT"}
		entry.zoneOrCompare = zoneOrCompare

		if LevelTimingsUI.compareGuid ~= "" then
			local compareText = "-"
			if compareTimings then
				local comparePlayed = compareTimings.played - compareOffset
				local delta = comparePlayed - played
				compareText = LevelTimingsUI:FormatPlayed(comparePlayed) .. " ("
				if delta >= 0 then
					compareText = compareText .. "|cFFFF0000+" -- red
				else
					compareText = compareText .. "|cFF00FF00-" -- green
				end
				compareText = compareText .. LevelTimingsUI:FormatPlayed(math.abs(delta)) .. "|r)"
			end
			zoneOrCompare.text = compareText
			zoneOrCompare.justifyH = "RIGHT"
		else
			local zone, subzone = timings.zone, timings.subzone
			local zoneText = ""
			if zone then
				zoneText = zone
				if subzone and subzone ~= "" then
					zoneText = zoneText .. " (" .. subzone .. ")"
				end
			else
				-- grey
				zoneText = "|cFF808080" .. (timings.initial and "(Initial entry)" or "(Unknown)") .. "|r"
			end

			zoneOrCompare.text = zoneText
		end
	end

	return displayRows
end

function LevelTimingsUI:FormatPlayed(played)
	if played == 0 then
		return "0s"
	end
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
	local displayRows = LevelTimingsUI.displayRows
	local scrollFrame = LevelTimingsUI_ScrollFrame
	local offset = HybridScrollFrame_GetOffset(scrollFrame)
	local buttons = scrollFrame.buttons
	local buttonCount = #buttons
	local rowCount = #displayRows
	local usedHeight = 0
	local buttonHeight = 16

	for i = 1, buttonCount do
		local button = buttons[i]
		local index = offset + i
		if index <= rowCount then
			local row = displayRows[index]

			button.Level:SetText(row.level)
			button.Timestamp:SetText(row.timestamp)
			button.PlayedTotal:SetText(row.played)
			button.PlayedLevel:SetText(row.playedLevel)
			button.ZoneOrCompare:SetText(row.zoneOrCompare.text)
			button.ZoneOrCompare:SetJustifyH(row.zoneOrCompare.justifyH)
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

function LevelTimingsUI:CharactersDropDown_Initialize()
	LevelTimingsUI:PopulateDropDown(function(self) LevelTimingsUI:SelectCharacter(self.value) end)
end

function LevelTimingsUI:CompareDropDown_Initialize()
	local onClickFunc = function(self) LevelTimingsUI:SelectCompare(self.value) end
	local info = UIDropDownMenu_CreateInfo()
	info.text = "-"
	info.value = ""
	info.func = onClickFunc
	info.checked = nil
	UIDropDownMenu_AddButton(info)

	LevelTimingsUI:PopulateDropDown(onClickFunc)
end

function LevelTimingsUI:PopulateDropDown(onItemClick)
	local sortArray = {}
	local n = 1
	for guid, entry in pairs(LevelTimingsDB["players"]) do
		sortArray[n] = {guid = guid, name = entry.name, realm = entry.realm, class = entry.class, faction = entry.faction}
		n = n + 1
	end

	table.sort(sortArray, function(l, r)
		if l.realm == r.realm then
			return l.name < r.name
		else
			return l.realm < r.realm
		end
	end)

	local info = UIDropDownMenu_CreateInfo()
	for _, item in ipairs(sortArray) do
		local name = LevelTimingsUI:ColoredName(item)
		local realm = GetFactionColor(item.faction):WrapTextInColorCode(item.realm)

		info.text = name .. " (" .. realm .. ")"
		info.value = item.guid
		info.func = onItemClick
		info.checked = nil
		UIDropDownMenu_AddButton(info)
	end
end

function LevelTimingsUI:ColoredName(item)
	return RAID_CLASS_COLORS[item.class]:WrapTextInColorCode(item.name)
end

function LevelTimingsUI_OnLoad(self)
	self:RegisterForDrag("LeftButton")
	SetPortraitToTexture(LevelTimingsUI_FrameIcon, "Interface\\Icons\\INV_7XP_Inscription_TalentTome01")
	LevelTimingsUI_FrameTitleText:SetText("Level Timings")
	LevelTimingsUI_ScrollFrame.update = LevelTimingsUI.UpdateList
	HybridScrollFrame_CreateButtons(LevelTimingsUI_ScrollFrame, "LevelTimingsUI_ButtonTemplate")

	if true then
		-- TODO: Debug stuff
		self:RegisterEvent("ADDON_LOADED")
		self:SetScript("OnEvent", function(self, msg, addonName)
			if addonName ~= "LevelTimings" then
				return
			end
			self:UnregisterEvent("ADDON_LOADED")
			LevelTimingsUI:Show()
		end)
	else
		-- This will make the frame close when pressing the Escape button
		tinsert(UISpecialFrames, self:GetName())
	end
end

function LevelTimingsUI_OnShow(self)
	LevelTimingsUI:RefreshList()
end

function LevelTimingsUI_CharactersDropDown_OnLoad(self)
	UIDropDownMenu_SetWidth(self, 240)
	UIDropDownMenu_JustifyText(self, "LEFT")
end

function LevelTimingsUI_CharactersDropDown_OnShow(self)
	UIDropDownMenu_Initialize(self, LevelTimingsUI.CharactersDropDown_Initialize)
	LevelTimingsUI:SetSelectedCharacterInDropDown()
end

function LevelTimingsUI_CompareDropDown_OnShow(self)
	UIDropDownMenu_Initialize(self, LevelTimingsUI.CompareDropDown_Initialize)
	LevelTimingsUI:SetSelectedCompareInDropDown()
end

function LevelTimingsUI_DeleteCharacterButton_Click(self)
	LevelTimingsUI:InitiateDelete()
end

function LevelTimingsUI_FromLevelSlider_OnLoad(self)
	self:SetObeyStepOnDrag(true)
	local name = self:GetName()
	_G[name .. "Low"]:Hide()
	_G[name .. "High"]:Hide()
	-- Registering it here prevents OnValueChanged from triggering when the default value is set
	self:SetScript("OnValueChanged", LevelTimingsUI_SetFromLevel)
end
