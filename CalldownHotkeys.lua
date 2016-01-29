-- ===============================
--	CalldownHotkeys (The Takeover) v1.0
--	 by: RadthorDax ; TAKEN OVER BY HANACHI! MUAHAHAHAHA!
--  Maintenance: v2.A4 by Amayani
-- ===============================

require "table"
require "math"
require "string"
require "lib/lib_table"
require "lib/lib_Slash"
require "lib/lib_InterfaceOptions"
require "lib/lib_DropDownList"
require "lib/lib_RoundedPopupWindow"
require "lib/lib_UserKeybinds"
require "lib/lib_InputIcon"
require "lib/lib_Debug"
require "lib/lib_NestedList"
require "lib/lib_HoloPlate"
require "lib/lib_Button"
require "lib/lib_Colors"
require "./lib_RedBand"
require "./ListNode"

-- ===============================
--	Variables
-- ===============================

local LookupIDs = {};

local loaded = false;
local ready = false;

local io_EnabledAlerts = true;
local io_DefaultID = 0;

local FOCUS_COLOR = "#FDB300";

local CALLDOWNLIST 		= Component.GetFrame("CalldownList")
local INVISIBLE_GROUP	= Component.GetWidget("InvisibleGroup")
local CLOSE_BUTTON	 	= Component.GetWidget("close");

local KEYCATCHER = {}
local KEYSET = {}
local DATA = {}

local BindFunctions = {}

local Collisions = {}

local LISTS = {}
local GROUPLISTS = {}
local LISTDATA = {}

local cycleFromFirst = false
local previousGroup = "None"

local calldownGroup = {}

local OnMessageOption = {}

local Keybinds = {}
local TextTimer = {}

local stringTable = {
	"Movement",
	"Combat",
	"Interface",
	"Vehicle",
	"Social",
}

local CategoryList = {}

local ButtonPrint = [[<FocusBox id="ButtonGroup" dimensions="center-x:50%; center-y:50%; width:5%; height:55%"></FocusBox>]]

-- ===============================
--	Interface Options
-- ===============================

InterfaceOptions.NotifyOnLoaded(true)
InterfaceOptions.NotifyOnDefaults(true)

InterfaceOptions.StartGroup({id="ENABLED", label="Calldown Hotkeys", checkbox=true, default=true})
InterfaceOptions.AddTextInput({id="DEFAULT_ID", label="Default Calldown ID", tooltip="The ID of the calldown to load on startup.", default="30287", whitespace=false, maxlen=10});
InterfaceOptions.AddCheckBox({id="ENABLE_ALERTS", label="Enable Alerts", tooltip="Toggles debug messages and slotting messages.", default=true});
InterfaceOptions.AddTextInput({id="TRIGGER", label="Menu Toggle", default="F4", tooltip="Please know what you're doing,\nthis changes the key to toggle the menu.\n\nThis binding is only restricted by bound calldowns with binding restriction on.\n\nTakes a keyString, F4 being F4. "})
InterfaceOptions.AddCheckBox({id="RESTRICT", label="Restrict bindings", default=true, tooltip="Please know what you're doing.\nThis will remove binding restrictions.\nOnly turn this off if you have to."})
InterfaceOptions.AddCheckBox({id="ID", label="Toggle Calldown display.", default=true, tooltip="Whether or not to show a\ncalldown's name/id.\n\nIf true, displays calldown Id."})
InterfaceOptions.AddCheckBox({id="CYCLE_ID", label="Cycle groups always start from first item", default=false, tooltip="Toggles whether or not groups with the cycle method will always start from first item or the last known position."})
InterfaceOptions.StopGroup()

-- ===============================
--	Events
-- ===============================

function OnComponentLoad()
	InterfaceOptions.SetCallbackFunc(function(id, val)
		OnMessage({type=id, data=val})
	end, "Calldown Hotkeys v2")

	Keybinds = Component.GetSetting("Keybinds") or {}
	GroupKeybinds = Component.GetSetting("GroupKeybinds") or {}
	GroupData = Component.GetSetting("GroupData") or {}
	GroupInfo = Component.GetSetting("GroupInfo") or {}

	SortFunc = {}

	SortFunc["Name"] = function(a,b) return Game.GetItemInfoByType(a.itemTypeId).name<Game.GetItemInfoByType(b.itemTypeId).name end
	SortFunc["ReverseName"] = function(a,b) return Game.GetItemInfoByType(a.itemTypeId).name>Game.GetItemInfoByType(b.itemTypeId).name end

	SortFunc["Quantity"] = function(a,b) return Player.GetItemCount(a.itemTypeId)>Player.GetItemCount(b.itemTypeId) end
	SortFunc["ReverseQuantity"] = function(a,b) return Player.GetItemCount(a.itemTypeId)<Player.GetItemCount(b.itemTypeId) end

	-- X Button

	CLOSE_BUTTON:BindEvent("OnMouseDown", function()
		ToggleIt()
	end);

	local X = CLOSE_BUTTON:GetChild("X");
	CLOSE_BUTTON:BindEvent("OnMouseEnter", function() X:ParamTo("exposure", 1, 0.15); end);
	CLOSE_BUTTON:BindEvent("OnMouseLeave", function() X:ParamTo("exposure", 0, 0.15); end);
end

function OnLoading(args)
	if Game.GetLoadingProgress() == 1 then

		DetailMode()

		KEYSET = {}

		for ID,KEYBIND in pairs(Keybinds) do
			BindKey(KEYBIND, ID)
		end
	end
end

function OnReloadUI()
	System.BlurMainScene(false)

	for ID in pairs(GroupData) do
		UpdateGroup(ID)
	end
end

function OnMessage(args)
	local option, message = args.type, args.data
	if not ( OnMessageOption[option] ) then return nil end
	OnMessageOption[option](message)
end

OnMessageOption.__LOADED = function()
	onmessageLoaded = true
end

OnMessageOption.__DEFAULT = function()
	for k in pairs(KEYSET) do
		KEYSET[k]:Destroy()
		KEYSET[k] = nil
	end

	for k in pairs(DATA) do
		if DATA[k].INPUT then
			DATA[k].INPUT:Destroy()
			DATA[k].INPUT = nil
		end
	end

	Keybinds = {}
	Component.SaveSetting("Keybinds", Keybinds)

	KEYSET["Menu"] = UserKeybinds.Create()
	KEYSET["Menu"]:RegisterAction("Menu", ToggleIt)
	KEYSET["Menu"]:BindKey("Menu", 115)
end


OnMessageOption.ENABLED = function(val)
	if KEYSET then
		for k in pairs(KEYSET) do
			KEYSET[k]:Activate(val)
		end
	end
	enabled = val
end

OnMessageOption.RESTRICT = function(val)
	restrictBinds = val
end

OnMessageOption.ENABLE_ALERTS = function(val)
	io_EnabledAlerts = val;
	Debug.EnableLogging(val)
end

OnMessageOption.DEFAULT_ID = function(val)
	io_DefaultID = tonumber(val);
	if onmessageLoaded then
		if (ready) then
			Slot(io_DefaultID);
		end
		loaded = true;
	end
