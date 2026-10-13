-- Mirror ModelManager.addWeaponPartModels using read-only native mappings.
-- Child scene objects inherit the weapon's framing and held orientation.
local M={}

local function scriptMappings(scene,gun)
    if not gun.getScriptItem then return {} end
    local script=gun:getScriptItem()
    if not script or not script.getLoadedScriptBodies then return {} end
    local version=script.getScriptVersion and script:getScriptVersion() or 0
    local bodies=script:getLoadedScriptBodies()
    local count=bodies and bodies:size() or 0
    if scene.installedMappingScript==script and scene.installedMappingVersion==version
        and scene.installedMappingBodyCount==count then return scene.installedMappings end
    local mappings={}
    local fullType=script:getFullName()
    local module=fullType and fullType:match("^([^%.]+)%.")
    if module then
        -- Native ModelWeaponPart has no Lua getters. Read its already-loaded
        -- public script bodies once; no debug reflection or filesystem access.
        for i=1,count-1,2 do
            local body=bodies:get(i):gsub("/%*.-%*/",""):gsub("//[^\r\n]*","")
            for key,value in body:gmatch("([%w_]+)%s*=%s*([^,{}]+)") do
                if key:lower()=="modelweaponpart" then
                    local words={}
                    for token in value:gmatch("%S+") do words[#words+1]=token end
                    if #words>=2 and #words<=4 then
                        local entry
                        -- Match the native Item parser, including repeated
                        -- declarations that update an existing mapping.
                        for _,old in ipairs(mappings) do
                            if old.partType==words[1] then entry=old;break end
                        end
                        entry=entry or {}
                        entry.partType=words[1]:find("%.") and words[1] or module.."."..words[1]
                        entry.modelName=words[2]:find("%.") and words[2] or module.."."..words[2]
                        entry.attachmentNameSelf=words[3]
                        entry.attachmentParent=words[4]
                        if words[3] and words[3]:lower()=="none" then entry.attachmentNameSelf=nil end
                        if words[4] and words[4]:lower()=="none" then entry.attachmentParent=nil end
                        mappings[#mappings+1]=entry
                    end
                end
            end
        end
    end
    local byType={}
    for _,mapping in ipairs(mappings) do
        local entries=byType[mapping.partType] or {}
        entries[#entries+1]=mapping
        byType[mapping.partType]=entries
    end
    scene.installedMappingScript=script
    scene.installedMappingVersion=version
    scene.installedMappingBodyCount=count
    scene.installedMappings=byType
    return byType
end

local function descriptors(scene,gun)
    local result={}
    if not gun or not gun.getAllWeaponParts then return result end
    local mappings=scriptMappings(scene,gun)
    local parts=gun:getAllWeaponParts()
    if not mappings or not parts then return result end
    for i=0,parts:size()-1 do
        local part=parts:get(i)
        local fullType=part and part:getFullType()
        for _,mapping in ipairs(mappings[fullType] or {}) do
            result[#result+1]={model=mapping.modelName,
                selfAttachment=mapping.attachmentNameSelf,parentAttachment=mapping.attachmentParent}
        end
    end
    return result
end

local function same(a,b)
    if not a or #a~=#b then return false end
    for i=1,#a do
        if a[i].model~=b[i].model or a[i].selfAttachment~=b[i].selfAttachment
            or a[i].parentAttachment~=b[i].parentAttachment then return false end
    end
    return true
end

function M.clear(scene)
    if not scene then return end
    for i=#(scene.installedModelIds or {}),1,-1 do
        pcall(function() scene.javaObject:fromLua1("removeModel",scene.installedModelIds[i]) end)
    end
    scene.installedModelIds={}
    scene.installedModelDescriptors=nil
end

function M.sync(scene,gun)
    if not scene or not scene.javaObject then return false end
    local ok,wanted=pcall(descriptors,scene,gun)
    if not ok then return false end
    if same(scene.installedModelDescriptors,wanted) then return false end
    M.clear(scene)
    scene.installedModelDescriptors=wanted
    for i,entry in ipairs(wanted) do
        local id="weapon-part-"..i
        local created=false
        local success=pcall(function()
            local script=getScriptManager():getModelScript(entry.model)
            if not script then return end
            local java=scene.javaObject
            java:fromLua2("createModel",id,script:getFullType())
            created=true
            java:fromLua2("setObjectAutoRotate",id,false)
            java:fromLua2("setModelUseWorldAttachment",id,false)
            java:fromLua2("setModelWeaponRotationHack",id,false)
            -- Native absent sockets intentionally resolve to identity. Some
            -- integrated barrels are authored at the gun origin this way.
            java:fromLua4("setObjectParent",id,entry.selfAttachment,"weapon",entry.parentAttachment)
            scene.installedModelIds[#scene.installedModelIds+1]=id
        end)
        if not success and created then
            pcall(function() scene.javaObject:fromLua1("removeModel",id) end)
        end
    end
    return true
end

return M
