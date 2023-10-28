local function checkInjuries(data)
    local injuries = {}

    utils.debug(data.injuries)

    if not data.injuries or not next(data.injuries) then
        injuries[#injuries + 1] = {
            title = 'No injuries',
        }
    else
        for _, v in pairs(data.injuries) do
            injuries[#injuries + 1] = {
                title = v.label,
                description = v.desc,

                arrow = true,
                onSelect = function()
                    lib.registerContext({
                        id = 'patient_injury' .. _,
                        title = v.label,
                        menu = "patient_injuries",
                        options = {
                            {
                                title = locale("injury_value"),
                                progress = v.value,
                                metadata = { v.value .. "%" },
                            },
                            {
                                title = locale("injury_treat"),
                                onSelect = function()
                                    local dataToSend = {}
                                    dataToSend.targetServerId = data.target
                                    dataToSend.injury = true
                                    dataToSend.bone = v.bone
                                    TriggerServerEvent("ars_ambulancejob:healPlayer", dataToSend)

                                    utils.debug("Injury treated " .. dataToSend.bone)
                                end

                            }
                        }
                    })

                    lib.showContext('patient_injury' .. _)
                end
            }
        end
    end

    lib.registerContext({
        id = 'patient_injuries',
        title = locale("menu_title"),
        menu = "check_patient",
        options = injuries
    })

    lib.showContext('patient_injuries')
end

local function checkPatient(target)
    local targetServerId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(target))
    local data = lib.callback.await('ars_ambulancejob:getData', false, targetServerId)
    local isDead = data.status.isDead
    local status = isDead and locale("patient_not_conscious") or locale("patient_conscious")

    utils.debug(data)

    lib.progressBar({
        duration = 3000,
        label = locale("checking_patient"),
        useWhileDead = false,
        canCancel = false,
        disable = {
            car = true,
        },
    })

    local options = {
        {
            title = locale("status_patient: ") .. status,
            icon = 'heartbeat',
            iconColor = isDead and "#b5300b" or "#5b87b0",
            readOnly = true,
        },

        {
            title = locale("check_injuries"),
            description = 'check if the patient has any fractures',
            icon = 'user-injured',
            onSelect = function()
                local passData = {}
                passData.target = targetServerId
                passData.injuries = data.injuries

                checkInjuries(passData)
            end,
        }
    }

    if isDead then
        options[#options + 1] = {
            title = locale("revive_patient"),
            description = 'check if the patient has any fractures',
            icon = 'medkit',
            iconColor = "#5BC0DE",
            onSelect = function()
                local playerPed = cache.ped or PlayerPedId()
                local playerHeading = GetEntityHeading(playerPed)
                local playerLocation = GetEntityForwardVector(playerPed)
                local playerCoords = GetEntityCoords(playerPed)


                local dataToSend = {}
                dataToSend.targetServerId = targetServerId
                dataToSend.injury = false
                dataToSend.heading = playerHeading
                dataToSend.location = playerLocation
                dataToSend.coords = playerCoords
                TriggerServerEvent("ars_ambulancejob:healPlayer", dataToSend)
            end,
        }

        options[#options + 1] = {
            title = WEAPONS[data.killedBy] or "Not found",
            readOnly = true,
            icon = 'skull',

        }
    end


    lib.registerContext({
        id = 'check_patient',
        title = locale("menu_title"),
        options = options
    })
    lib.showContext('check_patient')
end


function createDistressCall()
    if player.distressCallTime then
        local currentTime = GetGameTimer()
        utils.debug(currentTime - player.distressCallTime, 60000 * Config.WaitTimeForNewCall)
        if currentTime - player.distressCallTime < 60000 * Config.WaitTimeForNewCall then return utils.showNotification("Wait before sending another call") end
    end

    local input = lib.inputDialog('Arius Ambulance', {
        { type = 'input', label = 'Message', description = 'a message to send to medics online', required = true },
    })
    if not input then return end

    local msg = input[1]

    if not Config.UseInterDistressSystem then
        Config.SendDistressCall(msg)
    else
        local data = {}
        local playerCoords = cache.coords or GetEntityCoords(cache.ped)

        local current, crossing = GetStreetNameAtCoord(playerCoords.x, playerCoords.y, playerCoords.z)

        data.msg = msg
        data.gps = playerCoords
        data.location = GetStreetNameFromHashKey(current)

        TriggerServerEvent("ars_ambulancejob:createDistressCall", data)
    end


    player.distressCallTime = GetGameTimer()
end

exports("createDistressCall", createDistressCall)

