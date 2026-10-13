import java.nio.file.*;
import java.util.*;
import java.util.regex.*;
import java.lang.reflect.*;

/** Actual non-debug native Item metadata through the installed Lua bridge. */
public class NativeInstalledModelsCheck {
    static Class<?> type(String name)throws Exception{return Class.forName(name);}
    static Object invoke(Object o,String name,Class<?>[] types,Object... args)throws Exception {
        return o.getClass().getMethod(name,types).invoke(o,args);
    }
    static Class<?> table;
    static Object run(Object thread,Object env,String source)throws Exception {
        Object closure=type("se.krka.kahlua.luaj.compiler.LuaCompiler").getMethod("loadstring",String.class,String.class,table).invoke(null,source,"native-parts-check",env);
        Object[] result=(Object[])invoke(thread,"pcall",new Class[]{Object.class,Object[].class},closure,new Object[0]);
        if(!Boolean.TRUE.equals(result[0]))throw new AssertionError(Arrays.toString(result));
        return result.length>1?result[1]:null;
    }
    static String itemBody(String text,String name) {
        Matcher match=Pattern.compile("\\bitem\\s+"+name+"\\s*\\{").matcher(text);
        if(!match.find())throw new AssertionError("Missing item "+name);
        int start=match.start(),end=match.end(),depth=1;
        while(depth>0&&end<text.length()) {
            char c=text.charAt(end++);if(c=='{')depth++;if(c=='}')depth--;
        }
        return text.substring(start,end);
    }
    static String lua(String value) {
        return value==null?"nil":"\""+value.replace("\\","\\\\").replace("\"","\\\"").replace("\r","\\r").replace("\n","\\n")+"\"";
    }
    static void checkDirectory(Path root,Object env,Object thread,Class<?> itemType,Class<?> moduleType,Method put)throws Exception {
        Map<String,Object> items=new LinkedHashMap<>();
        int declarations=0;
        List<Path> files;
        try(var paths=Files.walk(root)){files=paths.filter(p->p.toString().endsWith(".txt")).sorted().toList();}
        for(Path path:files) {
            String source=Files.readString(path).replaceAll("(?s)/\\*.*?\\*/","").replaceAll("//[^\\r\\n]*","");
            Matcher modules=Pattern.compile("\\bmodule\\s+([\\w]+)\\s*\\{").matcher(source);
            while(modules.find()) {
                int end=modules.end(),depth=1;
                while(depth>0&&end<source.length()){char c=source.charAt(end++);if(c=='{')depth++;if(c=='}')depth--;}
                String moduleName=modules.group(1),body=source.substring(modules.end(),end-1);
                Matcher names=Pattern.compile("\\bitem\\s+([\\w]+)\\s*\\{").matcher(body);
                while(names.find()) {
                    String name=names.group(1),itemSource=itemBody(body,name);
                    if(!Pattern.compile("ModelWeaponPart\\s*=",Pattern.CASE_INSENSITIVE).matcher(itemSource).find())continue;
                    String fullName=moduleName+"."+name;
                    Object item=items.get(fullName);
                    if(item==null) {
                        Object module=moduleType.getConstructor().newInstance();moduleType.getField("name").set(module,moduleName);
                        item=itemType.getConstructor().newInstance();invoke(item,"setModule",new Class[]{moduleType},module);
                        invoke(item,"setName",new Class[]{String.class},name);items.put(fullName,item);
                    }
                    invoke(item,"addLoadedScriptBody",new Class[]{String.class,String.class},"GaelGunStore",itemSource);
                    Matcher values=Pattern.compile("ModelWeaponPart\\s*=\\s*([^,}]+)",Pattern.CASE_INSENSITIVE).matcher(itemSource);
                    while(values.find()){invoke(item,"DoParam",new Class[]{String.class,String.class},"ModelWeaponPart",values.group(1).trim());declarations++;}
                }
                modules.region(end,source.length());
            }
        }
        // Test-only Java reflection supplies an independent native-parser oracle.
        // The production Lua path remains public-API-only with Core.debug false.
        Field nativeMappings=itemType.getDeclaredField("modelWeaponPart");nativeMappings.setAccessible(true);
        int descriptors=0;
        for(var entry:items.entrySet()) {
            List<?> mappings=(List<?>)nativeMappings.get(entry.getValue());
            if(mappings==null||mappings.isEmpty())throw new AssertionError("No native mappings for "+entry.getKey());
            LinkedHashSet<String> partTypes=new LinkedHashSet<>();
            for(Object mapping:mappings)partTypes.add((String)mapping.getClass().getField("partType").get(mapping));
            StringBuilder parts=new StringBuilder("{"),expected=new StringBuilder("{");
            for(String partType:partTypes) {
                parts.append(lua(partType)).append(',');
                for(Object mapping:mappings)if(partType.equals(mapping.getClass().getField("partType").get(mapping))) {
                    expected.append("{model=").append(lua((String)mapping.getClass().getField("modelName").get(mapping)))
                        .append(",selfAttachment=").append(lua((String)mapping.getClass().getField("attachmentNameSelf").get(mapping)))
                        .append(",parentAttachment=").append(lua((String)mapping.getClass().getField("attachmentParent").get(mapping))).append("},");
                    descriptors++;
                }
            }
            parts.append('}');expected.append('}');
            put.invoke(env,"nativeItem",entry.getValue());
            run(thread,env,"local partTypes="+parts+";local expected="+expected+";local label="+lua(entry.getKey())+"\n"+"""
                local scene={javaObject={}}
                local created,parented=0,0
                function scene.javaObject:fromLua1() error('unexpected model removal') end
                function scene.javaObject:fromLua2(op,id,value)
                    if op=='createModel' then created=created+1; assert(value==expected[created].model,label..' model mismatch') end
                end
                function scene.javaObject:fromLua4(op,id,selfSocket,parent,parentSocket)
                    parented=parented+1
                    assert(op=='setObjectParent' and parent=='weapon',label..' parent operation')
                    assert(selfSocket==expected[parented].selfAttachment,label..' self socket mismatch')
                    assert(parentSocket==expected[parented].parentAttachment,label..' parent socket mismatch')
                end
                function getScriptManager() return {getModelScript=function(_,name)
                    return {getFullType=function()return name end}
                end} end
                local parts={size=function()return #partTypes end,get=function(_,i)
                    return {getFullType=function()return partTypes[i+1] end}
                end}
                local gun={getScriptItem=function()return nativeItem end,getAllWeaponParts=function()return parts end}
                assert(Models.sync(scene,gun),label..' sync failed')
                assert(created==#expected and parented==#expected,label..' native descriptor count differs')
                assert(not Models.sync(scene,gun),label..' unchanged item rebuilt')
                """);
        }
        if(items.size()<100||descriptors<1000)throw new AssertionError("Unexpectedly small GGS coverage");
        System.out.println("PASS non-debug installed GGS native parity: "+items.size()+" items, "+declarations+" declarations, "+descriptors+" descriptors");
    }
    public static void main(String[] args)throws Exception {
        Class<?> core=type("zombie.core.Core");core.getField("debug").setBoolean(null,false);
        table=type("se.krka.kahlua.vm.KahluaTable");
        Class<?> platformType=type("se.krka.kahlua.vm.Platform"),converterType=type("se.krka.kahlua.converter.KahluaConverterManager");
        Object platform=type("se.krka.kahlua.j2se.J2SEPlatform").getMethod("getInstance").invoke(null);
        Object env=invoke(platform,"newEnvironment",new Class[0]);
        Object converter=converterType.getConstructor().newInstance();
        type("zombie.Lua.KahluaNumberConverter").getMethod("install",converterType).invoke(null,converter);
        Object exposer=type("zombie.Lua.LuaManager$Exposer").getConstructor(converterType,platformType,table).newInstance(converter,platform,env);
        Class<?> itemType=type("zombie.scripting.objects.Item"),moduleType=type("zombie.scripting.objects.ScriptModule");
        invoke(exposer,"setExposed",new Class[]{Class.class},itemType);
        invoke(exposer,"setExposed",new Class[]{Class.class},ArrayList.class);
        invoke(exposer,"exposeLikeJava",new Class[]{Class.class,table},itemType,env);
        invoke(exposer,"exposeLikeJava",new Class[]{Class.class,table},ArrayList.class,env);
        Object thread=type("se.krka.kahlua.vm.KahluaThread").getConstructor(platformType,table).newInstance(platform,env);
        thread.getClass().getField("debugOwnerThread").set(thread,Thread.currentThread());
        Method put=table.getMethod("rawset",Object.class,Object.class);
        put.invoke(env,"Models",run(thread,env,Files.readString(Path.of(args[0]))));
        if(Files.isDirectory(Path.of(args[1]))) {
            checkDirectory(Path.of(args[1]),env,thread,itemType,moduleType,put);
            if(core.getField("debug").getBoolean(null))throw new AssertionError("Probe enabled debug mode");
            return;
        }
        String text=Files.readString(Path.of(args[1]));
        for(String name:new String[]{"STEVENS_555","DOUBLEBARREL"}) {
            String body=itemBody(text,name);
            Object module=moduleType.getConstructor().newInstance();moduleType.getField("name").set(module,"MarzGuns");
            Object item=itemType.getConstructor().newInstance();
            invoke(item,"setModule",new Class[]{moduleType},module);
            invoke(item,"setName",new Class[]{String.class},name);
            invoke(item,"addLoadedScriptBody",new Class[]{String.class,String.class},"GunsOfMarz",body);
            Matcher match=Pattern.compile("ModelWeaponPart\\s*=\\s*([^,]+)",Pattern.CASE_INSENSITIVE).matcher(body);
            ArrayList<String[]> types=new ArrayList<>();
            while(match.find()) {
                String value=match.group(1).trim();invoke(item,"DoParam",new Class[]{String.class,String.class},"ModelWeaponPart",value);
                if(value.contains("Barrel_Close"))types.add(value.split("\\s+"));
            }
            if(types.isEmpty())throw new AssertionError("No actual barrel mapping "+name);
            put.invoke(env,"nativeItem",item);put.invoke(env,"partType",types.get(0)[0]);
            put.invoke(env,"expectedModel",types.get(0)[1]);
            run(thread,env,"assert(nativeItem:getFullName()=='MarzGuns."+name+"'); assert(nativeItem:getLoadedScriptBodies():size()==2); assert(type(nativeItem:getLoadedScriptBodies():get(1))=='string'); nativeItem:getScriptVersion()");
            run(thread,env,"""
                local calls={}
                local scene={javaObject={}}
                function scene.javaObject:fromLua1(op,id) error('unexpected removal') end
                function scene.javaObject:fromLua2(op,id,value)
                    if op=='createModel' then calls[#calls+1]=value end
                end
                function scene.javaObject:fromLua4(op,id,selfSocket,parent,parentSocket)
                    assert(op=='setObjectParent' and selfSocket=='barrel' and parentSocket=='barrel')
                end
                function getScriptManager() return {getModelScript=function(_,name)
                    return {getFullType=function()return name end}
                end} end
                local parts={size=function()return 1 end,get=function()return {getFullType=function()return partType end} end}
                local gun={getScriptItem=function()return nativeItem end,getAllWeaponParts=function()return parts end}
                assert(Models.sync(scene,gun) and #calls==1)
                assert(calls[1]==expectedModel,'actual closed-barrel model differs')
                assert(not Models.sync(scene,gun) and #calls==1,'unchanged native item rebuilt')
                """);
            System.out.println("PASS non-debug native Item -> Lua -> installed barrel: "+name);
        }
        if(core.getField("debug").getBoolean(null))throw new AssertionError("Probe enabled debug mode");
    }
}
