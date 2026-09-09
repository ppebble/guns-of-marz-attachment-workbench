import java.nio.file.*;
import java.lang.reflect.*;

/** Runs source tests using the installed game's Kahlua VM, without test dependencies. */
public class LuaHarness {
    public static void main(String[] args) throws Exception {
        Class<?> platformClass = Class.forName("se.krka.kahlua.vm.Platform");
        Class<?> tableClass = Class.forName("se.krka.kahlua.vm.KahluaTable");
        Class<?> j2se = Class.forName("se.krka.kahlua.j2se.J2SEPlatform");
        Object platform = j2se.getMethod("getInstance").invoke(null);
        Object env = j2se.getMethod("newEnvironment").invoke(platform);
        Class<?> threadClass = Class.forName("se.krka.kahlua.vm.KahluaThread");
        Object thread = threadClass.getConstructor(platformClass, tableClass).newInstance(platform, env);
        threadClass.getField("debugOwnerThread").set(thread, Thread.currentThread());
        Method compile = Class.forName("se.krka.kahlua.luaj.compiler.LuaCompiler").getMethod("loadstring", String.class, String.class, tableClass);
        Method pcall = threadClass.getMethod("pcall", Object.class, Object[].class);
        for (String path : args) {
            Object closure = compile.invoke(null, Files.readString(Path.of(path)), path, env);
            String name = path.replace('\\', '/');
            int start = name.indexOf("/media/lua/shared/");
            int prefix = "/media/lua/shared/".length();
            if (start < 0) { start = name.indexOf("/media/lua/server/"); prefix = "/media/lua/server/".length(); }
            if (start < 0) { start = name.indexOf("/media/lua/client/"); prefix = "/media/lua/client/".length(); }
            boolean module = start >= 0;
            if (module || path.endsWith(".test.lua") || path.endsWith("bootstrap.lua")) {
                Object[] result = (Object[]) pcall.invoke(thread, closure, new Object[0]);
                if (!Boolean.TRUE.equals(result[0])) throw new AssertionError(path + ": " + java.util.Arrays.toString(result));
                if (module) {
                    Object modules = tableClass.getMethod("rawget", Object.class).invoke(env, "modules");
                    tableClass.getMethod("rawset", Object.class, Object.class).invoke(modules,
                        name.substring(start + prefix, name.length() - 4), result.length > 1 ? result[1] : Boolean.TRUE);
                }
            }
            System.out.println("PASS " + path);
        }
    }
}
