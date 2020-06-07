
local LevelTimingsUI = {
	selectedGuid = UnitGUID("player"),
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
	print(guid)
	print(myGuid)

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
end

function LevelTimingsUI_ToggleShown()
	LevelTimingsUI_Frame:SetShown(not LevelTimingsUI_Frame:IsShown())
end

function LevelTimingsUI:Show()
	LevelTimingsUI_Frame:Show()
end

function LevelTimingsUI:SelectCharacter(guid)
	LevelTimingsUI.selectedGuid = guid
	LevelTimingsUI:SetSelectedCharacterInDropDown(guid)
	LevelTimingsUI:RefreshList()
end

function LevelTimingsUI:SetSelectedCharacterInDropDown(guid)
	UIDropDownMenu_SetSelectedValue(LevelTimingsUI_CharactersDropDown, guid);
	LevelTimingsUI_DeleteCharacterButton:SetEnabled(guid ~= UnitGUID("player"))
end

function LevelTimingsUI_RefreshList()
	LevelTimingsUI:RefreshList()
end

function LevelTimingsUI:RefreshList()
	local guid = LevelTimingsUI.selectedGuid
	local entry = LevelTimingsDB[guid]
	LevelTimingsUI.sortedRows = LevelTimingsUI:BuildSortedLevelRows(entry)
	LevelTimingsUI_FrameTitleText:SetText("Level Timings for " .. entry.name)
	HybridScrollFrame_SetOffset(LevelTimingsUI_ScrollFrame, 0)
	LevelTimingsUI_ScrollFrame.scrollBar:SetValue(0)
	LevelTimingsUI:UpdateList()
end

function LevelTimingsUI:BuildSortedLevelRows(entry)
	local timings = entry.timings
	local levels = {}
	local n = 1
	for level in pairs(timings) do
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
	self:RegisterForDrag("LeftButton")
	SetPortraitToTexture(LevelTimingsUI_FrameIcon, "Interface\\Icons\\INV_7XP_Inscription_TalentTome01");
	LevelTimingsUI_FrameTitleText:SetText("Level Timings")
	LevelTimingsUI_ScrollFrame.update = LevelTimingsUI.UpdateList
	HybridScrollFrame_CreateButtons(LevelTimingsUI_ScrollFrame, "LevelTimingsUI_ButtonTemplate")

	if false then
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

function LevelTimingsUI_CharactersDropDown_Initialize()
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

	local info = UIDropDownMenu_CreateInfo();
	for _, item in ipairs(sortArray) do
		local name = item.name
		if item.class and RAID_CLASS_COLORS[item.class] then
			name = RAID_CLASS_COLORS[item.class]:WrapTextInColorCode(name)
		end
		local realm = item.realm
		if item.faction and PLAYER_FACTION_GROUP[item.faction] then
			realm = GetFactionColor(item.faction):WrapTextInColorCode(realm)
		end

		info.text = name .. " (" .. realm .. ")"
		info.value = item.guid
		info.func = LevelTimingsUI_CharactersDropDown_OnClick
		info.checked = nil
		UIDropDownMenu_AddButton(info);
	end
end

function LevelTimingsUI_CharactersDropDown_OnLoad(self)
	UIDropDownMenu_SetWidth(self, 200);
	UIDropDownMenu_JustifyText(self, "LEFT")
end

function LevelTimingsUI_CharactersDropDown_OnClick(self)
	LevelTimingsUI:SelectCharacter(self.value)
end

function LevelTimingsUI_CharactersDropDown_OnShow(self)
	UIDropDownMenu_Initialize(self, LevelTimingsUI_CharactersDropDown_Initialize);
	LevelTimingsUI:SetSelectedCharacterInDropDown(LevelTimingsUI.selectedGuid)
end

function LevelTimingsUI_DeleteCharacterButton_Click(self)
	LevelTimingsUI:InitiateDelete()
end
