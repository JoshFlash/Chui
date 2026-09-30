-- Dev/ApiCheck.lua  (development only; the packager comments it out of releases)
-- /chui apicheck confirms every function and event Chui relies on exists in
-- the running client (Appendix A), plus the Blizzard extension points the
-- Suppressor depends on. Run it after every patch.
local _, Chui = ...

local FUNCTIONS = {
    -- Input
    "IsKeyDown", "C_Texture.GetAtlasInfo", "IsModifiedClick", "PickupMerchantItem", "OpenStackSplitFrame",
    "C_Item.GetItemQualityByID", "StackSplitFrame.OpenStackSplitFrame", "C_Container.ShowContainerSellCursor", "SetCursor", "ResetCursor",
    "ShowInspectCursor", "hooksecurefunc",
    -- Gossip
    "C_GossipInfo.GetText", "C_GossipInfo.GetOptions", "C_GossipInfo.GetAvailableQuests",
    "C_GossipInfo.GetActiveQuests", "C_GossipInfo.SelectOption", "C_GossipInfo.SelectOptionByIndex",
    "C_GossipInfo.SelectAvailableQuest", "C_GossipInfo.SelectActiveQuest", "C_GossipInfo.CloseGossip",
    "C_GossipInfo.ForceGossip",
    -- Quest greeting
    "GetGreetingText", "GetNumAvailableQuests", "GetAvailableTitle", "GetAvailableQuestInfo",
    "GetNumActiveQuests", "GetActiveTitle", "SelectAvailableQuest", "SelectActiveQuest",
    -- Quest offer / turn-in
    "GetTitleText", "GetQuestID", "GetQuestText", "GetObjectiveText", "GetProgressText", "GetRewardText",
    "AcceptQuest", "DeclineQuest", "CompleteQuest", "GetQuestReward", "CloseQuest", "IsQuestCompletable",
    "QuestGetAutoAccept", "AcknowledgeAutoAcceptQuest", "QuestIsFromAreaTrigger", "QuestIsFromAdventureMap",
    "QuestFlagsPVP", "GetNumQuestItems", "GetNumQuestRewards", "GetNumQuestChoices", "GetQuestItemInfo",
    "GetQuestItemLink", "GetRewardMoney", "GetRewardXP", "GetQuestMoneyToGet", "GetRewardTitle",
    "C_QuestOffer.GetQuestRewardCurrencyInfo", "C_QuestOffer.GetQuestRequiredCurrencyInfo",
    "C_QuestOffer.GetQuestOfferMajorFactionReputationRewards",
    "C_QuestInfoSystem.GetQuestClassification", "C_QuestLog.GetQuestTagInfo",
    -- Merchant
    "GetMerchantNumItems", "C_MerchantFrame.GetItemInfo", "GetMerchantItemLink",
    "GetMerchantItemCostInfo", "GetMerchantItemCostItem", "GetMerchantItemMaxStack", "BuyMerchantItem",
    "GetMerchantFilter", "SetMerchantFilter", "GetNumBuybackItems", "GetBuybackItemInfo", "BuybackItem",
    "CanMerchantRepair", "GetRepairAllCost", "RepairAllItems", "CanGuildBankRepair",
    "C_MerchantFrame.GetNumJunkItems", "C_MerchantFrame.SellAllJunkItems", "CloseMerchant",
    -- Trainer (Retail's own trainer UI no longer calls the last four; confirm)
    "GetNumTrainerServices", "GetTrainerServiceInfo", "GetTrainerServiceCost", "GetTrainerServiceSkillReq",
    "SelectTrainerService", "BuyTrainerService", "SetTrainerServiceTypeFilter", "GetTrainerServiceTypeFilter",
    "IsTradeskillTrainer", "GetTrainerTradeskillRankValues", "CloseTrainer",
    "GetTrainerServiceIcon", "GetTrainerServiceDescription", "GetTrainerServiceLevelReq", "GetTrainerGreetingText",
    -- Item text
    "ItemTextGetText", "ItemTextGetItem", "ItemTextGetMaterial", "ItemTextGetPage",
    "ItemTextHasNextPage", "ItemTextNextPage", "ItemTextPrevPage", "CloseItemText",
    -- Shared
    "SetPortraitTexture", "UnitName", "InCombatLockdown", "C_Item.GetItemQualityColor",
    "HandleModifiedItemClick", "CreateFramePool", "GetMoneyString", "C_EventUtils.IsEventValid",
    "PixelUtil.SetPoint", "PixelUtil.SetSize",
    -- Suppressor extension points
    "SetPlayerInteractionConditions", "CustomGossipFrameManager.GetHandler",
}

local EVENTS = {
    "GOSSIP_SHOW", "GOSSIP_CLOSED", "GOSSIP_CONFIRM", "GOSSIP_CONFIRM_CANCEL", "GOSSIP_ENTER_CODE",
    "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_FINISHED",
    "QUEST_ITEM_UPDATE", "QUEST_ACCEPTED",
    "MERCHANT_SHOW", "MERCHANT_UPDATE", "MERCHANT_FILTER_ITEM_UPDATE", "MERCHANT_CLOSED",
    "BAG_UPDATE_DELAYED", "PLAYER_MONEY", "CURRENCY_DISPLAY_UPDATE", "UPDATE_INVENTORY_DURABILITY",
    "TRAINER_SHOW", "TRAINER_UPDATE", "TRAINER_DESCRIPTION_UPDATE", "TRAINER_CLOSED",
    "ITEM_TEXT_BEGIN", "ITEM_TEXT_READY", "ITEM_TEXT_CLOSED",
    "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "PLAYER_INTERACTION_MANAGER_FRAME_HIDE",
    "GET_ITEM_INFO_RECEIVED", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED",
    "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "ADDON_LOADED", "MODIFIER_STATE_CHANGED",
}

local function Resolve(path)
    local value = _G
    for part in path:gmatch("[^%.]+") do
        if type(value) ~= "table" then return nil end
        value = value[part]
    end
    return value
end

Chui:RegisterCommand("apicheck", "dev: verify every API and event Chui uses exists", function()
    local missing = 0
    for _, name in ipairs(FUNCTIONS) do
        if type(Resolve(name)) ~= "function" then
            missing = missing + 1
            print("  " .. Chui.Theme.Paint("bad", "missing function"), name)
        end
    end
    for _, event in ipairs(EVENTS) do
        if not C_EventUtils.IsEventValid(event) then
            missing = missing + 1
            print("  " .. Chui.Theme.Paint("bad", "unknown event"), event)
        end
    end
    for _, key in ipairs({ "Gossip", "QuestGiver", "Merchant", "Trainer" }) do
        if not Enum.PlayerInteractionType[key] then
            missing = missing + 1
            print("  " .. Chui.Theme.Paint("bad", "missing enum") .. " Enum.PlayerInteractionType." .. key)
        end
    end
    local _, build, _, toc = GetBuildInfo()
    Chui:Print(("apicheck on %d (build %s): %d functions, %d events, %s")
        :format(toc, build, #FUNCTIONS, #EVENTS,
            missing == 0 and Chui.Theme.Paint("good", "all present") or Chui.Theme.Paint("bad", ("%d problems"):format(missing))))
end)
