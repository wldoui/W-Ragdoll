-- Переносит настоящие анимации ударов Beatrun (punchright/punchleft/punchmid из new_climbanim.mdl)
-- на руки рэгдолла wragdoll. new_climbanim.mdl без меша (0 вершин) - это намеренно так в оригинале,
-- поэтому сам он не рисуется, а служит только "двигателем" костей: модель скрыта (SetNoDraw),
-- на ней проигрывается sequence, а полученные относительные углы костей ValveBiped
-- (одинаковый скелет у climbanim и у рэгдолла) переносятся на кости рэгдолла каждый кадр.
if not CLIENT then return end

local DRIVER_MODEL = "models/new_climbanim.mdl"
local ARM_BONES = {
	"ValveBiped.Bip01_R_Clavicle", "ValveBiped.Bip01_R_UpperArm", "ValveBiped.Bip01_R_Forearm", "ValveBiped.Bip01_R_Hand",
	"ValveBiped.Bip01_L_Clavicle", "ValveBiped.Bip01_L_UpperArm", "ValveBiped.Bip01_L_Forearm", "ValveBiped.Bip01_L_Hand",
	"ValveBiped.Bip01_Spine1", "ValveBiped.Bip01_Spine2",
}

local driver
local function GetDriver()
	if IsValid(driver) then return driver end
	driver = ClientsideModel(DRIVER_MODEL, RENDERGROUP_OTHER)
	if not IsValid(driver) then return end
	driver:SetNoDraw(true)
	driver:SetPos(vector_origin)
	driver:DrawShadow(false)
	return driver
end

-- относительный угол кости в бинд-позе драйвера, чтобы применять ДЕЛЬТУ, а не абсолют
local bindAngle = {}
local function CaptureBind(d)
	if next(bindAngle) then return end
	d:SetSequence(0)
	d:SetCycle(0)
	d:InvalidateBoneCache()
	for _, name in ipairs(ARM_BONES) do
		local b = d:LookupBone(name)
		if b then bindAngle[name] = select(2, d:GetBonePosition(b)) end
	end
end

local active -- {rag=, seq=, t0=, dur=}
local SEQ_DUR = {punchright = 0.35, punchleft = 0.35, punchmid = 0.55}

function RD_PlayBeatrunPunch(rag, seqname)
	if not IsValid(rag) then return end
	local d = GetDriver()
	if not IsValid(d) then return end
	CaptureBind(d)
	local seq = d:LookupSequence(seqname)
	if seq < 0 then return end
	d:ResetSequence(seq)
	d:SetCycle(0)
	d:SetPlaybackRate(1)
	active = {rag = rag, dur = SEQ_DUR[seqname] or 0.4, t0 = CurTime()}
end

hook.Add("Think", "RD_BeatrunPunchDriver", function()
	if not active then return end
	local d = driver
	if not IsValid(d) or not IsValid(active.rag) then active = nil return end

	local k = (CurTime() - active.t0) / active.dur
	if k >= 1 then active = nil return end

	d:SetCycle(math.Clamp(k, 0, 1))
	d:FrameAdvance(0)
	d:InvalidateBoneCache()

	local rag = active.rag
	for _, name in ipairs(ARM_BONES) do
		local db = d:LookupBone(name)
		local rb = rag.GetBoneCount and rag:LookupBone(name)
		if db and rb and bindAngle[name] then
			local _, curAng = d:GetBonePosition(db)
			-- дельта от бинд-позы драйвера, наложенная на текущую позу кости рэгдолла
			local diff = curAng - bindAngle[name]
			local ragPos, ragAng = rag:GetBonePosition(rb)
			rag:ManipulateBoneAngles(rb, Angle(diff.p, diff.y, diff.r))
		end
	end
end)

hook.Add("ShutDown", "RD_BeatrunPunchCleanup", function()
	if IsValid(driver) then driver:Remove() end
end)