end

OnMessageOption.CYCLE_ID = function(val)
	cycleFromFirst = val
end

OnMessageOption.TRIGGER = function(val)
	if restrictBinds then
		local returnedVal = ReturnCanMenu(val)
		if not returnedVal then
			if KEYSET["Menu"] then KEYSET["Menu"]:Destroy() end
			KEYSET["Menu"] = UserKeybinds.Create()
			KEYSET["Menu"]:RegisterAction("Menu", ToggleIt)
			KEYSET["Menu"]:BindKey("Menu", val)
			menuBind = val
		else
			if returnedVal ~= "Menu" then
				Debug.Warn("Cannot bind Menu, conflict: " .. Game.GetItemInfoByType(returnedVal).name)
			else
				Debug.Warn("Menu is already bound to that key.")
			end
		end
	else
		if KEYSET["Menu"] then KEYSET["Menu"]:Destroy() end
		KEYSET["Menu"] = UserKeybinds.Create()
		KEYSET["Menu"]:RegisterAction("Menu", ToggleIt)
		KEYSET["Menu"]:BindKey("Menu", val)
		menuBind = val
	end
end

OnMessageOption.ID = function(val)
	idDisplay = val
end

function OnPlayerReady()
	if ready then return nil end
	ready = true;
	callback(InitStuff, nil, .25)
end

function InitStuff()
	Slot(io_DefaultID);

	if Player.IsReady() then
		for ID,KEYBIND in pairs(Keybinds) do
			BindKey(KEYBIND, ID)
		end
	end

	for ID,GROUP in pairs(GroupData) do
		if #GROUP >= 1 then
			FocusedFocus = MakeGroup(ID, true)
			CreateGroup(ID, GROUP)
		else
			GroupData[ID] = nil
			Component.SaveSetting("GroupData", GroupData)
		end
	end

	FocusedFocus = nil

	for GROUP,KEYBIND in pairs(GroupKeybinds) do
		if LISTS[GROUP] then
			BindGroup(GROUP, KEYBIND)
		else
			GroupKeybinds[GROUP] = nil
			Component.SaveSetting("GroupKeybinds", GroupKeybinds)
		end
	end
end


function OnLoadCalldown(args)
	if (args.id) then
		Slot(tonumber(args.id));
	end
end

function OnHotkeys(args)
	Debug.Table("Pushed keys", args.keys)
end

-- ===============================
--	Functions
-- ===============================

function ReturnCanMenu(keyCode)
	local keyTable = {}
	for k in pairs(KEYSET) do if tostring(keyCode) == tostring(KEYSET[k]:ExportKeybinds()[k][1]) then return k end end
	return nil
end

-- 38 Up Arrow -- 40 Down Arrow --

function Slot(id)
	if Player.IsReady() then
		if type(id) == "table" then
			id = id.name
		end
		Debug.Log("Slot: " .. tostring(id))
		local old = GetSlottedCalldownID();
		Player.SlotTech(id, id);
		if (GetSlottedCalldownID() ~= old) then
			out("Loaded " .. GetNameByID(id) .. ".");
		end
	else
		callback(Slot, id, 1)
	end
end

function DetailMode()
	if PARENTLIST and ENTRY and DATA then
		for _,LIST in pairs(CAT) do
			LIST.NESTER:Clear()
		end
		
		for _,INPUT in pairs(DATA) do
			INPUT = nil
		end

		for _,CALLDOWN in pairs(ENTRY) do
			CALLDOWN = nil
		end

		ENTRY = nil
	end

	UpdateList()

	if not FocusQuantity then
		FocusQuantity = Component.CreateWidget('<FocusBox id="quantity" dimensions="height:30; width:49%; center-x:75%; center-y:-3.5%"/>', Component.GetWidget("List"))
		FocusName = Component.CreateWidget('<FocusBox id="name" dimensions="height:30; width:49%; center-x:25%; center-y:-3.5%"/>', Component.GetWidget("List"))

		PanelQuantity = HoloPlate.Create(FocusQuantity)
		PanelName = HoloPlate.Create(FocusName)

		FocusQuantity:BindEvent("OnMouseDown", function() Sort("Quantity", nil) end)
		FocusQuantity:BindEvent("OnMouseEnter", function() PanelQuantity.INNER:ParamTo("exposure", 1, .15) end)
		FocusQuantity:BindEvent("OnMouseLeave", function() PanelQuantity.INNER:ParamTo("exposure", 0, .15) end)

		FocusName:BindEvent("OnMouseDown", function() Sort("Name", nil) end)
		FocusName:BindEvent("OnMouseEnter", function() PanelName.INNER:ParamTo("exposure", 1, .15) end)
		FocusName:BindEvent("OnMouseLeave", function() PanelName.INNER:ParamTo("exposure", 0, .15) end)

		PanelQuantity:SetColor("555555")
		PanelName:SetColor("555555")

		TextQuantity = Component.CreateWidget('<Text id="TextQuantity" key="{Quantity}" dimensions="dock:fill" style="font:Demi_15; halign:center; valign:center; shadow:0; eatsmice:false"/>', FocusQuantity)
		TextName = Component.CreateWidget('<Text id="TextQuantity" key="{Name}" dimensions="dock:fill" style="font:Demi_15; halign:center; valign:center; shadow:0; eatsmice:false"/>', FocusName)
	end

	if Player.IsReady() and onmessageLoaded and Player.GetConsumableItems() then
		if not PARENTLIST then
			PARENTLIST = NestedList.Create(Component.GetWidget("List"))

			CALLDOWNLIST:BindEvent("OnEscape", function() ToggleIt() end)
		end

		if not DETAIL then
			DETAIL = {}
		end

		if not CAT then
			CAT = {}

			CategoryList = GetAllFoundCategories()

			for CATEGORY,_ in pairs(CategoryList) do
				CAT[CATEGORY] = {}

				-- Nesting Group
				CAT[CATEGORY].GROUP = Component.CreateWidget('<Group dimensions="top:0; width:100%; height:38"/>', INVISIBLE_GROUP)

				-- Backplate
				CAT[CATEGORY].PLATE = HoloPlate.Create(CAT[CATEGORY].GROUP)
				CAT[CATEGORY].PLATE:SetColor("#555555")

				-- Label
				CAT[CATEGORY].TEXT = Component.CreateWidget('<Text key="{' .. CATEGORY .. '}" dimensions="center-x:51%; center-y:50%; width:100%; height:100%" style="font:UbuntuMedium_11; halign:left; valign:center; eatsmice:false"/>', CAT[CATEGORY].GROUP)
				CAT[CATEGORY].TEXT:SetTag(groupId)

				-- Create our list
				CAT[CATEGORY].NESTER = PARENTLIST:CreateItem(CAT[CATEGORY].GROUP)
			end
		end

		for _,CALLDOWN in pairs(Player.GetConsumableItems()) do
			if not ENTRY then ENTRY = {} end
			local calldownId = tostring(CALLDOWN.itemTypeId)
			local abilityId = tostring(CALLDOWN.abilityId)
			if not(ENTRY[calldownId] or Keybinds[calldownId]) then
				ENTRY[calldownId] = {}

				-- Nesting Group
				ENTRY[calldownId].GROUP = Component.CreateWidget('<Group dimensions="top:0; width:98.5%; height:32"/>', INVISIBLE_GROUP)

				-- Backplate
				ENTRY[calldownId].PLATE = HoloPlate.Create(ENTRY[calldownId].GROUP)
				ENTRY[calldownId].PLATE:SetColor("#85555555")

				-- Labels
				ENTRY[calldownId].TEXT = Component.CreateWidget('<Text key="{' .. Game.GetItemInfoByType(calldownId).name:gsub('%"', '&quot;') .. '}" dimensions="center-x:55%; center-y:50%; width:100%; height:100%" style="font:Demi_10; halign:left; valign:center; eatsmice:false" />', ENTRY[calldownId].GROUP)
				ENTRY[calldownId].QUANTITY = Component.CreateWidget('<Text key="{' .. Player.GetItemCount(CALLDOWN.itemTypeId) .. '}" dimensions="center-x:50%; center-y:50%; width:100%; height:100%" style="font:Demi_10; halign:center; valign:center; eatsmice:false" />', ENTRY[calldownId].GROUP)

				ENTRY[calldownId].NESTER = CAT[Game.GetItemInfoByType(calldownId).uiCategory].NESTER:CreateItem(ENTRY[calldownId].GROUP)

				-- Stuff for visuals
				DATA[calldownId] = {}

				ENTRY[calldownId].NESTER:AddHandler("OnMouseDown", function() Component.BeginDragDrop("view", ".", "EndDrop") timeCall = callback(function() CreateIcon(calldownId, abilityId) end, nil, .4) end)
				ENTRY[calldownId].NESTER:AddHandler("OnMouseUp", function() if timeCall then if Component.IsWidget(cursorIcon) then Component.RemoveWidget(cursorIcon) cursorIcon = nil end cancel_callback(timeCall) OnEntryDown(calldownId) end end)

				if FindBind(calldownId) then
					DATA[calldownId].INPUT = InputIcon.CreateVisual(ENTRY[calldownId].NESTER:GetWidget(), resName)
					DATA[calldownId].INPUT:SetDims("height:22; center-x:3%; center-y:50%; width:22;")
					DATA[calldownId].INPUT:SetBind({keycode=FindBind(calldownId), alt=false}, false)
				end

				-- Data

				ENTRY[calldownId].abilityId = abilityId
			end
		end
		
		for calldownId in pairs(Keybinds) do
			MakeCalldownEntry(calldownId, Game.GetItemInfoByType(calldownId).abilityId)
		end

		if sortType then Sort(sortType, true) end
	end
