local function SendCVar( name, value )
    net.Start( "WyldiHands_SetConVar" )
        net.WriteString( name )
        net.WriteBool( value )
    net.SendToServer()
end

local function AddServerCheckbox( panel, label, cvarName )
    local cb = panel:CheckBox( label )
    cb:SetChecked( GetConVar( cvarName ):GetBool() )

    -- Отправляем изменение на сервер (применится, если ты суперадмин)
    cb.OnChange = function( self, val )
        if val == GetConVar( cvarName ):GetBool() then return end
        SendCVar( cvarName, val )
    end

    -- Синхронизация галочки, если значение изменили из консоли
    cvars.AddChangeCallback( cvarName, function( _, _, new )
        if IsValid( cb ) then cb:SetChecked( tobool( new ) ) end
    end, "WyldiHands_UI_" .. cvarName )

    return cb
end

hook.Add( "PopulateToolMenu", "WyldiHands_Menu", function()
    spawnmenu.AddToolMenuOption( "Utilities", "Artanis", "artanis_hands", "Hands", "", "", function( panel )
        panel:ClearControls()

        panel:Help( "Настройки пустых рук (меняет только суперадмин)." )

        AddServerCheckbox( panel, "Выдавать руки при спавне", "artanis_hands_autogive" )
        AddServerCheckbox( panel, "Автоматически брать руки в руки", "artanis_hands_autoselect" )

        panel:Help( "Если автовыдача выключена, руки можно взять в Q-меню → Weapons → Other." )
    end )
end )