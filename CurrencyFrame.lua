
--- @type VendorCurrency_API
local _, VendorCurrency_API = ...;

local VendorCurrencyFrame = CreateFrame("Frame", "GhostVendorCurrencyFrame", nil, "ButtonFrameTemplate");

-- Currency Buttons

local CurrencyButtonMixin = {};

function CurrencyButtonMixin:SetCurrencyItemLink(itemLink)
    self.LinkedItem = Item:CreateFromItemLink(itemLink);
    self:SetItem(itemLink);

    self:SetScript("OnEnter", function(button)
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT");
        GameTooltip:SetItemByID(self.LinkedItem:GetItemID());
    end);

    self:SetScript("OnLeave", GameTooltip_Hide);

    self:SetScale(0.7);

    self.Label = self:CreateFontString(nil, "OVERLAY", "GameFontNormal");
    self.Label:SetWordWrap(true);
    self.Label:SetNonSpaceWrap(true);
    self.Label:SetJustifyH("LEFT");
    self.Label:SetPoint("LEFT", self, "RIGHT", 5, 0);

    local labelRightPoint = VendorCurrencyFrame.ScrollFrame.ScrollChild:GetWidth() - (VendorCurrencyFrame.ScrollFrame.ScrollBar:GetWidth() + 30);

    self.Label:SetPoint("RIGHT", labelRightPoint, 0);
    self.Label:SetScale(1.3);
    self.Label:SetParent(self);
    self.Label:EnableMouse(true);
    self.Label:SetScript("OnEnter", function()
        if self.Label:IsTruncated() then
            local r, g, b, a = self.Label:GetTextColor();
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
            GameTooltip:SetText(self.Label:GetText(), r, g, b, a, true);
        end
    end)

    self.Label:SetScript("OnLeave", GameTooltip_Hide);

    self:SetParent(VendorCurrencyFrame.ScrollFrame.ScrollChild);

    local parentKey = self.LinkedItem:GetItemName():gsub(" ", "");
    self:SetParentKey(parentKey);

    self.LinkedItem:ContinueOnItemLoad(function()
        local itemName = self.LinkedItem:GetItemName();
        self.Label:SetText(itemName);
        if VendorCurrencyFrame:IsShown() then
            self:Show();
        end
    end);
end

function CurrencyButtonMixin:UpdateLabelWithOwnedQuanity()
    if self.LinkedItem:HasItemLocation() then
        local stack = C_Item.GetStackCount(self.LinkedItem:GetItemLocation());
        if stack > 0 then
            self.Label:SetText(self.LinkedItem:GetItemName() .. "\n(In Bags: " .. stack .. ")");
        else
            self.Label:SetText(self.LinkedItem:GetItemName());
        end
    end
end


local function CreateCurrencyButton()
    local button = CreateFrame("ItemButton", nil, VendorCurrencyFrame.ScrollFrame.ScrollChild);

    return Mixin(button, CurrencyButtonMixin);
end

local function ResetCurrencyButton(_, button)
    local parent = button:GetParent();

    if parent then
        local parentKey = button:GetParentKey();
        if parentKey and parent[parentKey] then
            parent[parentKey] = nil;
        end
    end

    if button.LinkedItem then
        button.LinkedItem:Clear();
    end

    if button.Label then
        button.Label:SetParent();
        button.Label = nil;
    end

    button:ClearAllPoints();
    button:Reset();
    button:SetParent();
    button:Hide();
end

-- Vendor Currency Frame