end

function MakeCalldownEntry(calldownId, abilityId)

	ENTRY[calldownId] = {}

	-- Nesting Group
	ENTRY[calldownId].GROUP = Component.CreateWidget('<Group dimensions="top:0; width:98.5%; height:32"/>', INVISIBLE_GROUP)

	-- Backplate
	ENTRY[calldownId].PLATE = HoloPlate.Create(ENTRY[calldownId].GROUP)
	ENTRY[calldownId].PLATE:SetColor("#85555555")

	-- Labels
	ENTRY[calldownId].TEXT = Component.CreateWidget('<Text key="{' .. Game.GetItemInfoByType(calldownId).name:gsub('%"', '&quot;') .. '}" dimensions="center-x:55%; center-y:50%; width:100%; height:100%" style="font:Demi_10; halign:left; valign:center; eatsmice:false" />', ENTRY[calldownId].GROUP)
	ENTRY[calldownId].QUANTITY = Component.CreateWidget('<Text key="{' .. Player.GetItemCount(calldownId) .. '}" dimensions="center-x:50%; center-y:50%; width:100%; height:100%" style="font:Demi_10; halign:center; valign:center; eatsmice:false" />', ENTRY[calldownId].GROUP)

	ENTRY[calldownId].NESTER = CAT[Game.GetItemInfoByType(calldownId).uiCategory].NESTER:CreateItem(ENTRY[calldownId].GROUP)

	-- Stuff for visuals
	DATA[calldownId] = {}

	ENTRY[calldownId].NESTER:AddHandler("OnMouseDown", function() Component.BeginDragDrop("view", ".", "EndDrop") timeCall = callback(function() CreateIcon(calldownId, abilityId) end, nil, .4) end)
	ENTRY[calldownId].NESTER:AddHandler("OnMouseUp", function() if timeCall then if Component.IsWidget(cursorIcon) then Component.RemoveWidget(cursorIcon) cursorIcon = nil end cancel_callback(timeCall) OnEntryDown(calldownId) end end)

	if FindBind(calldownId) then
		DATA[calldownId].INPUT = InputIcon.CreateVisual(ENTRY[calldownId].NESTER:GetWidget(), resName)
		DATA[calldownId].INPUT:SetDims("height:22; center-x:3%; center-y:50%; width:22;")
		DATA[calldownId].INPUT:SetBind({keycode=FindBind(calldownId), alt=false}, false)
	end

	-- Data

	ENTRY[calldownId].abilityId = abilityId

	return ENTRY[calldownId].GROUP
end

function CreateGroup(id, group)
	for index,CALLDOWN in pairs(group) do
		CreateEntry(FocusedFocus.NESTER, CALLDOWN.calldownId, CALLDOWN.abilityId, id)
	end
end

function BindGroup(group, bind)
	if KEYSET[group] then KEYSET[group]:Destroy() end

	KEYSET[group] = UserKeybinds.Create()

	KEYSET[group]:RegisterAction(group, function() SlotGroup(group) end)
	KEYSET[group]:BindKey(group, bind)
end

