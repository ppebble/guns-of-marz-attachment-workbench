import java.lang.reflect.*;
import java.util.*;
import java.util.function.Function;

/** Calls the installed game's actual translation JSON reader; no game/save startup. */
public class TranslationHarness {
    public static void main(String[] args) throws Exception {
        Class<?> language = Class.forName("zombie.core.Language");
        Constructor<?> constructor = language.getDeclaredConstructor(String.class, String.class, String.class, boolean.class);
        constructor.setAccessible(true);
        Method reader = Class.forName("zombie.core.Translator").getDeclaredMethod("tryFillMapFromFile",
            String.class, String.class, Map.class, language, Function.class);
        reader.setAccessible(true);
        Set<String> expected = null;
        for (String name : List.of("EN", "KO", "CN")) {
            Map<String,String> map = new HashMap<>();
            reader.invoke(null, args[0], "IG_UI", map, constructor.newInstance(name, name, "EN", false), Function.identity());
            if (map.size() < 60 || !map.containsKey("IGUI_GMAW_Title")) throw new AssertionError("Translation discovery failed: " + name);
            for (String value : map.values()) if (value.isBlank() || value.startsWith("IGUI_GMAW_")) throw new AssertionError(value);
            if (expected != null && !expected.equals(map.keySet())) throw new AssertionError("Language parity");
            expected = new HashSet<>(map.keySet());
            if (name.equals("KO") && map.get("IGUI_GMAW_Title").codePoints().noneMatch(c -> c >= 0xAC00 && c <= 0xD7A3))
                throw new AssertionError("Korean encoding");
            if (name.equals("CN") && map.get("IGUI_GMAW_Title").codePoints().noneMatch(c -> c >= 0x4E00 && c <= 0x9FFF))
                throw new AssertionError("Simplified Chinese encoding");
            System.out.println("PASS native translation reader " + name + ": " + map.size() + " keys");
            Map<String,String> sandbox = new HashMap<>();
            reader.invoke(null, args[0], "Sandbox", sandbox, constructor.newInstance(name, name, "EN", false), Function.identity());
            for (String key : List.of("Sandbox_GoMAttachmentWorkbench",
                    "Sandbox_GoMAttachmentWorkbench_ShowOnlyOwnedParts",
                    "Sandbox_GoMAttachmentWorkbench_ShowOnlyOwnedParts_tooltip")) {
                if (!sandbox.containsKey(key) || sandbox.get(key).isBlank()) throw new AssertionError("Sandbox translation: " + name + " " + key);
            }
            if (sandbox.size() != 3) throw new AssertionError("Sandbox translation parity: " + name);
            System.out.println("PASS native sandbox translation reader " + name + ": 3 keys");
        }
        Class<?> custom = Class.forName("zombie.sandbox.CustomSandboxOptions");
        Object definitions = custom.getConstructor().newInstance();
        Method readOptions = custom.getDeclaredMethod("readFile", String.class);
        readOptions.setAccessible(true);
        String optionPath = java.nio.file.Path.of(args[0], "media", "sandbox-options.txt").toString();
        if (!Boolean.TRUE.equals(readOptions.invoke(definitions, optionPath))) throw new AssertionError("Sandbox parse failed");
        Field optionsField = custom.getDeclaredField("options");
        optionsField.setAccessible(true);
        List<?> options = (List<?>) optionsField.get(definitions);
        if (options.size() != 1) throw new AssertionError("Sandbox option count");
        Object option = options.getFirst();
        Class<?> optionType = option.getClass();
        if (!optionType.getSimpleName().equals("CustomBooleanSandboxOption")
                || !optionType.getField("id").get(option).equals("GoMAttachmentWorkbench.ShowOnlyOwnedParts")
                || optionType.getField("defaultValue").getBoolean(option)
                || !optionType.getField("page").get(option).equals("GoMAttachmentWorkbench")
                || !optionType.getField("translation").get(option).equals("GoMAttachmentWorkbench_ShowOnlyOwnedParts")) {
            throw new AssertionError("Sandbox option contract");
        }
        System.out.println("PASS native sandbox parser: owned-only Boolean, default false");
    }
}
