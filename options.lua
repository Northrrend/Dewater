local _, MySlot = ...
local L = MySlot.L
local RegEvent = MySlot.regevent


local f = CreateFrame("Frame", nil, UIParent)
f.name = L["Dewater"]
InterfaceOptions_AddCategory(f)

RegEvent("ADDON_LOADED", function()
    do
        local t = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        t:SetText(L["Dewater"])
        t:SetPoint("TOPLEFT", f, 15, -15)
    end

    do
        local t = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        t:SetText(L["Feedback"] .. "  xjq314")
        t:SetPoint("TOPLEFT", f, 15, -50)
    end


    do
        local b = CreateFrame("Button", nil, f, "GameMenuButtonTemplate")
        b:SetWidth(200)
        b:SetHeight(25)
        b:SetPoint("TOPLEFT", 15, -80)
        b:SetText(L["Open Dewater"])
        b:SetScript("OnClick", function()
            MySlot.MainFrame:Show()
            InterfaceOptionsFrame_Show()
        end)
    end


    do
        MyslotSettings = MyslotSettings or {}
        MyslotSettings.minimap = MyslotSettings.minimap or { hide = false }
        local config = MyslotSettings.minimap

        local b = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
        b:SetPoint("TOPLEFT", f, 15, -110)

        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        b.text:SetPoint("LEFT", b, "RIGHT", 0, 1)
        b.text:SetText(L["Minimap Icon"])
        b:SetChecked(not config.hide)
        b:SetScript("OnClick", function()
            config.hide = not b:GetChecked()

            local icon = LibStub("LibDBIcon-1.0")
            if b:GetChecked() then
                icon:Show("Myslot")
            else
                icon:Hide("Myslot")
            end
        end)
    end

    local doffset = -160

end)