function HandleGroup(group)

	if newGroup then newGroup = nil end

	ACTIVE_GROUP = group

	local LIST = LISTS[group].NESTER
	local LISTGROUP = LISTDATA[tostring(group)]

	if ROUNDWINDOW then ROUNDWINDOW:Destroy() ROUNDWINDOW = nil end

	-- RoundWindow creation

	ROUNDWINDOW = RoundedPopupWindow.Create(CALLDOWNLIST)

	-- Initializations

	ROUNDWINDOW.BUTTONS = {}
	ROUNDWINDOW.TEXT = {}
	ROUNDWINDOW.INPUT = {}
	ROUNDWINDOW.TEXTINPUT = {}

	-- RoundWindow Modification

	ROUNDWINDOW:EnableClose(true, function() ROUNDWINDOW:Remove() ROUNDWINDOW = nil end)

	ROUNDWINDOW:SetDims("center-x:50%; center-y:50%; height:200; width:235")

	ROUNDWINDOW:SetTitle(group)

	-- Header Text

	ROUNDWINDOW.HEADER.TEXT:SetTextColor("PanelTitle")

	ROUNDWINDOW.HEADER.TEXT:SetFont("Demi_15")

	-- Destroy Button

	ROUNDWINDOW.BUTTONS.DESTROY = Button.Create(ROUNDWINDOW.GROUP)

	ROUNDWINDOW.BUTTONS.DESTROY:SetDims("center-x:25%; center-y:85%; height:22; width:100")

	ROUNDWINDOW.BUTTONS.DESTROY:SetText("Destroy Group")

	ROUNDWINDOW.BUTTONS.DESTROY:Bind(function() 

		if newGroup then group = newGroup newGroup = nil end

		-- Destroy the list.

		LISTS[group].NESTER:Remove() 

		-- Destroy any bindings.

		if GroupKeybinds[group] then
			GroupKeybinds[group] = nil
		end

		if KEYSET[group] then
			KEYSET[group]:Destroy()
			KEYSET[group] = nil
		end

		-- Save keybinds

		Component.SaveSetting("GroupKeybinds", GroupKeybinds)

		-- Nil the stuff

		LISTS[group] = nil 

		LISTDATA[tostring(group)] = nil

		-- Update the drop down list.

		GroupList:ClearItems() 
		UpdateList() 

		-- Destroy the group.

		GroupData[tostring(group)] = nil
		Component.SaveSetting("GroupData", GroupData)

		-- "Close" the window.

		ROUNDWINDOW:Remove()
		ROUNDWINDOW = nil 
	end)

	-- Bind Button

	ROUNDWINDOW.TEXT.BIND = Component.CreateWidget('<Text id="Bind" key="{Bind:}" dimensions="center-x:15%; center-y:30%; height:20; width:60" style="font:Demi_11"/>', ROUNDWINDOW.GROUP)

	ROUNDWINDOW.BUTTONS.BIND = Button.Create(ROUNDWINDOW.GROUP)

	ROUNDWINDOW.BUTTONS.BIND:TintPlate("4f4f4f")
	ROUNDWINDOW.BUTTONS.BIND.PLATE.INNER:SetParam("alpha", 0)

	ROUNDWINDOW.BUTTONS.BIND:SetDims("center-x:36.5%; center-y:30%; height:42; width:42")

	ROUNDWINDOW.BUTTONS.BIND:Bind(BindGroupButton, group)

	-- Input Art

	ROUNDWINDOW.INPUT = InputIcon.CreateVisual(ROUNDWINDOW.BUTTONS.BIND.LABEL_GROUP, "Bind" .. group)

	ROUNDWINDOW.INPUT:GetGroup():EatMice(false)

	ROUNDWINDOW.INPUT:SetDims("height:22; width:22;")

	ROUNDWINDOW.INPUT:SetBind({keycode=GroupKeybinds[group] or "", alt=false}, false)

	-- Name Button

	ROUNDWINDOW.NAMEGROUP = Component.CreateWidget('<Group dimensions="center-x:60%; center-y:50%; height:20; width:65%"/>', ROUNDWINDOW.GROUP)

	ROUNDWINDOW.BUTTONS.NAME = HoloPlate.Create(ROUNDWINDOW.NAMEGROUP)

	ROUNDWINDOW.TEXT.NAME = Component.CreateWidget('<Text id="Name" key="{Name:}" dimensions="center-x:15%; center-y:50%; height:20; width:60" style="font:Demi_11"/>', ROUNDWINDOW.GROUP)

	ROUNDWINDOW.BUTTONS.NAME:SetColor("4f4f4f")
	ROUNDWINDOW.BUTTONS.NAME.INNER:SetParam("alpha", 0)

	ROUNDWINDOW.TEXTINPUT = Component.CreateWidget('<TextInput dimensions="dock:fill" style="texture:colors; region:transparent; font:UbuntuMedium_11; halign:left; valign:center"> <Events> <OnSubmit bind="OnSubmit"/> <OnLostFocus bind="OnLostFocus"/> </Events> </TextInput>', ROUNDWINDOW.NAMEGROUP)

	ROUNDWINDOW.TEXTINPUT:SetText(group)
	ROUNDWINDOW.TEXTINPUT:SetTag(group)

	-- Group Type Button

	ROUNDWINDOW.TYPE = DropDownList.Create(ROUNDWINDOW.GROUP)
	ROUNDWINDOW.TYPE:SetDims("center-x:75%; center-y:85%; height:22; width:100")

	ROUNDWINDOW.TYPE:AddItem("Smart", "smartSlot")
	ROUNDWINDOW.TYPE:AddItem("Cycle", "cycleSlot")
	ROUNDWINDOW.TYPE:AddItem("Set", "setSlot")

	ROUNDWINDOW.TYPE:SetSelectedByValue(GroupInfo[group].groupType)

	ROUNDWINDOW.TYPE:BindOnSelect(SwitchTypes)

	-- Group Index Dropdown

	ROUNDWINDOW.TEXT.INDEX = Component.CreateWidget('<Text id="Name" key="{Index:}" dimensions="center-x:15%; center-y:65%; height:20; width:60" style="font:Demi_11"/>', ROUNDWINDOW.GROUP)

	ROUNDWINDOW.INDEX = DropDownList.Create(ROUNDWINDOW.GROUP)
	ROUNDWINDOW.INDEX:SetDims("center-x:48.5%; center-y:65%; height:22; width:100")

	ROUNDWINDOW.INDEX:AddItem("1", "1")
	ROUNDWINDOW.INDEX:AddItem("2", "2")
	ROUNDWINDOW.INDEX:AddItem("3", "3")
	ROUNDWINDOW.INDEX:AddItem("4", "4")

	ROUNDWINDOW.INDEX:SetSelectedByValue(GroupInfo[group].groupIndex)

	ROUNDWINDOW.INDEX:BindOnSelect(SwitchIndex)
end

function SwitchIndex(index)
	GroupInfo[ACTIVE_GROUP].groupIndex = index

	Component.SaveSetting("GroupInfo", GroupInfo)
end

function SwitchTypes(type)
	GroupInfo[ACTIVE_GROUP].groupType = type

	Component.SaveSetting("GroupInfo", GroupInfo)
end

function BindGroupButton(group)
	ROUNDWINDOW.INPUT:Hide()

	if ROUNDWINDOW.KEYCATCHER then
		Component.RemoveWidget(ROUNDWINDOW.KEYCATCHER)
	end

	ROUNDWINDOW.KEYCATCHER = Component.CreateWidget("KeyCatcher", CALLDOWNLIST):GetChild("KeyCatch")

	ROUNDWINDOW.KEYCATCHER:BindEvent("OnKeyCatch", ProcessBind)
	ROUNDWINDOW.KEYCATCHER:ListenForKey()
	ROUNDWINDOW.KEYCATCHER:SetTag(group)
end

-- TextInput Handling --

