AddCSLuaFile()

SWEP.PrintName      = "Hands"
SWEP.Author         = "Wyldi"
SWEP.Purpose        = "ЛКМ - драться, R - убрать кулаки."
SWEP.Instructions   = "ЛКМ: достать кулаки и бить. R: пустые руки."
SWEP.Category       = "Other"
SWEP.Spawnable      = true
SWEP.AdminSpawnable = true

-- ================== НАСТРОЙКИ ==================
local RUNNER_MODEL = "models/runnerhands.mdl"

SWEP.HitDistance = 50
SWEP.DamageMin   = 8
SWEP.DamageMax   = 12
SWEP.MidMult     = 1.6
SWEP.ComboReset  = 0.5

local PUNCH_SEQ = {
	{"punch1", "punchright"},
	{"punch2", "punchleft"},
	{"punch3", "punchmid"},
}
local DRAW_SEQ = {"draw", "fists_draw", "deploy"}
local IDLE_SEQ = {"idle", "idle1", "fists_idle_01"}

local HIT_FRAC  = {0.30, 0.30, 0.40}
local NEXT_FRAC = {0.65, 0.65, 0.85}
local PUNCH_VP  = {Angle(2, 1, -2), Angle(2, -1, 2), Angle(3, 0, 0)}
-- ===============================================

SWEP.Slot = 0
SWEP.SlotPos = 0
SWEP.Weight = 0
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false

local useRunner = util.IsValidModel(RUNNER_MODEL)
SWEP.ViewModel    = useRunner and RUNNER_MODEL
SWEP.UseHands     = true
SWEP.ViewModelFOV = 70
SWEP.WorldModel   = ""
SWEP.HoldType     = "normal"

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "none"
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

if CLIENT then
	SWEP.WepSelectIcon = surface.GetTextureID("weapons/weapon_hands")
	function SWEP:DrawWeaponSelection(x, y, wide, tall, alpha)
		surface.SetDrawColor(255, 255, 255, alpha)
		surface.SetTexture(self.WepSelectIcon)
		surface.DrawTexturedRect(x + 10, y + 10, wide - 20, (wide - 20) / 2)
	end

	concommand.Add("wh_dump", function()
		local vm = LocalPlayer():GetViewModel()
		if not IsValid(vm) then return print("нет вьюмодели") end
		print("VM model:", vm:GetModel(), "sequences:", vm:GetSequenceCount())
		for i = 0, vm:GetSequenceCount() - 1 do
			print(i, vm:GetSequenceName(i), vm:GetSequenceActivityName(i))
		end
	end)
end

function SWEP:SetupDataTables()
	self:NetworkVar("Bool",  0, "Fists")
	self:NetworkVar("Float", 0, "NextIdle")
	self:NetworkVar("Float", 1, "PunchReset")
	self:NetworkVar("Float", 2, "PendingHit")
	self:NetworkVar("Int",   0, "Punch")
	self:NetworkVar("Int",   1, "PendingIdx")
end

function SWEP:Initialize()
	self:SetHoldType("normal")
	self:SetFists(false)
	self:SetPunch(1)
end

function SWEP:PlayVM(names, act)
	local owner = self:GetOwner()
	if not IsValid(owner) then return 0 end
	local vm = owner:GetViewModel()
	if not IsValid(vm) then return 0 end
	for _, n in ipairs(names) do
		local s = vm:LookupSequence(n)
		if s and s >= 0 then
			vm:SendViewModelMatchingSequence(s)
			return vm:SequenceDuration(s)
		end
	end
	if act then
		self:SendWeaponAnim(act)
		return vm:SequenceDuration()
	end
	return 0
end

function SWEP:ApplyMode()
	local owner = self:GetOwner()
	if not IsValid(owner) or not owner:IsPlayer() then return end
	if self:GetFists() then
		self:SetHoldType("fist")
		if SERVER then owner:DrawViewModel(true) end
		local d = self:PlayVM(DRAW_SEQ, ACT_VM_DRAW)
		self:SetNextIdle(CurTime() + d)
	else
		self:SetHoldType("normal")
		self:SetNextIdle(0)
		self:SetPendingHit(0)
		if SERVER then owner:DrawViewModel(false) end
	end
