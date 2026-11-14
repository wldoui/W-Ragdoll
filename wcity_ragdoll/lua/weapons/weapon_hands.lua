AddCSLuaFile()

SWEP.PrintName      = "Hands"
SWEP.Author         = "Wyldi"
SWEP.Purpose        = "ЛКМ - драться, R - убрать кулаки."
SWEP.Instructions   = "ЛКМ: достать кулаки и бить. R (настраивается): пустые руки."
SWEP.Category       = "Other"

SWEP.Spawnable      = true
SWEP.AdminSpawnable = true

-- ================== НАСТРОЙКИ ==================
SWEP.ToggleKey   = KEY_R
SWEP.HitDistance = 48
SWEP.DamageMin   = 8
SWEP.DamageMax   = 12
-- ===============================================

SWEP.Slot       = 0
SWEP.SlotPos    = 0
SWEP.Weight     = 0
SWEP.AutoSwitchTo   = false
SWEP.AutoSwitchFrom = false
SWEP.DrawAmmo       = false
SWEP.DrawCrosshair  = false

-- Вшитые руки из обычного GMod (как в weapon_fists)
SWEP.ViewModel    = Model( "models/weapons/c_arms.mdl" )
SWEP.WorldModel   = ""
SWEP.ViewModelFOV = 54
SWEP.UseHands     = true
SWEP.HoldType     = "normal"

SWEP.Primary.ClipSize      = -1
SWEP.Primary.DefaultClip   = -1
SWEP.Primary.Automatic     = true
SWEP.Primary.Ammo          = "none"

SWEP.Secondary.ClipSize    = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic   = false
SWEP.Secondary.Ammo        = "none"

local SwingSound = Sound( "WeaponFrag.Throw" )
local HitSound   = Sound( "Flesh.ImpactHard" )

if CLIENT then
    SWEP.WepSelectIcon = surface.GetTextureID( "weapons/weapon_hands" )

    function SWEP:DrawWeaponSelection( x, y, wide, tall, alpha )
        surface.SetDrawColor( 255, 255, 255, alpha )
        surface.SetTexture( self.WepSelectIcon )
        y = y + 10
        x = x + 10
        wide = wide - 20
        surface.DrawTexturedRect( x, y, wide, wide / 2 )
    end
end

function SWEP:SetupDataTables()
    self:NetworkVar( "Bool",  0, "Fists" )            -- true = режим драки
    self:NetworkVar( "Float", 0, "NextMeleeAttack" )
    self:NetworkVar( "Float", 1, "NextIdle" )
    self:NetworkVar( "Bool",  1, "RightPunch" )
end

function SWEP:Initialize()
    self:SetHoldType( "normal" )
    self:SetFists( false )
end

---------------------------------------------------------------
-- Применение режима (пустые руки / кулаки)
---------------------------------------------------------------
function SWEP:ApplyMode()
    local owner = self:GetOwner()
    if not IsValid( owner ) or not owner:IsPlayer() then return end

    if self:GetFists() then
        self:SetHoldType( "fist" )
        if SERVER then owner:DrawViewModel( true ) end

        local vm = owner:GetViewModel()
        if IsValid( vm ) then
            vm:SendViewModelMatchingSequence( vm:LookupSequence( "fists_draw" ) )
            self:SetNextIdle( CurTime() + vm:SequenceDuration() )
        end
    else
        self:SetHoldType( "normal" )
        self:SetNextMeleeAttack( 0 )
        self:SetNextIdle( 0 )
        if SERVER then owner:DrawViewModel( false ) end
    end
end

function SWEP:Deploy()
    self:ApplyMode()
    return true
end

function SWEP:Holster()
    local owner = self:GetOwner()
    -- ОБЯЗАТЕЛЬНО возвращаем вьюмодель, иначе другие пушки будут невидимы
    if SERVER and IsValid( owner ) and owner:IsPlayer() then
        owner:DrawViewModel( true )
    end
    self:SetNextMeleeAttack( 0 )
    return true
end

function SWEP:OnRemove()
    local owner = self:GetOwner()
    if SERVER and IsValid( owner ) and owner:IsPlayer() then
        owner:DrawViewModel( true )
    end
end

function SWEP:OnDrop()
    self:Remove()
end

function SWEP:ShouldDropOnDie()
    return false
end