function OnSubmit(args)
	local group = args.widget:GetText()
	local otherGroup = args.widget:GetTag()

	RedBand.GenericMessage(otherGroup .. " has been renamed to: " .. group)

	newGroup = group
	
	if not LISTDATA[group] then
		LISTDATA[group] = _table.copy(LISTDATA[otherGroup])
		LISTDATA[otherGroup] = nil

		LISTS[group] = LISTS[otherGroup]
		LISTS[otherGroup] = nil

		LISTS[group].TEXT:SetTag(group)

		ROUNDWINDOW.TEXTINPUT:SetTag(group)

		ACTIVE_GROUP = group

		if ROUNDWINDOW.KEYCATCHER then
			Component.RemoveWidget(ROUNDWINDOW.KEYCATCHER)
			ROUNDWINDOW.KEYCATCHER = Component.CreateWidget("KeyCatcher", CALLDOWNLIST):GetChild("KeyCatch")

			ROUNDWINDOW.KEYCATCHER:BindEvent("OnKeyCatch", ProcessBind)
			ROUNDWINDOW.KEYCATCHER:ListenForKey()

			ROUNDWINDOW.KEYCATCHER:SetTag(group)
		end

		if KEYSET[otherGroup] then
			KEYSET[otherGroup]:Destroy()
			KEYSET[otherGroup] = nil

			GroupKeybinds[group] = _table.copy(GroupKeybinds[otherGroup])
			GroupKeybinds[otherGroup] = nil

			BindGroup(group, GroupKeybinds[group])

			Component.SaveSetting("GroupKeybinds", GroupKeybinds)
		end

		if Collisions[otherGroup] then
			Collisions[group] = _table.copy(Collisions[otherGroup])
			Collisions[otherGroup] = nil
		end

		GroupInfo[group] = _table.copy(GroupInfo[otherGroup])
		GroupInfo[otherGroup] = nil

		ROUNDWINDOW:SetTitle(group)

		ROUNDWINDOW.HEADER.TEXT:SetTextColor("PanelTitle")

		ROUNDWINDOW.HEADER.TEXT:SetFont("Demi_15")
	
		LISTS[group].TEXT:SetText(group)

		UpdateGroup(group)
		UpdateGroup(otherGroup)

		UpdateList()

		Component.SaveSetting("GroupInfo", GroupInfo)
	else
		RedBand.ErrorMessage("This group already exists!")
	end
end

function OnLostFocus(args)
	log(tostring(args))
end

-- End of TextInput handling --

function ProcessBind(args)
	ROUNDWINDOW.INPUT:Show()
	local groupId = ACTIVE_GROUP
	local keyCode = args.widget:GetKeyCode()

	if keyCode ~= 27 and CanBind(keyCode) then
		if KEYSET[groupId] then KEYSET[groupId]:UnregisterAction(groupId) end

		KEYSET[groupId] = UserKeybinds.Create()

		KEYSET[groupId]:RegisterAction(groupId, function() SlotGroup(groupId) end)
		KEYSET[groupId]:BindKey(groupId, keyCode)

		GroupKeybinds[groupId] = keyCode

		Component.SaveSetting("GroupKeybinds", GroupKeybinds)

		ROUNDWINDOW.INPUT:SetBind({keycode=keyCode, alt=false}, false)
		RedBand.GenericMessage(groupId .. " has been bound to: " .. System.GetKeycodeString(keyCode))
	elseif keyCode == 27 then
		RedBand.GenericMessage("Unbound Group: " .. groupId)

		if KEYSET[groupId] then 
			KEYSET[groupId]:Destroy() 
			KEYSET[groupId] = nil 
		end

		ROUNDWINDOW.INPUT:SetBind({keycode="blank", alt=false}, false)
		GroupKeybinds[groupId] = nil

		Component.SaveSetting("GroupKeybinds", GroupKeybinds)
	end

	ROUNDWINDOW.KEYCATCHER = nil

	Component.RemoveWidget(args.widget)
end 

function SlotGroup(group)
	local group = tostring(group)

	if not GroupInfo[group].groupType then
		GroupInfo[group].groupType = "smartSlot"
		Component.SaveSetting("GroupInfo", GroupInfo)
	end

	if cycleFromFirst then
		if previousGroup ~= group then
			GroupInfo[group].lastCDindex = 0
			previousGroup = group
		end
	end

	if GroupInfo[group].groupType == "smartSlot" then
		local OnCooldown = {}
		local OffCooldown = {}

		for iterator,data in lnodes(LISTDATA[group]) do
			if data and tonumber(Player.GetItemCount(data.calldownId)) >= 1 then
				if Player.GetAbilityState(data.abilityId).requirements.remainingCooldown then
					table.insert(OnCooldown, {calldownId=data.calldownId, cooldown=Player.GetAbilityState(data.abilityId).requirements.remainingCooldown})
				else
					table.insert(OffCooldown, {calldownId=data.calldownId})
				end
			end
		end

		if #OffCooldown == 0 and #OnCooldown == 0 then
			RedBand.ErrorMessage("No calldowns to slot.")
		end

		if #OffCooldown >= 1 then
			Player.SlotTech(OffCooldown[1].calldownId, OffCooldown[1].calldownId, GroupInfo[group].groupIndex)

			out("Loaded "..GetNameByID(OffCooldown[1].calldownId).." from " .. group)
		elseif #OnCooldown >= 1 then
			table.sort(OnCooldown, function(a,b) return a.cooldown<b.cooldown end)
			Player.SlotTech(OnCooldown[1].calldownId, OnCooldown[1].calldownId, GroupInfo[group].groupIndex)

			out("Loaded "..GetNameByID(OnCooldown[1].calldownId).." from " .. group)
		end
	elseif GroupInfo[group].groupType == "cycleSlot" then
		local localcalldowns = {}

		for iterator,data in lnodes(LISTDATA[group]) do
			if data and tonumber(Player.GetItemCount(data.calldownId)) >= 1 then
				table.insert(localcalldowns, {calldownId=data.calldownId})
			end
		end

		if #localcalldowns == 0 then
			RedBand.ErrorMessage("No calldowns to slot.")
			return nil
		end

		local lastCDindex = GroupInfo[group].lastCDindex or 0

		if lastCDindex >= #localcalldowns then
			lastCDindex = 1
		else
			lastCDindex = lastCDindex + 1
		end

		GroupInfo[group].lastCDindex = lastCDindex

		Player.SlotTech(localcalldowns[lastCDindex].calldownId, localcalldowns[lastCDindex].calldownId, GroupInfo[group].groupIndex)
		out("Loaded "..GetNameByID(localcalldowns[lastCDindex].calldownId) .." from " .. group)	

		Component.SaveSetting("GroupInfo", GroupInfo)
	elseif GroupInfo[group].groupType == "setSlot" then
		local localcalldowns = {}
		local setSize = 4

		for iterator,data in lnodes(LISTDATA[group]) do
			if data and tonumber(Player.GetItemCount(data.calldownId)) >= 1 then
				table.insert(localcalldowns, {calldownId=data.calldownId})
			end
		end

		if #localcalldowns == 0 then
			RedBand.ErrorMessage("No calldowns to slot.")
			return nil
		elseif #localcalldowns < 4 then
			setSize = #localcalldowns
		end
		
		local notice = "Loaded set " .. group .. ":"
		
		for i = 1, setSize do
			Player.SlotTech(localcalldowns[i].calldownId, localcalldowns[i].calldownId, i)
			notice = notice .. " [" .. GetNameByID(localcalldowns[i].calldownId) .. "]"
		end
		
		out(notice)
	end
