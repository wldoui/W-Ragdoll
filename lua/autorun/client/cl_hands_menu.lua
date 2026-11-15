local function SendCVar(name, value)
    net.Start("WyldiHands_SetConVar")
        net.WriteString(name)
        net.WriteBool(value)
    net.SendToServer()
end

local function AddServerCheckbox(panel, label, cvarName)
    local cb = panel:CheckBox(label)
    local convar = GetConVar(cvarName)

    if not convar then
        print("[WyldiHands] ConVar not found: " .. cvarName)
        return cb
    end

    cb:SetChecked(convar:GetBool())

    cb.OnChange = function(self, val)
        SendCVar(cvarName, val)
    end

    cvars.AddChangeCallback(cvarName, function(_, _, new)
        if IsValid(cb) then
            cb:SetChecked(tobool(new))
        end
    end, "WyldiHands_UI_" .. cvarName)

    return cb
end

hook.Add("PopulateToolMenu", "WyldiHands_Menu", function()
    spawnmenu.AddToolMenuOption(
        "Options",
        "WyldiHands",
        "wyldi_hands",
        "Hands",
        "",
        "",
        function(panel)
            panel:ClearControls()

            panel:Help("Настройки пустых рук (меняет только суперадмин).")

            AddServerCheckbox(panel, "Выдавать руки при спавне", "wyldi_hands_autogive")
            AddServerCheckbox(panel, "Автоматически брать руки в руки", "wyldi_hands_autoselect")

            panel:Help("Если автовыдача выключена, руки можно взять в Q-меню → Weapons → Other.")
        end )
end)