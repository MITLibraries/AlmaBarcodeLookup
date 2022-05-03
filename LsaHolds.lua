require "Atlas.AtlasHelpers"
local rootLogger = "AtlasSystems.Addons.AlmaBarcodeLookupAddon"

luanet.load_assembly("System.Windows.Forms")  -- For cursor manipulation
luanet.load_assembly("log4net")
luanet.load_assembly("System.Xml")

-- Load the .Net types that we will be using.
local types = {};
types["System.Windows.Forms.Cursor"] = luanet.import_type("System.Windows.Forms.Cursor")
types["System.Windows.Forms.Cursors"] = luanet.import_type("System.Windows.Forms.Cursors")
types["System.Windows.Forms.Application"] = luanet.import_type("System.Windows.Forms.Application")
types["log4net.LogManager"] = luanet.import_type("log4net.LogManager")
local log = types["log4net.LogManager"].GetLogger(rootLogger)
log:Debug("Finished creating types")

-- Load settings
local settings = {}
settings.LookupType = GetSetting("Look Up Type")
settings.AlmaApiUrl = GetSetting("Alma API URL")
settings.AlmaApiKey = GetSetting("Alma API Key")
settings.AllowOverwriteWithBlankValue = GetSetting("Allow Overwrite With Blank Value")
settings.FieldsToImport = Utility.StringSplit(",", GetSetting("Fields to Import"))
settings.FieldToPerformLookupWith = GetSetting("Field to Perform Lookup With")
settings.UserForLSAHoldRequest = GetSetting("User Primary ID")
settings.pickup_location = GetSetting("location code")
settings.office_delivery = GetSetting("office delivery")
settings.barcodeField = Utility.StringSplit(".", GetSetting("barcode field"))
settings.mmsIdField = Utility.StringSplit(".", GetSetting("mms id field"))

-- We will store the interface manager object here so that we don't have to make multiple GetInterfaceManager calls.
local interfaceMngr = nil
log:Debug("Created Interface Manager")

local product = types["System.Windows.Forms.Application"].ProductName

function Init()
  log:Debug("Starting")
  interfaceMngr = GetInterfaceManager()
  log:Debug("Got Interface Manager")

  -- Retrieve Ribbon Page and Add Buttons.
  local ribbonPage = interfaceMngr:CreateRibbonPage("MIT LSA Holds")
  log:Debug("Created Ribbon Page")

  ribbonPage:CreateButton("Import by Barcode", GetClientImage(DataMapping.ClientImage[product]), "ImportItem", "Options")
  ribbonPage:CreateButton("Place LSA Hold", GetClientImage(DataMapping.ClientImage[product]), "PlaceLSAHold", "Options")

  log:Debug("Created Buttons")

  -- Find the field to perform lookup with
  if settings.FieldToPerformLookupWith:lower() == "{default}" then
    settings.FieldToPerformLookupWith = Utility.StringSplit(".", DataMapping.BarcodeFieldMapping[product])
    settings.FieldToPerformLookupWith[1] = Utility.Trim(settings.FieldToPerformLookupWith[1])
    settings.FieldToPerformLookupWith[2] = Utility.Trim(settings.FieldToPerformLookupWith[2])
    log:InfoFormat("Field to Perform Lookup With is {0}.{1}", settings.FieldToPerformLookupWith[1], settings.FieldToPerformLookupWith[2])
  else
    log:Warn("Invalid Field to Perform Lookup With")
  end

  InitializeVariables()

end

function InitializeVariables()
  log:Debug("Initializing Variables")
  AlmaLookup.InitializeVariables(settings.AlmaApiUrl, settings.AlmaApiKey, settings.AllowOverwriteWithBlankValue, settings.FieldsToImport)
  log:Debug("Finished Initializing Variables")
end