end

function UpdateList()
	groupId = 0

	if not GroupList then
		GroupButton = Button.Create(Component.GetWidget("Group"))
		GroupButton:SetDims("height:22; width:48%; center-x:25%; center-y:-3%")

		GroupButton:SetText("Make a group")

		GroupButton:Bind(MakeGroup)

		GroupList = DropDownList.Create(Component.GetWidget("Group"))
		GroupList:SetDims("height:22; width:48%; center-x:75%; center-y:-3%")

		GroupList:BindOnSelect(HandleGroup)
	end

	GroupList:ClearItems()

	for idx in pairs(LISTS) do
		groupId = groupId + 1

		GroupList:AddItem(idx, idx)
	end
end

function MakeGroup(indexId, doNotGroupInfo)
	if (not groupId or groupId == 0) and (not GROUPLIST) then GROUPLIST = NestedList.Create(Component.GetWidget("Group")) end

	local groupId = indexId or GetId()

	-- Create the list.

	local ENTRY = {}
	ENTRY.GROUP = Component.CreateWidget('<Group dimensions="top:0; width:100%; height:38"/>', INVISIBLE_GROUP)

	-- Backplate
	ENTRY.PLATE = HoloPlate.Create(ENTRY.GROUP)
	ENTRY.PLATE:SetColor("#85555555")

	-- Label
	ENTRY.TEXT = Component.CreateWidget('<Text key="{' .. groupId .. '}" dimensions="center-x:51%; center-y:50%; width:100%; height:100%" style="font:UbuntuMedium_11; halign:left; valign:center; eatsmice:false"/>', ENTRY.GROUP)
	ENTRY.TEXT:SetTag(groupId)

	ENTRY.NESTER = GROUPLIST:CreateItem(ENTRY.GROUP)

	LISTS[groupId] = ENTRY

	-- Make an entry

	if not GroupList then
		GroupButton = Button.Create(Component.GetWidget("Group"))
		GroupButton:SetDims("height:22; width:48%; center-x:25%; center-y:-3%")

		GroupButton:SetText("Make a group")
		GroupButton:Bind(MakeGroup)

		GroupList = DropDownList.Create(Component.GetWidget("Group"))
		GroupList:SetDims("height:22; width:48%; center-x:75%; center-y:-3%")

		GroupList:BindOnSelect(HandleGroup)
	end

	GroupList:AddItem(groupId, groupId)

	-- Init Group Info

	if not doNotGroupInfo then
		GroupInfo[groupId] = {}
		GroupInfo[groupId].lastCDindex = 1
		GroupInfo[groupId].groupIndex = 1
		GroupInfo[groupId].groupType = "smartSlot"

		Component.SaveSetting("GroupInfo", GroupInfo)
	end

	-- Make the collision focus and bind the events.

	Collisions[groupId] = Component.CreateWidget('<FocusBox id="collision" dimensions="dock:fill"/>', LISTS[groupId].NESTER:GetWidget())
	Collisions[groupId]:BindEvent("OnMouseEnter", function() FocusedFocus = ENTRY end)
	Collisions[groupId]:BindEvent("OnMouseLeave", function() FocusedFocus = nil end)

	return LISTS[groupId]
end

function GetId()
	for i = 1,10000 do
		if not LISTS["List " .. i] then 
			return "List " .. i
		end
	end
end

