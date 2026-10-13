-- ModelScript attachment metadata -> temporary scene-local leader endpoints.
-- No model, part script or loaded mesh is modified. Invalid/unavailable data
-- means NO leader for the specific slot; the clickable card remains visible.
local A = {}
local abs,min,max = math.abs,math.min,math.max

local function finite(v)
    return type(v)=="number" and v==v and abs(v)<100000
end

function A.resolve(profile, script, slot)
    local aliases=profile and profile.anchors and profile.anchors[slot]
    if not aliases or not script or not script.getAttachmentById then return nil end
    for _,id in ipairs(aliases) do
        local attachment=script:getAttachmentById(id)
        if attachment and attachment.getOffset then
            local offset=attachment:getOffset()
            if offset then
                local x,y,z=offset:x(),offset:y(),offset:z()
                if finite(x) and finite(y) and finite(z)
                    and abs(x)<10 and abs(y)<10 and abs(z)<10 then
                    return {id=id,x=x,y=y,z=z}
                end
            end
        end
    end
end

-- The *native UI3DScene* supplies camera/projection; we only apply the same
-- T * R * S held-model transform as Window.lua and the native attachment editor.
-- Right is Y=90 degrees: the model already faces left. Never reflect the
-- projected UI coordinate again. Mesh vertex transforms do not belong in the
-- socket transform; this locates a mount origin, not a part's mesh surface.
function A.project(profile, scene, attachment, direction)
    if not scene or not attachment then return nil end
    local camera=scene.javaObject
    local scale=scene.anchorScale
    local t=scene.anchorTranslation
    if not camera or not camera.sceneToUIX or not camera.sceneToUIY
        or not finite(scale) or not t then return nil end
    if not (finite(t.x) and finite(t.y) and finite(t.z)) then return nil end
    local sign=direction<0 and -1 or 1
    local upSign=scene.anchorUpSign or 1
    if upSign~=1 and upSign~=-1 then return nil end
    -- R_x(-90) R_y(upSign<0 ? 180 : 0) R_z(direction<0 ? 180 : 0).
    -- Model rendering, framing and sockets share the same authored axes.
    local wx=t.x+upSign*sign*attachment.x*scale
    local wy=t.y+upSign*attachment.z*scale
    local wz=t.z-sign*attachment.y*scale
    local sx=camera:sceneToUIX(wx,wy,wz)
    local sy=camera:sceneToUIY(wx,wy,wz)
    if not finite(sx) or not finite(sy) then return nil end
    -- Never connect to a point outside the central preview. Avoid boundary
    -- noise from the native projection or a model not yet ready.
    if sx<scene.width*0.04 or sx>scene.width*0.96
        or sy<scene.height*0.06 or sy>scene.height*0.94 then return nil end
    return {x=math.floor(sx+0.5),y=math.floor(sy+0.5),id=attachment.id}
end

return A
