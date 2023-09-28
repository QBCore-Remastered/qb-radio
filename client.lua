local radioMenu = false
local onRadio = false
local radioChannel = 0
local radioVolume = 50
local hasRadio = false
local radioProp = nil

--Function
local function connectToRadio(channel)
    radioChannel = channel
    if onRadio then
        exports["pma-voice"]:setRadioChannel(0)
    else
        onRadio = true
        exports["pma-voice"]:setVoiceProperty("radioEnabled", true)
    end
    exports["pma-voice"]:setRadioChannel(channel)
    local subFreq = string.split(tostring(channel), '.')[2]
    if subFreq and subFreq ~= "" then
        exports.qbx_core:Notify(Config.messages['joined_to_radio'] ..channel.. ' MHz', 'success')
    else
        exports.qbx_core:Notify(Config.messages['joined_to_radio'] ..channel.. '.00 MHz', 'success')
    end
end

local function closeEvent()
	TriggerEvent("InteractSound_CL:PlayOnOne","click",0.6)
end

local function leaveradio()
    closeEvent()
    radioChannel = 0
    onRadio = false
    exports["pma-voice"]:setRadioChannel(0)
    exports["pma-voice"]:setVoiceProperty("radioEnabled", false)
    exports.qbx_core:Notify(Config.messages['you_leave'] , 'error')
end

local function toggleRadioAnimation(pState)
    lib.requestAnimDict('cellphone@')
	if pState then
		TriggerEvent("attachItemRadio","radio01")
		TaskPlayAnim(cache.ped, "cellphone@", "cellphone_text_read_base", 2.0, 3.0, -1, 49, 0, 0, 0, 0)
		radioProp = CreateObject(`prop_cs_hand_radio`, 1.0, 1.0, 1.0, 1, 1, 0)
		AttachEntityToEntity(radioProp, cache.ped, GetPedBoneIndex(cache.ped, 57005), 0.14, 0.01, -0.02, 110.0, 120.0, -15.0, 1, 0, 0, 0, 2, 1)
	else
		StopAnimTask(cache.ped, "cellphone@", "cellphone_text_read_base", 1.0)
		ClearPedTasks(cache.ped)
		if radioProp ~= 0 then
			DeleteObject(radioProp)
			radioProp = 0
		end
	end
end

local function toggleRadio(toggle)
    radioMenu = toggle
    SetNuiFocus(radioMenu, radioMenu)
    if radioMenu then
        toggleRadioAnimation(true)
        SendNUIMessage({type = "open"})
    else
        toggleRadioAnimation(false)
        SendNUIMessage({type = "close"})
    end
end

local function isRadioOn()
    return onRadio
end

local function doRadioCheck()
    hasRadio = exports.ox_inventory:Search('count', 'radio') > 0
end

--Exports
exports("IsRadioOn", isRadioOn)

--Events

-- Handles state right when the player selects their character and location.
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    doRadioCheck()
end)

-- Resets state on logout, in case of character change.
RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    hasRadio = false
    leaveradio()
end)

AddEventHandler('ox_inventory:itemCount', function(itemName, totalCount) 
    if itemName ~= 'radio' then return end
    hasRadio = totalCount > 0
end)

-- Handles state if resource is restarted live.
AddEventHandler('onResourceStart', function(resource)
    if GetCurrentResourceName() ~= resource then return end
    doRadioCheck()
end)

RegisterNetEvent('qb-radio:use', function()
    toggleRadio(not radioMenu)
end)

RegisterNetEvent('qb-radio:onRadioDrop', function()
    if radioChannel ~= 0 then
        leaveradio()
    end
end)

-- NUI
RegisterNUICallback('joinRadio', function(data, cb)
    local rchannel = tonumber(data.channel)
    if not rchannel then
        exports.qbx_core:Notify(Config.messages['invalid_radio'] , 'error')
        cb("ok")
        return
    end

    if rchannel > Config.MaxFrequency or rchannel == 0 then
        exports.qbx_core:Notify(Config.messages['invalid_radio'] , 'error')
        cb("ok")
        return
    end

    if rchannel == radioChannel then
        exports.qbx_core:Notify(Config.messages['you_on_radio'] , 'error')
        cb("ok")
        return
    end

    if Config.RestrictedChannels[rchannel] and not Config.RestrictedChannels[rchannel][QBX.PlayerData.job.name] or not QBX.PlayerData.job.onduty then
        exports.qbx_core:Notify(Config.messages['restricted_channel_error'], 'error')
        cb("ok")
        return
    end

    connectToRadio(rchannel)
end)

RegisterNUICallback('leaveRadio', function(_, cb)
    if radioChannel == 0 then
        exports.qbx_core:Notify(Config.messages['not_on_radio'], 'error')
    else
        leaveradio()
    end
    cb("ok")
end)

RegisterNUICallback("volumeUp", function(_, cb)
	if radioVolume <= 95 then
		radioVolume = radioVolume + 5
		exports.qbx_core:Notify(Config.messages["volume_radio"] .. radioVolume, "success")
		exports["pma-voice"]:setRadioVolume(radioVolume)
	else
		exports.qbx_core:Notify(Config.messages["decrease_radio_volume"], "error")
	end
    cb('ok')
end)

RegisterNUICallback("volumeDown", function(_, cb)
	if radioVolume >= 10 then
		radioVolume = radioVolume - 5
		exports.qbx_core:Notify(Config.messages["volume_radio"] .. radioVolume, "success")
		exports["pma-voice"]:setRadioVolume(radioVolume)
	else
		exports.qbx_core:Notify(Config.messages["increase_radio_volume"], "error")
	end
    cb('ok')
end)

RegisterNUICallback("increaseradiochannel", function(_, cb)
    local newChannel = radioChannel + 1
    exports["pma-voice"]:setRadioChannel(newChannel)
    exports.qbx_core:Notify(Config.messages["increase_decrease_radio_channel"] .. newChannel, "success")
    cb("ok")
end)

RegisterNUICallback("decreaseradiochannel", function(_, cb)
    if not onRadio then return end
    local newChannel = radioChannel - 1
    if newChannel >= 1 then
        exports["pma-voice"]:setRadioChannel(newChannel)
        exports.qbx_core:Notify(Config.messages["increase_decrease_radio_channel"] .. newChannel, "success")
        cb("ok")
    end
end)

RegisterNUICallback('poweredOff', function(_, cb)
    leaveradio()
    cb("ok")
end)

RegisterNUICallback('escape', function(_, cb)
    toggleRadio(false)
    cb("ok")
end)

--Main Thread
CreateThread(function()
    while true do
        Wait(1000)
        if LocalPlayer.state.isLoggedIn and onRadio then
            if not hasRadio or QBX.PlayerData.metadata.isdead or QBX.PlayerData.metadata.inlaststand then
                if radioChannel ~= 0 then
                    leaveradio()
                end
            end
        end
    end
end)