function openDistressCalls()
    if not hasJob(Config.EmsJobs) then return end

    local distressCalls = lib.callback.await('ars_ambulancejob:getDistressCalls', false)

    local calls = {}

    for i = 1, #distressCalls do
        local call = distressCalls[i]

        utils.debug(call)

        calls[#calls + 1] = {
            title       = call.name,
            description = call.msg,
            icon        = "fa-truck-medical",
            iconColor   = "#FEBD69",
            arrow       = true,
            onSelect    = function()
                lib.registerContext({
                    id      = 'openCall' .. call.name .. call.msg .. i,
                    title   = call.name,
                    menu    = "openDistressCalls",
                    options = {
                        {
                            title       = call.msg,
                            icon        = "fa-info-circle",
                            iconColor   = "#0077FF",
                            readOnly    = true,
                            description = "message sent from the patient"
                        },
                        {
                            title       = call.location,
                            icon        = "fa-map-marker",
                            iconColor   = "#00CC00",
                            readOnly    = true,
                            description = "Location of the patient"
                        },
                        {
                            title       = "Set Waypoint",
                            icon        = "fa-map-pin",
                            iconColor   = "#FFA500",
                            arrow       = true,
                            description = "Set the waypoint to the patient direction",

                            onSelect    = function()
                                SetNewWaypoint(call.gps.x, call.gps.y)
                                utils.showNotification("Waypoint set")
                            end
                        },
                        {
                            title       = "Risolved",
                            icon        = "fa-check",
                            iconColor   = "#32CD32",
                            arrow       = true,
                            description = "Complete the call if you risolved it",


                            onSelect = function()
                                TriggerServerEvent("ars_ambulancejob:callCompleted", call)
                                utils.showNotification("Call closed")
                            end
                        },
                    }
                })
                lib.showContext('openCall' .. call.name .. call.msg .. i)
            end
        }
    end

    lib.registerContext({
        id      = 'openDistressCalls',
        title   = "Calls",
        options = calls
    })
    lib.showContext('openDistressCalls')
end

exports("openDistressCalls", openDistressCalls)


RegisterCommand("dis", function()
    openDistressCalls()
end)

RegisterCommand("dis2", function()
    createDistressCall()
end)

exports.ox_target:addGlobalPlayer({
    {
        name = 'check_suspect',
        icon = 'fas fa-magnifying-glass',
        label = locale('check_patient'),
        groups = Config.EmsJobs,
        distance = 3,
        onSelect = function(data)
            checkPatient(data.entity)
        end
    }
})


RegisterNetEvent("ars_ambulancejob:playHealAnim", function(data)
    local playerPed = cache.ped or PlayerPedId()
    local coords = GetEntityCoords(playerPed)

    if data.anim == "medic" then
        utils.showNotification("Reviving player")

        CreateThread(function()
            lib.progressBar({
                duration = 14900 + (900 * 15) + 1000,
                label = locale("reviving_patient"),
                useWhileDead = false,
                canCancel = false,
                disable = {
                    car = true,
                    move = true,
                },
            })
        end)

        lib.requestAnimDict("mini@cpr@char_a@cpr_def")
        lib.requestAnimDict("mini@cpr@char_a@cpr_str")

        TaskPlayAnim(playerPed, 'mini@cpr@char_a@cpr_def', 'cpr_intro', 8.0, 8.0, -1, 0, 0, false, false, false)

        Wait(14900)

        for i = 1, 15 do
            Wait(900)
            TaskPlayAnim(playerPed, 'mini@cpr@char_a@cpr_str', 'cpr_pumpchest', 8.0, 8.0, -1, 0, 0, false, false, false)
        end

        Wait(1000)

        TaskPlayAnim(playerPed, Config.DeathAnimations["revive"].dict, Config.DeathAnimations["revive"].clip, 10.0, -10.0, -1, 0, 0, 0, 0, 0)
    elseif data.anim == "dead" then
        utils.showNotification("Getting revived")

        player.gettingRevived = true

        lib.requestAnimDict('mini@cpr@char_b@cpr_str')
        lib.requestAnimDict('mini@cpr@char_b@cpr_def')

        SetEntityVisible(playerPed, false)
        Wait(250)
        SetEntityVisible(playerPed, true)

        SetEntityInvincible(playerPed, false)
        TriggerEvent('playerSpawned', coords.x, coords.y, coords.z)
        SetCurrentPedWeapon(playerPed, GetHashKey('WEAPON_UNARMED'), true)

        local x, y, z = table.unpack(data.coords + data.location)

        SetEntityCoords(playerPed, x, y, z - 0.50)
        SetEntityHeading(playerPed, data.heading - 270.0)

        TaskPlayAnim(playerPed, 'mini@cpr@char_b@cpr_def', 'cpr_intro', 8.0, 8.0, -1, 0, 0, false, false, false)

        Wait(14900)

        TaskPlayAnim(playerPed, 'mini@cpr@char_b@cpr_str', 'cpr_pumpchest', 8.0, 8.0, -1, 0, 0, false, false, false)

        for i = 1, 15 do
            Wait(900)
            TaskPlayAnim(playerPed, 'mini@cpr@char_b@cpr_str', 'cpr_pumpchest', 8.0, 8.0, -1, 0, 0, false, false, false)
        end

        Wait(800)

        player.gettingRevived = false
        stopPlayerDeath()
    end
end)


RegisterNetEvent("ars_ambulancejob:createDistressCall", function(name)
    lib.notify({
        title = "New Distress Call",
        description = ("%s sent a distress call"):format(name),
        position = 'bottom-right',
        duration = 8000,
        style = {
            backgroundColor = '#1C1C1C',
            color = '#C1C2C5',
            borderRadius = '8px',
            ['.description'] = {
                fontSize = '16px',
                color = '#B0B3B8'
            },
        },
        icon = 'fas fa-truck-medical',
        iconColor = '#FEBD69'
    })
    PlaySound(-1, "Event_Start_Text", "GTAO_FM_Events_Soundset")
end)