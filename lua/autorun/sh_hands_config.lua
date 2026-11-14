AddCSLuaFile()

WyldiHands = WyldiHands or {}

WyldiHands.CVarGive = CreateConVar(
    "Wyldi_Hands_Autogive", "1",
    FCVAR_ARCHIVE + FCVAR_REPLICATED + FCVAR_NOTIFY,
    "Выдавать руки игрокам при спавне (1/0)",
    0, 1
)

WyldiHands.CVarSelect = CreateConVar(
    "Wyldi_Hands_Autoselect", "1",
    FCVAR_ARCHIVE + FCVAR_REPLICATED + FCVAR_NOTIFY,
    "Автоматически брать руки в руки при спавне (1/0)",
    0, 1
)