// Naming conventions
//
// - All sprites start with S_
// - Generic sprites (walls, puddles, liquids, etc) prefixed w/ G_
// - Object-specific sprites are prefixd w/ O_
//

pub const Sprite = enum(u21) {
    S_G_Wall_Finished = 0x2790,
    S_G_Wall_Rough = 0x2791,
    S_G_Wall_Grate = 0x2792,
    S_G_Wall_Window = 0x2793,
    S_G_Wall_Scifish = 0x2794,
    S_G_Wall_Window2 = 0x2795,
    S_G_Wall_Polished = 0x2796,
    S_G_Wall_Ornate = 0x2797,
    S_G_StairsDown = 0x279E,
    S_G_StairsUp = 0x279F,

    S_G_T_Metal = 0x27A0,
    S_G_T_Ornate = 0x27A1,

    S_G_P_MiscLabMach = 0x27B0,
    S_O_P_Table = 0x27B1,
    S_O_P_Chair = 0x27B2,
    S_O_P_ControlPanel = 0x27B3,
    S_O_P_SwitchingStation = 0x27B4,
    S_G_M_Machine = 0x27BF,

    S_G_M_DoorShut = 0x27C0,
    S_G_M_DoorOpen = 0x27C1,
    S_O_M_LabDoorShut = 0x27C2,
    S_O_M_LabDoorOpen = 0x27C3,
    S_O_M_QrtDoorShut = 0x27C4,
    S_O_M_QrtDoorOpen = 0x27C5,
    S_O_M_PriLight = 0x27C6,
    S_O_M_LabLight = 0x27C7,
    S_G_Poster = 0x27CF,
};