function ImportItem()
  -- Set the mouse cursor to busy.
  types["System.Windows.Forms.Cursor"].Current = types["System.Windows.Forms.Cursors"].WaitCursor;
  log:Debug("Importing Item...")
  local lookupResult = DoBarcodeLookup()
  log:Debug("DoLookup Complete")

  if(lookupResult ~= nil) then
    for _, result in ipairs(lookupResult) do
      log:InfoFormat("Importing {0} into {1}.{2}", result.valueToImport, result.valueDestination[1], result.valueDestination[2])
      SetFieldValue(result.valueDestination[1], result.valueDestination[2], result.valueToImport)
    end
  else
    interfaceMngr:ShowMessage("No item found.", "Item Not found")
  end
  -- Set the mouse cursor back to default.
  types["System.Windows.Forms.Cursor"].Current = types["System.Windows.Forms.Cursors"].Default;
end

function DoBarcodeLookup()
  if GetField(settings.FieldToPerformLookupWith[1],
  settings.FieldToPerformLookupWith[2]) then
    local barcode = GetField(settings.FieldToPerformLookupWith[1],
    settings.FieldToPerformLookupWith[2])
    local lookupResult = AlmaLookup.DoLookup(barcode)
    return lookupResult
  else
    return nil
  end
end


function GetField(fieldTable, field)
    local result = GetFieldValue(fieldTable, field)
    if result ~= nil and #result > 0 then
    return result
  else
    return nil
  end

end

function GetItemPID(barcode)
  log:InfoFormat("getting item ID for barcode: {0}", barcode)
  local succeeded, response = pcall(AlmaApi.RetrieveItemByBarcode, barcode)
  if succeeded then
    --get Item PID from XML response
    local mms_id = response:GetElementsByTagName("mms_id"):Item(0).InnerText
    local holding_id = response:GetElementsByTagName("holding_id"):Item(0).InnerText
    local item_id = response:GetElementsByTagName("pid"):Item(0).InnerText
    log:InfoFormat("item_id: {0}", item_id)
    return mms_id, holding_id, item_id
  else
      log:Error("Error Getting item PID")
  end

end

function PlaceLSAHold()
  -- Set the mouse cursor to busy.
  types["System.Windows.Forms.Cursor"].Current = types["System.Windows.Forms.Cursors"].WaitCursor

    -- We need a barcode or MMS ID to place a hold. 
    if GetField(settings.barcodeField[1], settings.barcodeField[2]) then
      local barcode = GetField(settings.barcodeField[1], settings.barcodeField[2])
      PlaceItemLevelHold(barcode)
    elseif GetField(settings.mmsIdField[1], settings.mmsIdField[2]) then
      local mmsId = GetField(settings.mmsIdField[1], settings.mmsIdField[2])
      PlaceTitleLevelHold(mmsId)
    else 
      interfaceMngr:ShowMessage("Either a barcode or MMS ID is required to place hold", "Error")
    end
  -- Set the mouse cursor back to default.
  types["System.Windows.Forms.Cursor"].Current = types["System.Windows.Forms.Cursors"].Default
end

function PlaceItemLevelHold(barcode)
  -- use the barcode to get IDs required for placing item level hold
   local mms_id, holding_id, item_id = GetItemPID(barcode)

  --Place item-level hold in Alma
  local success, response = pcall(
        AlmaApi.PlaceHoldByItemPID,
        mms_id, holding_id, item_id,
        settings.UserForLSAHoldRequest,
        settings.pickup_location, settings.office_delivery
      )
  if success then
    log:Info("hold placed successfully")
  else
    log:Info("hold attempt failed")
  end
end

function PlaceTitleLevelHold(mms_id)

  --Place title-level hold in Alma
  local success, response = pcall(
        AlmaApi.PlaceHoldByMmsId,
        mms_id,
        settings.UserForLSAHoldRequest,
        settings.pickup_location, settings.office_delivery
      )
  if success then
    log:Info("hold placed successfully")
  else
    log:Info("hold attempt failed")
  end
end