function VendorCurrencyFrame:Init()
    if not MerchantFrame then
        return;
    end

    self:RegisterEvent("BAG_UPDATE")
    self:SetScript("OnEvent", function(_, event, ...)
        if event == "BAG_UPDATE" and self:IsShown() then
            self:UpdateAllOwnedItems();
        end
    end);

    self.currencyButtons = {};
    self.currencyButtonsPool = CreateObjectPool(CreateCurrencyButton, ResetCurrencyButton);
    self.lastButtonAdded = nil;

    self:SetParent(MerchantFrame);
    self:SetPoint("TOPLEFT", MerchantFrame, "TOPRIGHT", 0, 0);
    self:SetWidth(250);
    self:SetTitle("Item Currencies");
    self:SetTitleOffsets(0, 0);

    securecallfunction(ButtonFrameTemplate_HidePortrait, self);
    securecallfunction(ButtonFrameTemplate_HideButtonBar, self);
    securecallfunction(ButtonFrameTemplate_HideAttic, self);

    self.CloseButton:HookScript("OnClick", function()
        self:OnHide();
    end);

    self:SetupScrollFrame();
    self.Initialized = true;
end

function VendorCurrencyFrame:UpdateAllOwnedItems()
    if not self.OwnedItems then
        return;
    end

    for _, button in ipairs(self.OwnedItems) do
        button:UpdateLabelWithOwnedQuanity();
    end
end

function VendorCurrencyFrame:AddCurrencyFromItemLink(itemLink)
    local button = self.currencyButtonsPool:Acquire();
    button:SetCurrencyItemLink(itemLink);

    self.currencyButtons[button.LinkedItem:GetItemID()] = button;
end

function VendorCurrencyFrame:SortItemButtons()
    local scrollChild = self.ScrollFrame.ScrollChild;
    local lastButton;

    local ownedItems = {};
    local unownedItems = {};

    for _, button in pairs(self.currencyButtons) do
        if button.LinkedItem:HasItemLocation() then
            tinsert(ownedItems, button);
        else
            tinsert(unownedItems, button);
        end
    end

    for _, button in pairs(ownedItems) do
        if not lastButton then
            button:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 10, -8);
        else
            button:SetPoint("TOPLEFT", lastButton, "BOTTOMLEFT", 0, -5);
        end
        securecallfunction(SetItemButtonDesaturated, button, false);
        lastButton = button;
    end

    for _, button in pairs(unownedItems) do
        if not lastButton then
            button:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 10, -8);
        else
            button:SetPoint("TOPLEFT", lastButton, "BOTTOMLEFT", 0, -5);
        end
        securecallfunction(SetItemButtonDesaturated, button, true);
        lastButton = button;
    end
end

function VendorCurrencyFrame:UpdateFrameHeight()
    local targetHeight = 0;
    local lineHeight = 30;
    local lineMargin = 5;
    local minHeight = 225;
    local maxHeight = MerchantFrame:GetHeight();

    targetHeight = (self.currencyButtonsPool:GetNumActive()) * (lineHeight + lineMargin);
    local height = min(maxHeight, max(minHeight, targetHeight));

    self:SetHeight(height);
    self.ScrollFrame:SetHeight(self.Inset:GetHeight());
    self.ScrollFrame:GetScrollChild():SetHeight(self.ScrollFrame:GetHeight() -5);
end

function VendorCurrencyFrame:ShowAllItemButtons()
    for _, button in pairs(self.currencyButtons) do
        button:Show();
    end
    self:SortItemButtons();
end

function VendorCurrencyFrame:OnShow()
    if not self.Initialized then
        self:Init();
    end

    local allCurrencies = VendorCurrency_API.MerchantData:GetAllCurrencies();

    if not allCurrencies then
        self:Hide(); -- no special currencies, or something went terribly wrong
        return;
    end

    if allCurrencies.item then
        for _, currency in ipairs(allCurrencies.item) do
            self:AddCurrencyFromItemLink(currency.link);
        end
    end

    -- TODO: Support generic currencies (allCurrencies.generic)

    self.OwnedItems = VendorCurrency_API.GetItemLocationsForOwnedItems(self.currencyButtons);

    self:UpdateAllOwnedItems();
    self:ShowAllItemButtons();
    self:UpdateFrameHeight();
    self:Show();
end