end

function SWEP:Deploy()
	self:ApplyMode()
	return true
end

function SWEP:Holster()
	local owner = self:GetOwner()
	if SERVER and IsValid(owner) and owner:IsPlayer() then owner:DrawViewModel(true) end
	self:SetPendingHit(0)
	return true
end

function SWEP:OnRemove()
	local owner = self:GetOwner()
	if SERVER and IsValid(owner) and owner:IsPlayer() then owner:DrawViewModel(true) end
end

function SWEP:OnDrop() self:Remove() end
function SWEP:ShouldDropOnDie() return false end

function SWEP:Reload()
	if self:GetFists() and (self.NextToggle or 0) < CurTime() then
		self.NextToggle = CurTime() + 0.5
		self:SetFists(false)
		self:ApplyMode()
	end
end

function SWEP:SecondaryAttack() end

function SWEP:PrimaryAttack()
	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	if not self:GetFists() then
		self:SetFists(true)
		self:ApplyMode()
		self:SetNextPrimaryFire(CurTime() + 0.5)
		return
	end

	local now = CurTime()
	if now > self:GetPunchReset() then self:SetPunch(1) end
	local p = math.Clamp(self:GetPunch(), 1, 3)

	local dur = self:PlayVM(PUNCH_SEQ[p], ACT_VM_HITCENTER)
	if dur <= 0 then dur = 0.6 end

	owner:SetAnimation(PLAYER_ATTACK1)
	owner:ViewPunch(PUNCH_VP[p])

	local nextAt = now + dur * NEXT_FRAC[p]
	self:SetPendingIdx(p)
	self:SetPendingHit(now + dur * HIT_FRAC[p])
	self:SetNextPrimaryFire(nextAt)
	self:SetNextSecondaryFire(nextAt)
	self:SetNextIdle(now + dur)
	self:SetPunchReset(now + dur + self.ComboReset)
	self:SetPunch(p % 3 + 1)
end

-- ================== ЭФФЕКТЫ ПО МАТЕРИАЛУ ==================
local SURFACE_DECAL = {
	[MAT_CONCRETE] = "Impact.Sand",
	[MAT_TILE]     = "Impact.Sand",
	[MAT_WOOD]     = "Impact.Wood",
	[MAT_METAL]    = "Impact.Sand",
	[MAT_GRATE]    = "Impact.Metal",
	[MAT_VENT]     = "Impact.Metal",
	[MAT_COMPUTER] = "Impact.Metal",
	[MAT_DIRT]     = "Impact.Sand",
	[MAT_SAND]     = "Impact.Sand",
	[MAT_SNOW]     = "Impact.Sand",
	[MAT_GLASS]    = "Impact.Glass",
	[MAT_PLASTIC]  = "Impact.Sand",
}

local SURFACE_SOUNDS = {
	[MAT_CONCRETE] = "physics/concrete/concrete_impact_hard1.wav",
	[MAT_TILE]     = "physics/concrete/concrete_impact_hard1.wav",
	[MAT_WOOD]     = "physics/wood/wood_solid_impact_hard1.wav",
	[MAT_METAL]    = "physics/metal/metal_solid_impact_hard1.wav",
	[MAT_GRATE]    = "physics/metal/metal_grate_impact_hard1.wav",
	[MAT_VENT]     = "physics/metal/metal_solid_impact_hard1.wav",
	[MAT_COMPUTER] = "physics/metal/metal_solid_impact_hard1.wav",
	[MAT_DIRT]     = "physics/surfaces/sand_impact_bullet1.wav",
	[MAT_SAND]     = "physics/surfaces/sand_impact_bullet1.wav",
	[MAT_SNOW]     = "physics/surfaces/sand_impact_bullet1.wav",
	[MAT_GLASS]    = "physics/glass/glass_impact_hard1.wav",
	[MAT_PLASTIC]  = "physics/plastic/plastic_box_impact_hard1.wav",
	[MAT_FLESH]    = "physics/flesh/flesh_impact_hit1.wav",
	[MAT_BLOODYFLESH] = "physics/flesh/flesh_impact_hit1.wav",
	[MAT_ALIENFLESH]  = "physics/flesh/flesh_impact_hit1.wav",
}

