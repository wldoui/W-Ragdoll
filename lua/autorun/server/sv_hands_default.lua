local HANDS_CLASS = "weapon_hands"

util.AddNetworkString( "WyldiHands_SetConVar" )

hook.Add( "PlayerSpawn", "WyldiHands_GiveDefault", function( ply )
    timer.Simple( 0, function()
        if not IsValid( ply ) or not ply:Alive() then return end

        if WyldiHands.CVarGive:GetBool() and not ply:HasWeapon( HANDS_CLASS ) then
            ply:Give( HANDS_CLASS )
        end

        if WyldiHands.CVarSelect:GetBool() and ply:HasWeapon( HANDS_CLASS ) then
            ply:SelectWeapon( HANDS_CLASS )
        end
    end )
end )

local allowed 