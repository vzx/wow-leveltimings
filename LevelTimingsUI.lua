
local LevelTimingsUI = {
	selectedGuid = UnitGUID("player"),
	compareGuid = "",
	sortedRows = {}
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

	if not LevelTimingsDB[guid] then
		-- Should never happen but eh you never know
		return
	end

	local item = LevelTimingsDB[guid]
	local name = item.name
	if item.class and RAID_CLASS_COLORS[item.class] then
		name = RAID_CLASS_COLORS[item.class]:WrapTextInColorCode(name)
	end

	local realm = item.realm
	if item.faction and PLAYER_FACTION_GROUP[item.faction] then
		realm = GetFactionColor(item.faction):WrapTextInColorCode(realm)
	end

	StaticPopupDialogs["LEVELTIMINGS_DELETE_CONFIRMATION"].text = "Are you sure you want to permanently delete all level timings for:\n\n"
		.. name .. " (" .. realm .. ")" .. "\n\nWARNING: this is irreversible!"
	local popup = StaticPopup_Show("LEVELTIMINGS_DELETE_CONFIRMATION")
	if popup then
		popup.data = guid
	end
end

function LevelTimingsUI:DeleteFromDB(guid)
	LevelTimingsDB[guid] = nil
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
	LevelTimingsUI_DeleteCharacterButton:SetEnabled(guid ~= UnitGUID("player"))
end

function LevelTimingsUI:SetSelectedCompareInDropDown()
	UIDropDownMenu_SetSelectedValue(LevelTimingsUI_CompareDropDown, LevelTimingsUI.compareGuid)
end

function LevelTimingsUI:RefreshList()
	local guid = LevelTimingsUI.selectedGuid
	local entry = LevelTimingsDB[guid]
	local compareEntry = nil
	local titleText = "Level Timings for " .. LevelTimingsUI:ColoredName(entry)

	if LevelTimingsUI.compareGuid ~= "" then
		compareEntry = LevelTimingsDB[LevelTimingsUI.compareGuid]
		titleText = titleText .. " vs " .. LevelTimingsUI:ColoredName(compareEntry)
		LevelTimingsUI_ListFrameColumnHeaderZoneOrCompare:SetText(RAID_CLASS_COLORS[compareEntry.class]:WrapTextInColorCode(compareEntry.name))
	else
		LevelTimingsUI_ListFrameColumnHeaderZoneOrCompare:SetText(ZONE)
	end

	LevelTimingsUI_FrameTitleText:SetText(titleText)
	LevelTimingsUI.sortedRows = LevelTimingsUI:BuildSortedLevelRows(entry, compareEntry)
	HybridScrollFrame_SetOffset(LevelTimingsUI_ScrollFrame, 0)
	LevelTimingsUI_ScrollFrame.scrollBar:SetValue(0)
	LevelTimingsUI:UpdateList()
end

function LevelTimingsUI:BuildSortedLevelRows(entry, compareEntry)
	local timings = entry.timings
	local compareTimings = {}
	if compareEntry then
		compareTimings = compareEntry.timings
	end
	local levels = {}
	local n = 1
	for level in pairs(timings) do
		levels[n] = level
		n = n + 1
	end
	table.sort(levels)

	local levelRows = {}
	for n, level in ipairs(levels) do
		levelRows[n] = {
			level = level,
			timings = timings[level],
			compareTimings = compareTimings[level]
		}
	end
	return levelRows
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
	local levelRows = LevelTimingsUI.sortedRows
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
			local compareTimings = row.compareTimings

			button.Level:SetText(row.level)
			button.Timestamp:SetText(date("%Y-%m-%d %H:%M:%S", timings.timestamp))
			button.Played:SetText(LevelTimingsUI:FormatPlayed(timings.played))

			if LevelTimingsUI.compareGuid ~= "" then
				local compareText = "-"
				if compareTimings then
					local delta = compareTimings.played - timings.played
					compareText = LevelTimingsUI:FormatPlayed(compareTimings.played) .. " ("
					if delta >= 0 then
						compareText = compareText .. "|cFFFF0000+"
					else
						compareText = compareText .. "|cFF00FF00-"
					end
					compareText = compareText .. LevelTimingsUI:FormatPlayed(math.abs(delta)) .. "|r)"
				end
				button.ZoneOrCompare:SetText(compareText)
				button.ZoneOrCompare:SetJustifyH("RIGHT")
				button.ZoneOrCompare:SetTextColor(1, 1, 1)
			else
				local zone, subzone = timings.zone, timings.subzone
				local zoneText = ""
				if zone then
					zoneText = zone
					if subzone and subzone ~= "" then
						zoneText = zoneText .. " (" .. subzone .. ")"
					end
					button.ZoneOrCompare:SetTextColor(1, 1, 1)
				else
					zoneText = "(Unknown)"
					button.ZoneOrCompare:SetTextColor(0.5, 0.5, 0.5)
				end

				button.ZoneOrCompare:SetText(zoneText)
				button.ZoneOrCompare:SetJustifyH("LEFT")
			end

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
	for guid, entry in pairs(LevelTimingsDB) do
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
