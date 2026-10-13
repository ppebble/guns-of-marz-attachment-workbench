-- GGS owns detailed, case-sensitive attachment points on its ModelScripts.
-- Only exact names are used. Missing points must not acquire arbitrary locations.
local P = {
    id = "gael",
    anchors = {
        Scope={"Scope"},
        Canon={"Canon","muzzle"},
        RecoilPad={"RecoilPad"},
        -- UI-only rear reference requested for slings; not the native sling
        -- mounting location. Reuse real rear sockets, never invent pixels.
        Sling={"Stock","RecoilPad","Sling"},
        Stock={"Stock"},
        Mount={"Mount"},
        L_Scope={"L_Scope"},
        Laser={"Laser"},
        Light={"Light"},
        Grip={"Grip"},
        Handguard={"Handguard"},
        Barrel_Shroud={"Barrel_Shroud"},
        Misc={"Misc"},
        -- The internal Hide_Beam, magazine Clip and stateful Stool parts are
        -- intentionally not UI attachment targets.
    },
}
return P
