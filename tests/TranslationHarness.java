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
        for (String name : List.of("EN", "KO")) {
            Map<String,String> map = new HashMap<>();
            reader.invoke(null, args[0], "IG_UI", map, constructor.newInstance(name, name, "EN", false), Function.identity());
            if (map.size() < 60 || !map.containsKey("IGUI_GMAW_Title")) throw new AssertionError("Translation discovery failed: " + name);
            for (String value : map.values()) if (value.isBlank() || value.startsWith("IGUI_GMAW_")) throw new AssertionError(value);
            if (expected != null && !expected.equals(map.keySet())) throw new AssertionError("Language parity");
            expected = new HashSet<>(map.keySet());
            if (name.equals("KO") && map.get("IGUI_GMAW_Title").codePoints().noneMatch(c -> c >= 0xAC00 && c <= 0xD7A3))
                throw new AssertionError("Korean encoding");
            System.out.println("PASS native translation reader " + name + ": " + map.size() + " keys");
        }
    }
}