function EndDrop(args)
	if args.done then

		function explode(d,p) -- Taken from lua example site. PHP-like explode.
 			local t, ll
  			t = {}
  			ll = 0
  			if (#p == 1) then return {p} end
    		while true do
      			l = string.find(p, d, ll, true) -- why you nil?
      			if l ~= nil then
        			table.insert(t, string.sub(p, ll, l-1))
        			ll = l+1
      			else
        			table.insert(t, string.sub(p, ll))
        			break
      			end
    		end
  			return t
		end

		if timeCall then cancel_callback(timeCall) timeCall = nil end

		if FocusedFocus and Component.IsWidget(FocusedFocus.TEXT) and cursorIcon then
			local explodeData = explode("-", cursorIcon:GetTag())

			local calldownId = explodeData[1]
			local abilityId = explodeData[2]
			local groupId = FocusedFocus.TEXT:GetTag()

			CreateEntry(FocusedFocus.NESTER, calldownId, abilityId, groupId)
		end

		if Component.IsWidget(cursorIcon) then Component.RemoveWidget(cursorIcon) end

		cursorIcon = nil
		FocusedFocus = nil
	end
end

function CreateEntry(list, calldownId, abilityId, groupId) 
	if not LISTDATA[groupId] then LISTDATA[groupId] = CalldownGroup:new() end 

	local LIST = LISTDATA[groupId]

	-- Creating the visual entry --

	local ENTRY = {}
	ENTRY.GROUP = Component.CreateWidget('<Group dimensions="top:0; width:95%; height:32"/>', INVISIBLE_GROUP)

	-- Backplate
	ENTRY.PLATE = HoloPlate.Create(ENTRY.GROUP)
	ENTRY.PLATE:SetColor("4f4f4f")

	-- Label
	ENTRY.TEXT = Component.CreateWidget('<Text key="{' .. Game.GetItemInfoByType(calldownId).name:gsub('%"', '&quot;') .. '}" dimensions="center-x:51%; center-y:50%; width:100%; height:100%" style="font:UbuntuMedium_11; halign:left; valign:center; eatsmice:false"/>', ENTRY.GROUP)

	ENTRY.NESTER = list:CreateItem(ENTRY.GROUP)

	-- Insert our calldown into the group's table and keep track of it --
			
	LISTDATA[groupId]:pushFront({abilityId=abilityId, calldownId=calldownId})
	local calldownIndex = LISTDATA[groupId].tail

	calldownIndex.data.visuals = ENTRY.NESTER

	UpdateGroup(groupId)
			
	-- Button Madness --

	function BindButton(button)
		if button and button.GROUP then
			button.GROUP:BindEvent("OnMouseEnter", function()
				button.BUTTON.INNER:ParamTo("exposure", -0.1, 0.15*.5, 0, "smooth");
				button.BUTTON.OUTER:ParamTo("exposure", 0.5, 0.15*.5, 0, "smooth");
			end)
			button.GROUP:BindEvent("OnMouseLeave", function() 
				button.BUTTON.INNER:QueueParam("exposure", -0.3, 0.15*.5, 0, "smooth");
				button.BUTTON.OUTER:QueueParam("exposure", 0.1, 0.15*.5, 0, "smooth");
			end)
		end
	end

		-- Destroy button

	local DESTROY = {}
	DESTROY.GROUP = Component.CreateWidget(ButtonPrint, ENTRY.NESTER:GetWidget())

	DESTROY.BUTTON = HoloPlate.Create(DESTROY.GROUP)
	DESTROY.LABEL = Component.CreateWidget('<StillArt name="blah" dimensions="dock:fill" style="texture:CheckBox_White; region:x; tint:FF0000"/>', DESTROY.GROUP)

	DESTROY.BUTTON.INNER:SetParam("alpha", 0)
	DESTROY.BUTTON:SetColor("#85555555")

	DESTROY.GROUP:SetDims("center-x:93.5%;")

	BindButton(DESTROY)
	DESTROY.GROUP:BindEvent("OnMouseDown", function() LIST:handleRemove(calldownIndex) UpdateGroup(groupId) end)

		-- Up Button

	local UP = {}
	UP.GROUP = Component.CreateWidget(ButtonPrint, ENTRY.NESTER:GetWidget())

	UP.BUTTON = HoloPlate.Create(UP.GROUP)
	UP.LABEL = Component.CreateWidget('<StillArt name="blah" dimensions="dock:fill" style="texture:chevrons; region:up"/>', UP.GROUP)

	UP.BUTTON.INNER:SetParam("alpha", 0)
	UP.BUTTON:SetColor("#85555555")

	UP.GROUP:SetDims("center-x:76.5%;")

	BindButton(UP)
	UP.GROUP:BindEvent("OnMouseDown", function()
		LIST:handleUp(calldownIndex)

		UpdateGroup(groupId)
	end)

		-- Down Button

	local DOWN = {}
	DOWN.GROUP = Component.CreateWidget(ButtonPrint, ENTRY.NESTER:GetWidget())

	DOWN.BUTTON = HoloPlate.Create(DOWN.GROUP)
	DOWN.LABEL = Component.CreateWidget('<StillArt name="blah" dimensions="dock:fill" style="texture:chevrons; region:down"/>', DOWN.GROUP)

	DOWN.BUTTON.INNER:SetParam("alpha", 0)
	DOWN.BUTTON:SetColor("#85555555")

	DOWN.GROUP:SetDims("center-x:85%;")

	BindButton(DOWN)
	DOWN.GROUP:BindEvent("OnMouseDown", function()
		LIST:handleDown(calldownIndex)

		UpdateGroup(groupId)
	end)

	-- End of Button Madness --
end

function UpdateGroup(id)
	
	local id = tostring(id)

	GroupData[id] = {}

	for iterator,data in lnodes(LISTDATA[id]) do
		table.insert(GroupData[id], {abilityId=data.abilityId, calldownId=data.calldownId})
	end

	if #GroupData[id] == 0 then
		GroupData[id] = nil
	end

	Component.SaveSetting("GroupData", GroupData)
end

function DestroyGroup(group)
	for iterator,data in lnodes(group) do
		iterator:remove()
	end
end

function FindIndex(group, calldown)
	local nIndex = 0

	for iterator,data in lnodes(group) do
		if data then
			nIndex = nIndex + 1
			if data == calldown then return nIndex end
		end
	end
end

function Remove(groupId, abilityId)
	for idx,ENTRY in pairs(LISTDATA[groupId]) do
		if ENTRY.abilityId == abilityId then table.remove(LISTDATA[groupId], idx) end
	end
end

function CreateIcon(calldownId, abilityId)
	timeCall = nil

	cursorIcon = Component.CreateWidget('<WebImage dimensions="relativecursor; height:32; width:32" style="fixed-bounds:true; eatsmice:false"/>', CALLDOWNLIST)

	cursorIcon:SetTag(tostring(calldownId) .. "-" .. abilityId)
	cursorIcon:SetUrl(Game.GetItemInfoByType(calldownId).web_icon)
end

function CanFind(id)
	for _,CALLDOWN in pairs(calldownGroup) do
		if CALLDOWN.id == id then return true end
	end

	return false
end

function Sort(sortMethod, override)
	toFocus = nil

	for _,LIST in pairs(CAT) do
		LIST.NESTER:Clear()
	end

	if SORTINPUT then SORTINPUT:Destroy() end

	if sortMethod == "Name" or sortMethod == "ReverseName" then
		TextName:SetTextColor(FOCUS_COLOR)
		TextQuantity:SetTextColor("FFFFFF")

		toFocus = FocusName
	elseif sortMethod == "Quantity" or sortMethod == "ReverseQuantity" then
		TextName:SetTextColor("FFFFFF")
		TextQuantity:SetTextColor(FOCUS_COLOR)

		toFocus = FocusQuantity
	end

	if not override then
		if not sortType or string.find(sortType, "Reverse") then
			sortType = sortMethod
		else
			sortType = "Reverse" .. sortMethod
		end
	end

	local direction = 40

	if sortType then	
		if string.find(sortType, "Reverse") then 
			direction = 38
		end
	end

	SORTINPUT = InputIcon.CreateVisual(toFocus, sortType)
	SORTINPUT:SetDims("height:22; center-x:80%; center-y:60%; width:22")
	SORTINPUT:SetBind({keycode=direction, alt=false}, false)

	local cleanTable = {}
	local checkTable = {}

	for CATEGORY,_ in pairs(CategoryList) do cleanTable[CATEGORY] = {} end

	local sortTable = Player.GetConsumableItems()
	for _,INDEX in pairs(sortTable) do if not checkTable[tostring(INDEX.itemTypeId)] then table.insert(cleanTable[Game.GetItemInfoByType(INDEX.itemTypeId).uiCategory], INDEX) checkTable[tostring(INDEX.itemTypeId)] = true end end

	for _,CATEGORY in pairs(cleanTable) do table.sort(CATEGORY, SortFunc[sortType]) end

	for CATEGORY,NESTERS in pairs(cleanTable) do
		for idx,CALLDOWN in pairs(NESTERS) do
			MakeCalldownEntry(CALLDOWN.itemTypeId, ENTRY[tostring(CALLDOWN.itemTypeId)].abilityId)
		end
	end
end

function GetAllFoundCategories()
	local catTable = {}
	for _,CALLDOWN in pairs(Player.GetConsumableItems()) do
		local categoryType = Game.GetItemInfoByType(CALLDOWN.itemTypeId).uiCategory
		if not catTable[categoryType] then catTable[categoryType] = true end
	end

	return catTable
end

function ToggleIt()
	if enabled then
		if not CALLDOWNLIST:IsVisible() then DetailMode() end
		ToggleCursor(not(CALLDOWNLIST:IsVisible()))
		CALLDOWNLIST:Show(not(CALLDOWNLIST:IsVisible()))

		System.BlurMainScene(CALLDOWNLIST:IsVisible())
		Component.GenerateEvent("MY_HIDE_HUD_REQUEST", {reason="web", hide=CALLDOWNLIST:IsVisible()});
	end
end

function ToggleCursor(bool)
	if bool then
		Component.SetInputMode("cursor")
	else
		Component.SetInputMode(nil)
	end
end

function OnEntryDown(calldownId)
	if not POP then
		POP = {}
		POP.WINDOW = Component.CreateWidget('<Border name="Popup" dimensions="height:15%; width:25%; center-x:50%; center-y:50%" class="SolidBackDrop"/>', CALLDOWNLIST)
		POP.TITLE = Component.CreateWidget('<Text dimensions="center-x:50%; center-y:45%; width:100%; height:100%" style="font:Demi_10; halign:center; valign:center; eatsmice:false" />', CALLDOWNLIST)
		if not idDisplay then
			POP.TITLE:SetText(Game.GetItemInfoByType(calldownId).name:gsub('%"', '&quot;'))
		else
			POP.TITLE:SetText(calldownId)
		end
		POPWIDGETS = Component.CreateWidget("PopText", CALLDOWNLIST)
		POP.TEXT = POPWIDGETS:GetChild("PopupText")
		POP.IMAGE = POPWIDGETS:GetChild("PopupImage")
		POP.IMAGE:SetDims("center-x:50%; center-y:52.5%")
		POP.IMAGE:SetUrl(Game.GetItemInfoByType(calldownId).web_icon)
		local binding = FindBind(calldownId)
		if binding then
			POP.TEXT:SetText("This calldown is bound to:")
			POP.TEXT:SetDims("right:95%; center-y:47.5%")
			POP.INPUT = InputIcon.CreateVisual(CALLDOWNLIST)
			POP.INPUT:SetDims("height:22; right:57%; width:22; top:46.25%")
			POP.INPUT:SetBind({keycode=binding, alt=false}, false)
		else
			POP.TEXT:SetText("This calldown is not currently bound")
			POP.TEXT:SetDims("center-x:50%; center-y:47.5%")
		end

		KEYCATCHER = Component.CreateWidget("KeyCatcher", CALLDOWNLIST):GetChild("KeyCatch")
		KEYCATCHER:ListenForKey()
		KEYCATCHER:SetTag(tostring(calldownId))
	end
end

function FindBind(calldownId)
	for k in pairs(Keybinds) do
		if tostring(calldownId) == tostring(k) then
			return Keybinds[k]
		end
	end
	return nil
end

function OnKeyPress(args)
	local keyCode = args.widget:GetKeyCode()
	Debug.Log("Pressed key: " .. keyCode)
	local calldownId = args.widget:GetTag()
	BindKey(keyCode, calldownId)
	if POP then 
		Component.RemoveWidget(POPWIDGETS) 
		POPWIDGETS = nil 

		if POP.INPUT then
			POP.INPUT:Destroy()
		end

		for _,widget in pairs(POP) do 
			if Component.IsWidget(widget) then
				Component.RemoveWidget(widget) 
			end
			widget = nil 
		end

		POP = nil 
	end
	if KEYCATCHER then
		Component.RemoveWidget(KEYCATCHER)
		KEYCATCHER = nil
	end
end

function BindKey(keyCode, calldownId)
	local calldownId = tostring(calldownId)
	if tostring(keyCode) == "27" or (keyCode and calldownId) and (CanBind(keyCode)) then
		local keyName = Game.GetItemInfoByType(calldownId).name:gsub('%"', '&quot;')
		if tostring(keyCode) == "27" then
			if KEYSET[calldownId] then
				KEYSET[calldownId]:Destroy()
				KEYSET[calldownId] = nil
			end
			if DATA[calldownId].INPUT then DATA[calldownId].INPUT:Destroy() DATA[calldownId].INPUT = nil end
			Keybinds[calldownId] = nil
			Component.SaveSetting("Keybinds", Keybinds)
			DumpKeys()
			return nil
		end
		local keyName = Game.GetItemInfoByType(calldownId).name:gsub('%"', '&quot;')
		if DATA and ENTRY then
			if KEYSET[calldownId] then KEYSET[calldownId]:UnregisterAction(tostring(calldownId)) end
			if DATA[calldownId].INPUT then DATA[calldownId].INPUT:Destroy() DATA[calldownId].INPUT = nil end
			DATA[calldownId].INPUT = InputIcon.CreateVisual(ENTRY[calldownId].NESTER:GetWidget(), keyName)
			DATA[calldownId].INPUT:SetDims("height:22; center-x:3%; center-y:50%; width:22;")
			DATA[calldownId].INPUT:SetBind({keycode=keyCode, alt=false}, false)
		end
		KEYSET[calldownId] = UserKeybinds.Create()
		BindFunctions[keyName] = function(calldownId) Slot(calldownId) end
		KEYSET[calldownId]:RegisterAction(tostring(calldownId), BindFunctions[keyName])
		KEYSET[calldownId]:BindKey(tostring(calldownId), keyCode)
		Keybinds[calldownId] = keyCode
		DumpKeys()
		Component.SaveSetting("Keybinds", Keybinds)
	end
end

function DumpKeys()
	local keyTable = {}
	for k,v in pairs(Keybinds) do
		table.insert(keyTable, {itemid=k, keycode=v})
	end
	Component.GenerateEvent("MY_USER_CALLDOWNHOTKEYS", {keys=tostring(keyTable)})
end

function CanBind(keyCode)
	if restrictBinds then
		local restrictedKeys = GetAllBindings()
		for k in pairs(restrictedKeys) do
			if tostring(keyCode) == tostring(restrictedKeys[k]) then
				Debug.Warn("You cannot bind: " .. System.GetKeycodeString(keyCode) .. ", conflict: " .. k)
				RedBand.ErrorMessage("You cannot bind: " .. System.GetKeycodeString(keyCode) .. ", conflict: " .. k)
				return false
			end
		end
		return true
	end

	local boolCheck = true

	if tonumber(keyCode) == 256 or tonumber(keyCode) == 257 then
		boolCheck = false
	end

	if not boolCheck then
		RedBand.ErrorMessage("LMB and RMB cannot be bound to.")
	end

	return boolCheck	
end

function GetAllBindings()
	local keyTable = {}

	for _,STRING in pairs(stringTable) do
		local useTable = System.GetKeyBindings(STRING, false)
		for k in pairs(useTable) do for v in pairs(useTable[k]) do if useTable[k][v].keycode ~= 0 then keyTable[k .. " index:" .. v] = useTable[k][v].keycode end end end
	end

	for k in pairs(KEYSET) do 
		if Game.GetItemInfoByType(k) then
			useIndex = Game.GetItemInfoByType(k).name 
		else 
			useIndex = k
		end 

		keyTable[useIndex] = KEYSET[k]:ExportKeybinds()[k][1] 
	end

	keyTable["Escape"] = 27
	keyTable["PrintScrn"] = 44

	return keyTable
end

function GetSlottedCalldownID()
	if Player.GetAbilities().action1 then
		return Player.GetAbilities().action1.itemTypeId;
	else
		return nil -- What went wrong?
	end
end

function GetNameByID(id)
	local info = Game.GetItemInfoByType(tonumber(id));

	return info.name or ""
end

function out(msg, ignoreSetting)
	if (io_EnabledAlerts or ignoreSetting) then
		Component.GenerateEvent("MY_SYSTEM_MESSAGE", {text=tostring(msg)});
	end
end