---------------------------------------------------------------
-- Атака
---------------------------------------------------------------
function SWEP:PrimaryAttack()
    local owner = self:GetOwner()
    if not IsValid( owner ) then return end

    -- Если руки пустые - достаём кулаки и сразу бьём
    if not self:GetFists() then
        self:SetFists( true )
        self:ApplyMode()
    end

    owner:SetAnimation( PLAYER_ATTACK1 )

    local right = self:GetRightPunch()
    local anim  = right and "fists_right" or "fists_left"
    self:SetRightPunch( not right )

    local vm = owner:GetViewModel()
    if IsValid( vm ) then
        vm:SendViewModelMatchingSequence( vm:LookupSequence( anim ) )
        self:SetNextIdle( CurTime() + vm:SequenceDuration() )
    end

    self:EmitSound( SwingSound )
    self:SetNextMeleeAttack( CurTime() + 0.2 )
    self:SetNextPrimaryFire( CurTime() + 0.6 )
    self:SetNextSecondaryFire( CurTime() + 0.6 )
end

function SWEP:SecondaryAttack() end

-- R по умолчанию тоже вызывает Reload; переключение делается в хуке ниже
function SWEP:Reload() end

function SWEP:DealDamage()
    local owner = self:GetOwner()
    if not IsValid( owner ) then return end

    owner:LagCompensation( true )

    local startPos = owner:GetShootPos()
    local endPos   = startPos + owner:GetAimVector() * self.HitDistance

    local tr = util.TraceLine( {
        start  = startPos,
        endpos = endPos,
        filter = owner,
        mask   = MASK_SHOT_HULL
    } )

    if not IsValid( tr.Entity ) then
        tr = util.TraceHull( {
            start  = startPos,
            endpos = endPos,
            filter = owner,
            mins   = Vector( -10, -10, -8 ),
            maxs   = Vector( 10, 10, 8 ),
            mask   = MASK_SHOT_HULL
        } )
    end

    if tr.Hit then self:EmitSound( HitSound ) end

    local scale = GetConVar( "phys_pushscale" ):GetFloat()
    local ent   = tr.Entity

    if SERVER and IsValid( ent ) and ( ent:IsNPC() or ent:IsPlayer() or ent:Health() > 0 ) then
        local dmg = DamageInfo()
        dmg:SetAttacker( owner )
        dmg:SetInflictor( self )
        dmg:SetDamage( math.random( self.DamageMin, self.DamageMax ) )
        dmg:SetDamageForce( owner:GetRight() * 4912 * scale + owner:GetForward() * 9998 * scale )
        ent:TakeDamageInfo( dmg )
    end

    if IsValid( ent ) then
        local phys = ent:GetPhysicsObject()
        if IsValid( phys ) then
            phys:ApplyForceOffset( owner:GetAimVector() * 80 * phys:GetMass() * scale, tr.HitPos )
        end
    end

    owner:LagCompensation( false )
end

function SWEP:Think()
    if not self:GetFists() then return end

    local owner = self:GetOwner()
    if not IsValid( owner ) then return end

    local melee = self:GetNextMeleeAttack()
    if melee > 0 and CurTime() > melee then
        self:DealDamage()
        self:SetNextMeleeAttack( 0 )
    end

    local idle = self:GetNextIdle()
    if idle > 0 and CurTime() > idle then
        local vm = owner:GetViewModel()
        if IsValid( vm ) then
            vm:SendViewModelMatchingSequence( vm:LookupSequence( "fists_idle0" .. math.random( 1, 2 ) ) )
            self:SetNextIdle( CurTime() + vm:SequenceDuration() )
        end
    end
end

-- Мировую модель не рисуем
function SWEP:DrawWorldModel() end
function SWEP:DrawWorldModelTranslucent() end

---------------------------------------------------------------
-- Кнопка "убрать кулаки" (пустые руки)
---------------------------------------------------------------
if SERVER then
    hook.Add( "PlayerButtonDown", "WyldiHands_Toggle", function( ply, button )
        local wep = ply:GetActiveWeapon()
        if not IsValid( wep ) or wep:GetClass() ~= "weapon_hands" then return end
        if button ~= wep.ToggleKey then return end

        if wep:GetFists() then
            wep:SetFists( false )
            wep:ApplyMode()
        end
    end )
end