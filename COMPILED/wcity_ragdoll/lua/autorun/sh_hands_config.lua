AddCSLuaFile()

ArtanisHands = ArtanisHands or {}

ArtanisHands.CVarGive = CreateConVar(
    "artanis_hands_autogive", "1",
    FCVAR_ARCHIVE + FCVAR_REPLICATED + FCVAR_NOTIFY,
    "Выдавать руки игрокам при спавне (1/0)",
    0, 1
)

ArtanisHands.CVarSelect = CreateConVar(
    "artanis_hands_autoselect", "1",
    FCVAR_ARCHIVE + FCVAR_REPLICATED + FCVAR_NOTIFY,
    "Автоматически брать руки в руки при спавне (1/0)",
    0, 1
)