function VendorCurrencyFrame:OnHide()
    self.currencyButtonsPool:ReleaseAll();
    wipe(self.currencyButtons);
    self:Hide();
end

function VendorCurrencyFrame:SetupScrollFrame()
    if self.ScrollFrame then
        return;
    end

    self.ScrollFrame = CreateFrame("ScrollFrame", nil, self, "ScrollFrameTemplate");
    self.ScrollFrame:SetPoint("TOPLEFT", self.Inset, "TOPLEFT", 0, -5);
    self.ScrollFrame:SetPoint("TOPRIGHT", self.Inset, "TOPRIGHT", 0, -5);

    self.ScrollFrame.ScrollBar:SetPoint("TOPLEFT", self.ScrollFrame, "TOPRIGHT", -20, -8);
    self.ScrollFrame.ScrollBar:SetPoint("BOTTOMLEFT", self.ScrollFrame, "BOTTOMRIGHT", -20, 5);
    self.ScrollFrame.ScrollBar:SetHideIfUnscrollable(true);
    self.ScrollFrame.ScrollBar:Update();

    self.ScrollFrame.ScrollChild = CreateFrame("Frame", nil, self.ScrollFrame)
    self.ScrollFrame.ScrollChild:SetWidth(self.Inset:GetWidth());

    self.ScrollFrame:SetScrollChild(self.ScrollFrame.ScrollChild);
    self.ScrollFrame.ScrollChild:Show();
    self.ScrollFrame:Show();
end

local function CreateOrShowFrameToggleButton()
    if VendorCurrencyFrameToggleButton then
        VendorCurrencyFrameToggleButton:Show();
        return;
    end

    VendorCurrencyFrameToggleButton = CreateFrame("Button", "GhostVendorCurrencyFrameToggleButton", MerchantFrameCloseButton);
    VendorCurrencyFrameToggleButton:SetPoint("RIGHT", MerchantFrameCloseButton, "LEFT", 3, 0);
    VendorCurrencyFrameToggleButton:SetSize(MerchantFrameCloseButton:GetSize());
    VendorCurrencyFrameToggleButton:SetNormalTexture("Interface\\Buttons\\UI-Panel-BiggerButton-Up");
    VendorCurrencyFrameToggleButton:SetPushedTexture("Interface\\Buttons\\UI-Panel-BiggerButton-Down");
    VendorCurrencyFrameToggleButton:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD");
    VendorCurrencyFrameToggleButton:SetDisabledTexture("Interface\\Buttons\\UI-Panel-SmallerButton-Disabled");
    VendorCurrencyFrameToggleButton:SetScale(1.3);
    VendorCurrencyFrameToggleButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
        GameTooltip:SetText("Toggle Item Currencies Display");
    end);

    VendorCurrencyFrameToggleButton:SetScript("OnLeave", GameTooltip_Hide);

    VendorCurrencyFrameToggleButton:EnableMouse(true);

    VendorCurrencyFrameToggleButton:SetScript("OnClick", function(self)
        VendorCurrencyFrame:OnShow();
        self:SetEnabled(not VendorCurrencyFrame:IsShown())
    end);

    VendorCurrencyFrameToggleButton:SetEnabled(not VendorCurrencyFrame:IsShown())

    VendorCurrencyFrame:HookScript("OnShow", function()
        VendorCurrencyFrameToggleButton:SetEnabled(false);
    end)

    VendorCurrencyFrame:HookScript("OnHide", function()
        if MerchantFrame:IsShown() then
            VendorCurrencyFrameToggleButton:SetEnabled(true);
        end
    end)

    VendorCurrencyFrameToggleButton:Show();
end

-- Hook Merchant Frame

MerchantFrame:HookScript("OnShow", function()
    VendorCurrencyFrame:OnShow();
    CreateOrShowFrameToggleButton();
end)

MerchantFrame:HookScript("OnHide", function()
    VendorCurrencyFrame:OnHide();
    VendorCurrencyFrameToggleButton:Hide();
end)