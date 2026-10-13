-- Visual-only profile. Weapon/part compatibility remains server-authoritative.
-- Names below are existing GoM ModelScript attachment IDs, not invented pixel positions.
local P = {
    id = "gom",
    -- All providers share the enlarged frame; compact meshes retain exact margins.
    modelFraming = {
        MP5K={down=0.14,up=0.10,minDown=0.11,minUp=0.10,minAspect=0.30},
        TEC9={down=0.14,up=0.10,minDown=0.11,minUp=0.10,minAspect=0.30},
    },
    -- These authored handguns/compact SMGs use negative local Z for up.
    -- Exact model names only, scoped to this visual provider.
    invertedUpModels = {
        TEC9=true, MP5K=true, MAC10=true,
        M92FS=true, M93R=true, USP=true, DEAGLE=true, HIPOWER=true,
        P226=true, M1911=true, VP70M=true, SW629=true, MP412=true,
        RHINO=true, COLT_SINGLE=true, PYTHON=true, DETECTIVE_38=true,
    },
    anchors = {
        Scope={"scope","rail_up"},
        LaserRifle={"rail_left","rail_right"},
        LightRifle={"rail_right","rail_left"},
        Foregrip={"rail_down"},
        Bipod={"rail_down"},
        Underbarrel={"underbarrel","rail_down"},
        Canon={"canon","muzzle"},
        Suppressor={"muzzle","canon"},
        Barrel={"barrel"},
        Shellholder={"shellholder"},
        Stock={"stock","stock_mount"},
        Sling={"sling"},
        RecoilPad={"recoil_pad"},
        RailUp={"rail_up"},
        RailDown={"rail_down"},
        RailLeft={"rail_left"},
        RailRight={"rail_right"},
        CanonMount={"canon","muzzle"},
    },
}
return P
