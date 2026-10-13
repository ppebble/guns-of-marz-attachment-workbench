local Models=require "GMAW/UI/InstalledModels"
local oldManager=getScriptManager
local function list(entries)
    return {size=function() return #entries end,get=function(_,i) return entries[i+1] end}
end
local function script(name,sockets)
    return {getFullType=function() return name end,
        getAttachmentById=function(_,id) return sockets[id] end}
end
local scripts={Barrel=script("MarzGuns.Barrel",{barrel={}}),Sight=script("MarzGuns.Sight",{mount={}})}
getScriptManager=function() return {getModelScript=function(_,id) return scripts[id:gsub("^MarzGuns%.","")] end} end
local calls,removed,created,parents={},{},0,{}
local scene={previewScript=script("MarzGuns.Gun",{barrel={},scope={}}),javaObject={}}
function scene.javaObject:fromLua1(op,id)
    calls[#calls+1]=op;removed[#removed+1]=id
    assert(op=="removeModel" and id~="weapon","part cleanup must preserve base")
end
function scene.javaObject:fromLua2(op,id,arg)
    calls[#calls+1]=op
    if op=="createModel" then created=created+1
    else assert(arg==false,"child inherits root orientation without independent rotation") end
end
function scene.javaObject:fromLua4(op,id,selfAttachment,parent,parentAttachment)
    calls[#calls+1]=op
    assert(op=="setObjectParent" and parent=="weapon")
    parents[#parents+1]={id,selfAttachment,parentAttachment}
end
local parts={"MarzGuns.Barrel_Close"}
local mappings={{partType="MarzGuns.Barrel_Close",modelName="Barrel",attachmentNameSelf="barrel",attachmentParent="barrel"},
    {partType="MarzGuns.Scope",modelName="Sight",attachmentNameSelf="mount",attachmentParent="scope"}}
local version,bodyReads=1,0
local itemScript={getFullName=function() return "MarzGuns.Gun" end,
    getScriptVersion=function() return version end,
    getLoadedScriptBodies=function()
        return {size=function() return 2 end,get=function(_,i)
            assert(i==1);bodyReads=bodyReads+1
            local lines={"item Gun {", "// ModelWeaponPart = MarzGuns.Bad Absent,"}
            for _,m in ipairs(mappings) do
                lines[#lines+1]="ModelWeaponPart = "..m.partType.." "..m.modelName.." "
                    ..(m.attachmentNameSelf or "none").." "..(m.attachmentParent or "none").."," 
            end
            lines[#lines+1]="}"
            return table.concat(lines,"\n")
        end}
    end}
local gun={getScriptItem=function() return itemScript end,
    getAllWeaponParts=function()
        local result={}
        for _,name in ipairs(parts) do
            local fullType=name
            result[#result+1]={getFullType=function() return fullType end}
        end
        return list(result)
    end}
assert(Models.sync(scene,gun) and created==1 and #parents==1,"installed barrel creates one child")
assert(parents[1][2]=="barrel" and parents[1][3]=="barrel","native self/parent sockets retained")
local before=#calls
assert(not Models.sync(scene,gun) and #calls==before,"unchanged frame performs no native rebuild")
assert(bodyReads==1,"loaded script body parsed once per version")
parts[2]="MarzGuns.Scope"
assert(Models.sync(scene,gun) and #scene.installedModelIds==2,"same gun attachment changes refresh children")
assert(parents[#parents][2]=="mount" and parents[#parents][3]=="scope","different socket IDs preserve order")
mappings[2].attachmentParent="missing"
version=version+1
assert(Models.sync(scene,gun) and #scene.installedModelIds==2,"missing native socket preserves origin-authored child")
mappings[2].modelName="Absent"
version=version+1
assert(Models.sync(scene,gun) and #scene.installedModelIds==1,"missing model keeps valid barrel")
parts={}
assert(Models.sync(scene,gun) and #scene.installedModelIds==0,"detach clears obsolete children")
parts={"MarzGuns.Barrel_Close"}
local parentCall=scene.javaObject.fromLua4
scene.javaObject.fromLua4=function() error("native failure") end
assert(Models.sync(scene,gun) and #scene.installedModelIds==0,"failed parenting cannot leave floating model")
assert(removed[#removed]=="weapon-part-1")
before=#calls
assert(not Models.sync(scene,gun) and #calls==before,"failed descriptor does not retry every frame")
scene.javaObject.fromLua4=parentCall
Models.clear(scene)
assert(Models.sync(scene,gun) and #scene.installedModelIds==1,"explicit clear permits new scene setup")
mappings[#mappings+1]={partType="MarzGuns.Barrel_Close",modelName="Sight"}
version=version+1
assert(Models.sync(scene,gun) and #scene.installedModelIds==2,"multiple native mappings for one part all render")
assert(parents[#parents][2]==nil and parents[#parents][3]==nil,"null native sockets permit origin parenting")
assert(Models.sync(scene,{}) and #scene.installedModelIds==0,"unsupported gun clears prior children")
Models.clear(scene)
assert(#scene.installedModelIds==0 and scene.installedModelDescriptors==nil)
getScriptManager=oldManager
print("installed-models.test.lua: passed")
