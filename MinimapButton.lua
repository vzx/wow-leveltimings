

local eventsFrame = CreateFrame("Frame")
eventsFrame:RegisterEvent("ADDON_LOADED")
eventsFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("ADDON_LOADED")
    local angle = LevelTimings_GetConfig("MinimapButton_Angle") or -174
	LevelTimingsUI_MinimapButton_SetPosition(angle)
end)

function LevelTimingsUI_MinimapButton_OnClick(self)
	LevelTimingsUI_ToggleShown()
end

function LevelTimingsUI_MinimapButton_OnLoad(self)
	self:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	self:RegisterForDrag("LeftButton", "RightButton")
end

function LevelTimingsUI_MinimapButton_OnDragStart(self)
	self:LockHighlight()
	self:SetScript("OnUpdate", LevelTimingsUI_MinimapButton_OnUpdate)
end

function LevelTimingsUI_MinimapButton_OnDragStop(self)
	self:SetScript("OnUpdate", nil)
	self:UnlockHighlight()
end

function LevelTimingsUI_MinimapButton_OnUpdate(self)
	local cursorX, cursorY = GetCursorPosition()
	local scale = UIParent:GetScale()

	local x = Minimap:GetLeft() - (cursorX / scale) + 70
	local y = (cursorY / scale) - Minimap:GetBottom() - 70

	local angle = math.deg(math.atan2(y, x))

	LevelTimings_SetConfig("MinimapButton_Angle", angle)

	self:Raise()
	LevelTimingsUI_MinimapButton_SetPosition(angle)
end

function LevelTimingsUI_MinimapButton_SetPosition(angle)
	LevelTimingsUI_MinimapButton:SetPoint("CENTER", "Minimap", "CENTER", (-78) * cos(angle), 78 * sin(angle))
end
