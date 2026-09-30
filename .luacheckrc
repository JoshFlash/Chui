std = "lua51"
max_line_length = false
exclude_files = { "Libs/", "LocalDev/" }

-- Chui's own globals.
globals = { "ChuiDB", "SLASH_CHUI1", "SlashCmdList", "UISpecialFrames" }

-- WoW API used by Chui. Add to this as new APIs come into use; a luacheck
-- "undefined variable" on a Blizzard name means it belongs here.
read_globals = {
    "C_AddOns", "C_EventUtils", "C_GossipInfo", "C_Item", "C_MerchantFrame",
    "C_QuestInfoSystem", "C_QuestLog", "C_QuestOffer", "C_Timer",
    "CreateFrame", "CreateFramePool", "Enum", "PixelUtil", "UIParent",
    "CustomGossipFrameManager", "GossipFrame", "QuestFrame", "MerchantFrame",
    "ClassTrainerFrame", "debugprofilestop", "geterrorhandler", "issecretvalue",
    "wipe", "tinsert", "date", "GetTime", "GetMoney", "GetMoneyString",
    "InCombatLockdown", "LibStub", "C_Texture", "IsKeyDown", "IsShiftKeyDown", "IsControlKeyDown", "IsAltKeyDown",
    "SetPlayerInteractionConditions", "UnitName", "GetMinimapZoneText",
    "CloseMerchant", "GetMerchantNumItems", "AcceptQuest", "AcknowledgeAutoAcceptQuest",
    "CloseQuest", "CompleteQuest", "DeclineQuest", "GetQuestReward", "GetTitleText",
    "GetQuestText", "GetObjectiveText", "GetProgressText", "GetRewardText",
    "GetGreetingText", "GetNumActiveQuests", "GetNumAvailableQuests",
    "GetActiveTitle", "GetAvailableQuestInfo", "GetAvailableTitle",
    "SelectActiveQuest", "SelectAvailableQuest", "IsQuestCompletable",
    "QuestFlagsPVP", "QuestGetAutoAccept", "QuestIsFromAdventureMap",
    "QuestIsFromAreaTrigger", "GetQuestID", "GetNumQuestChoices",
    "GetNumQuestRewards", "GetNumQuestItems",
    "ACCEPT", "OKAY", "CONTINUE", "COMPLETE_QUEST", "QUEST_OBJECTIVES", "UNKNOWN",
}