local DEFAULT_SOUND = "physics/concrete/concrete_impact_hard1.wav"
local DEFAULT_DECAL = "Impact.Concrete"

local function GetDecalName(tr)
	local name = SURFACE_DECAL[tr.MatType] or DEFAULT_DECAL
	local m = util.DecalMaterial(name)
	if not m or m == "" then name = DEFAULT_DECAL end
	return name
end

function SWEP:PlayImpactSound(tr, living)
	local snd
	if living then
		snd = SURFACE_SOUNDS[MAT_FLESH]
	else
		snd = SURFACE_SOUNDS[tr.MatType] or DEFAULT_SOUND
	end
	sound.Play(snd, tr.HitPos, 75, math.random(95, 105), 1)
end

function SWEP:WallHitFX(tr)
	local startPos = tr.HitPos + tr.HitNormal * 4
	local endPos   = tr.HitPos - tr.HitNormal * 4
	util.Decal(GetDecalName(tr), startPos, endPos, self:GetOwner())
end

function SWEP:DoHit(idx)
	if CLIENT then return end

	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	owner:LagCompensation(true)
	local start = owner:GetShootPos()
	local dir = owner:GetAimVector()
	local tr = util.TraceLine({
		start = start, endpos = start + dir * self.HitDistance,
		filter = owner, mask = MASK_SHOT_HULL,
	})
	if not tr.Hit then
		tr = util.TraceHull({
			start = start, endpos = start + dir * self.HitDistance, filter = owner,
			mins = Vector(-10, -10, -8), maxs = Vector(10, 10, 8), mask = MASK_SHOT_HULL,
		})
	end
	owner:LagCompensation(false)

	-- промах или небо: ничего не делаем
	if not tr.Hit or tr.HitSky then return end

	local ent = tr.Entity
	local living = IsValid(ent) and (ent:IsPlayer() or ent:IsNPC())

	self:PlayImpactSound(tr, living)

	local mult = idx == 3 and self.MidMult or 1

	if IsValid(ent) and not ent:IsWorld() then
		local dmg = DamageInfo()
		dmg:SetDamage(math.random(self.DamageMin, self.DamageMax) * mult)
		dmg:SetDamageType(DMG_CLUB)
		dmg:SetAttacker(owner)
		dmg:SetInflictor(self)
		dmg:SetDamageForce(dir * 8000 * mult)
		dmg:SetDamagePosition(tr.HitPos)
		ent:DispatchTraceAttack(dmg, tr, dir)

		local phys = ent:GetPhysicsObject()
		if IsValid(phys) and not living then
			phys:ApplyForceOffset(dir * 12000 * mult, tr.HitPos)
		end
	end

	-- декаль только на твёрдых поверхностях (не на игроках/NPC)
	if not living then
		self:WallHitFX(tr)
	end
end

function SWEP:Think()
	local owner = self:GetOwner()
	if not IsValid(owner) or not self:GetFists() then return end
	local now = CurTime()

	if SERVER then
		local hit = self:GetPendingHit()
		if hit > 0 and now >= hit then
			self:SetPendingHit(0)
			self:DoHit(self:GetPendingIdx())
		end
	end

	local idle = self:GetNextIdle()
	if idle > 0 and now >= idle then
		self:PlayVM(IDLE_SEQ, ACT_VM_IDLE)
		self:SetNextIdle(0)
	end
end

if SERVER then
	hook.Add("PlayerSpawn", "GiveDefaultHandsWeapon", function(ply)
		timer.Simple(0, function()
			if not IsValid(ply) then return end

			if not ply:HasWeapon("weapon_hands") then
				ply:Give("weapon_hands")
			end

			ply:SelectWeapon("weapon_hands")
		end)
	end)
end