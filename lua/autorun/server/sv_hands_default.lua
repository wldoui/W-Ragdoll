local HANDS_CLASS = "weapon_hands"

CreateConVar("wyldi_hands_autogive", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED)
CreateConVar("wyldi_hands_autoselect", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED)

WyldiHands.CVarGive = GetConVar("wyldi_hands_autogive")
WyldiHands.CVarSelect = GetConVar("wyldi_hands_autoselect")

util.AddNetworkString("WyldiHands_SetConVar")

net.Receive("WyldiHands_SetConVar", function(_, ply)
    if not ply:IsSuperAdmin() then return end

    local name = net.ReadString()
    local value = net.ReadBool()

    local allowed = {
        wyldi_hands_autogive = true,
        wyldi_hands_autoselect = true
    }

    if not allowed[name] then return end

    RunConsoleCommand(name, value and "1" or "0")
end)

hook.Add("PlayerSpawn", "WyldiHands_GiveDefault", function(ply)
    timer.Simple(0, function()
        if not IsValid(ply) or not ply:Alive() then return end

        if WyldiHands.CVarGive:GetBool() and not ply:HasWeapon(HANDS_CLASS) then
            ply:Give(HANDS_CLASS)
        end

        if WyldiHands.CVarSelect:GetBool() and ply:HasWeapon(HANDS_CLASS) then
            ply:SelectWeapon(HANDS_CLASS)
        end
    end)
end)