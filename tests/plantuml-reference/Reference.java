// Test-only reference driver for the pinned PlantUML JAR.
//
// Run through `mise run plantuml-corpus:reference`, never from production code.
// The driver reads each frozen fixture, records native acceptance or refusal and
// writes a normalized semantic view. Regex and EBNF trees come from the actual
// railroad tiles that PlantUML builds (parser inspection). JSON and YAML values
// come from the parsed data tree. Text labels come from the rendered SVG.
//
// Usage: java -cp plantuml.jar Reference.java <fixtures-dir> <output-file>

import java.io.ByteArrayOutputStream;
import java.lang.reflect.Field;
import java.lang.reflect.Modifier;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Deque;
import java.util.Iterator;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;
import java.util.stream.Stream;

import net.sourceforge.plantuml.BlockUml;
import net.sourceforge.plantuml.FileFormat;
import net.sourceforge.plantuml.FileFormatOption;
import net.sourceforge.plantuml.SourceStringReader;
import net.sourceforge.plantuml.core.Diagram;
import net.sourceforge.plantuml.ebnf.EbnfEngine;
import net.sourceforge.plantuml.ebnf.PSystemEbnf;
import net.sourceforge.plantuml.ebnf.ShuntingYard;
import net.sourceforge.plantuml.ebnf.Symbol;
import net.sourceforge.plantuml.ebnf.Token;
import net.sourceforge.plantuml.error.PSystemError;
import net.sourceforge.plantuml.ErrorUml;
import net.sourceforge.plantuml.json.JsonArray;
import net.sourceforge.plantuml.json.JsonObject;
import net.sourceforge.plantuml.json.JsonValue;
import net.sourceforge.plantuml.jsondiagram.JsonDiagram;
import net.sourceforge.plantuml.regexdiagram.PSystemRegex;

public class Reference {

	public static void main(String[] args) throws Exception {
		final Path root = Path.of(args[0]);
		final List<Path> files;
		try (Stream<Path> walk = Files.walk(root)) {
			files = walk.filter(p -> p.toString().endsWith(".puml")).sorted().collect(Collectors.toList());
		}
		final StringBuilder out = new StringBuilder();
		out.append("{\n  \"plantuml\": ").append(quote(net.sourceforge.plantuml.version.Version.versionString()));
		out.append(",\n  \"java\": ").append(quote(System.getProperty("java.version")));
		out.append(",\n  \"fixtures\": [\n");
		for (int i = 0; i < files.size(); i++) {
			final Path file = files.get(i);
			final String name = root.relativize(file).toString().replace('\\', '/');
			final String source = Files.readString(file, StandardCharsets.UTF_8);
			out.append("    ").append(fixture(name, source));
			out.append(i + 1 < files.size() ? ",\n" : "\n");
		}
		out.append("  ]\n}\n");
		Files.writeString(Path.of(args[1]), out.toString(), StandardCharsets.UTF_8);
	}

	static String fixture(String name, String source) {
		final StringBuilder sb = new StringBuilder();
		sb.append("{\"name\": ").append(quote(name));
		try {
			final SourceStringReader reader = new SourceStringReader(source);
			final List<BlockUml> blocks = reader.getBlocks();
			sb.append(", \"blocks\": ").append(blocks.size());
			if (blocks.isEmpty()) {
				sb.append(", \"status\": \"refused\", \"error\": \"no diagram block\"}");
				return sb.toString();
			}
			final Diagram diagram = blocks.get(0).getDiagram();
			sb.append(", \"class\": ").append(quote(diagram.getClass().getSimpleName()));
			if (diagram instanceof PSystemError) {
				final List<String> errors = new ArrayList<>();
				for (ErrorUml error : ((PSystemError) diagram).getErrorsUml())
					errors.add(error.getError());
				sb.append(", \"status\": \"refused\", \"error\": ").append(quote(String.join("; ", errors)));
				sb.append("}");
				return sb.toString();
			}
			final String svg = render(diagram);
			final List<String> texts = texts(svg);
			final boolean syntaxError = texts.contains("Syntax error!");
			sb.append(", \"status\": ").append(quote(syntaxError ? "syntax-error" : "accepted"));
			sb.append(", \"title\": ").append(title(diagram));
			if (diagram instanceof PSystemRegex) {
				sb.append(", \"inspection\": \"parser\"");
				sb.append(", \"regex\": ").append(regex((PSystemRegex) diagram));
			} else if (diagram instanceof PSystemEbnf) {
				sb.append(", \"inspection\": \"parser\"");
				sb.append(", \"ebnf\": ").append(ebnf((PSystemEbnf) diagram));
			} else if (diagram instanceof JsonDiagram) {
				sb.append(", \"inspection\": \"data\"");
				final Object value = field(diagram, JsonDiagram.class, "root");
				sb.append(", \"data\": ").append(value == null ? "null" : data((JsonValue) value));
				sb.append(", \"highlights\": ").append(highlights(diagram));
			}
			sb.append(", \"texts\": ").append(strings(texts));
		} catch (Throwable error) {
			sb.append(", \"status\": \"crashed\", \"error\": ").append(quote(error.getClass().getSimpleName()));
		}
		sb.append("}");
		return sb.toString();
	}

	static String render(Diagram diagram) throws Exception {
		final ByteArrayOutputStream os = new ByteArrayOutputStream();
		diagram.exportDiagram(os, 0, new FileFormatOption(FileFormat.SVG));
		return os.toString(StandardCharsets.UTF_8);
	}

	static final Pattern TEXT = Pattern.compile("<text[^>]*>([^<]*)</text>");

	static List<String> texts(String svg) {
		final List<String> result = new ArrayList<>();
		final Matcher m = TEXT.matcher(svg);
		while (m.find())
			result.add(unescape(m.group(1)));
		return result;
	}

	static String unescape(String s) {
		return s.replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", "\"").replace("&#39;", "'")
				.replace("&apos;", "'").replace("&#160;", " ").replace("&amp;", "&");
	}

	static String title(Diagram diagram) {
		try {
			final Object titled = diagram.getClass().getMethod("getTitle").invoke(diagram);
			final Object display = titled.getClass().getMethod("getDisplay").invoke(titled);
			final List<String> lines = new ArrayList<>();
			for (Object line : (Iterable<?>) display)
				lines.add(line.toString());
			return lines.isEmpty() ? "null" : quote(String.join("\n", lines));
		} catch (Exception e) {
			return "null";
		}
	}

	static String regex(PSystemRegex diagram) throws Exception {
		final Deque<?> stack = (Deque<?>) field(diagram, PSystemRegex.class, "stack");
		final List<String> items = new ArrayList<>();
		// The stack top is drawn. Record every entry, top first.
		for (Object tile : stack)
			items.add(tile(tile, 0));
		return "[" + String.join(", ", items) + "]";
	}

	static String ebnf(PSystemEbnf diagram) throws Exception {
		final List<?> expressions = (List<?>) field(diagram, PSystemEbnf.class, "expressions");
		final List<String> items = new ArrayList<>();
		for (Object expression : expressions) {
			if (expression.getClass().getSimpleName().equals("EbnfExpression"))
				items.add(rule(diagram, expression));
			else
				items.add("{\"note\": " + display(capture(expression, "val$note")) + "}");
		}
		return "[" + String.join(", ", items) + "]";
	}

	// Mirror EbnfExpression.getUDrawable through the public engine and inspect
	// the tile that PlantUML draws.
	static String rule(PSystemEbnf diagram, Object expression) throws Exception {
		@SuppressWarnings("unchecked")
		final List<Token> tokens = (List<Token>) field(expression, expression.getClass(), "tokens");
		final Object above = field(expression, expression.getClass(), "commentAbove");
		final Object below = field(expression, expression.getClass(), "commentBelow");
		final StringBuilder sb = new StringBuilder("{\"tokens\": ");
		sb.append(strings(tokens.stream().map(Token::toString).collect(Collectors.toList())));
		sb.append(", \"above\": ").append(above == null ? "null" : quote(above.toString()));
		sb.append(", \"below\": ").append(below == null ? "null" : quote(below.toString()));
		if (tokens.size() < 2 || tokens.get(1).getSymbol() != Symbol.DEFINITION) {
			return sb.append(", \"error\": true}").toString();
		}
		sb.append(", \"name\": ").append(quote(tokens.get(0).getData()));
		final Iterator<Token> it = tokens.subList(2, tokens.size()).iterator();
		if (!it.hasNext())
			return sb.append(", \"tile\": \"empty\"}").toString();
		try {
			final List<Token> full = new ShuntingYard(it).getOuputQueue();
			if (full.isEmpty())
				return sb.append(", \"error\": true}").toString();
			final EbnfEngine engine = new EbnfEngine(diagram.getSkinParam(), diagram.getPreprocessingArtifact().getOption());
			for (Token element : full) {
				switch (element.getSymbol()) {
				case TERMINAL_STRING1, TERMINAL_STRING2, LITERAL, SPECIAL_SEQUENCE -> engine.push(element);
				case COMMENT_ABOVE -> engine.commentAbove(element.getData());
				case COMMENT_BELOW -> engine.commentBelow(element.getData());
				case ALTERNATION -> engine.alternation();
				case CONCATENATION -> engine.concatenation();
				case OPTIONAL -> engine.optional();
				case NOT -> engine.not();
				case REPETITION_ZERO_OR_MORE -> engine.repetitionZeroOrMore();
				case REPETITION_ONE_OR_MORE -> engine.repetitionOneOrMore();
				case REPETITION_SYMBOL -> engine.repetitionSymbol();
				default -> throw new UnsupportedOperationException(element.toString());
				}
			}
			final Object block = engine.getTextBlock();
			if (!block.getClass().getSimpleName().equals("ETileWithCircles"))
				return sb.append(", \"error\": true}").toString();
			return sb.append(", \"tile\": ").append(tile(block, 0)).append("}").toString();
		} catch (Exception e) {
			return sb.append(", \"error\": true}").toString();
		}
	}

	static final List<String> SKIPPED = List.of("FontConfiguration", "Style", "HColorSet", "ISkinParam", "HColor",
			"UText", "ConfigurationStore", "StringBounder", "ISkinSimple", "TextBlock", "UStroke");

	// A generic reflective dump of one railroad tile, without layout state.
	static String tile(Object value, int depth) throws Exception {
		if (depth > 200)
			throw new IllegalStateException("depth");
		if (value == null)
			return "null";
		if (value instanceof String)
			return quote((String) value);
		if (value instanceof Number || value instanceof Boolean)
			return value.toString();
		if (value instanceof Enum)
			return quote(((Enum<?>) value).name());
		if (value instanceof Collection) {
			final List<String> items = new ArrayList<>();
			for (Object item : (Collection<?>) value)
				items.add(tile(item, depth + 1));
			return "[" + String.join(", ", items) + "]";
		}
		final Class<?> type = value.getClass();
		if (type.getSimpleName().equals("Display"))
			return display(value);
		final StringBuilder sb = new StringBuilder("{\"tile\": ").append(quote(type.getSimpleName()));
		for (Class<?> c = type; c != null && c != Object.class; c = c.getSuperclass()) {
			for (Field f : c.getDeclaredFields()) {
				if (Modifier.isStatic(f.getModifiers()) || SKIPPED.contains(f.getType().getSimpleName()))
					continue;
				if (f.getType() == double.class || f.getType() == Double.class)
					continue;
				f.setAccessible(true);
				final Object v = f.get(value);
				if (v instanceof Collection && ((Collection<?>) v).isEmpty())
					continue;
				if (v == null)
					continue;
				final String simple = v.getClass().getName();
				if (!(v instanceof String || v instanceof Number || v instanceof Boolean || v instanceof Enum
						|| v instanceof Collection || simple.startsWith("net.sourceforge.plantuml.ebnf")
						|| simple.endsWith(".Display")))
					continue;
				sb.append(", ").append(quote(f.getName())).append(": ").append(tile(v, depth + 1));
			}
		}
		return sb.append("}").toString();
	}

	static String display(Object display) {
		if (display == null)
			return "null";
		final List<String> lines = new ArrayList<>();
		for (Object line : (Iterable<?>) display)
			lines.add(line.toString());
		return strings(lines);
	}

	static String data(JsonValue value) {
		if (value.isObject()) {
			final List<String> members = new ArrayList<>();
			for (JsonObject.Member m : (JsonObject) value)
				members.add("[" + quote(m.getName()) + ", " + data(m.getValue()) + "]");
			return "{\"object\": [" + String.join(", ", members) + "]}";
		}
		if (value.isArray()) {
			final List<String> items = new ArrayList<>();
			for (JsonValue v : (JsonArray) value)
				items.add(data(v));
			return "{\"array\": [" + String.join(", ", items) + "]}";
		}
		if (value.isString())
			return "{\"string\": " + quote(value.asString()) + "}";
		if (value.isNumber())
			return "{\"number\": " + quote(value.toString()) + "}";
		if (value.isTrue())
			return "{\"boolean\": true}";
		if (value.isFalse())
			return "{\"boolean\": false}";
		return "{\"null\": true}";
	}

	static String highlights(Diagram diagram) throws Exception {
		final List<?> list = (List<?>) field(diagram, JsonDiagram.class, "highlighted");
		final List<String> items = new ArrayList<>();
		for (Object h : list) {
			@SuppressWarnings("unchecked")
			final List<String> paths = (List<String>) field(h, h.getClass(), "paths");
			final Object stereotype = field(h, h.getClass(), "stereotype");
			items.add("{\"path\": " + strings(paths) + ", \"stereotype\": "
					+ (stereotype == null ? "null" : quote(stereotype.toString())) + "}");
		}
		return "[" + String.join(", ", items) + "]";
	}

	static Object field(Object target, Class<?> type, String name) throws Exception {
		final Field f = type.getDeclaredField(name);
		f.setAccessible(true);
		return f.get(target);
	}

	static Object capture(Object target, String name) throws Exception {
		for (Field f : target.getClass().getDeclaredFields())
			if (f.getName().equals(name)) {
				f.setAccessible(true);
				return f.get(target);
			}
		return null;
	}

	static String strings(List<String> items) {
		return "[" + items.stream().map(Reference::quote).collect(Collectors.joining(", ")) + "]";
	}

	static String quote(String s) {
		if (s == null)
			return "null";
		final StringBuilder sb = new StringBuilder("\"");
		for (int i = 0; i < s.length(); i++) {
			final char c = s.charAt(i);
			switch (c) {
			case '"' -> sb.append("\\\"");
			case '\\' -> sb.append("\\\\");
			case '\n' -> sb.append("\\n");
			case '\r' -> sb.append("\\r");
			case '\t' -> sb.append("\\t");
			default -> {
				if (c < 0x20 || c > 0x7e)
					sb.append(String.format("\\u%04x", (int) c));
				else
					sb.append(c);
			}
			}
		}
		return sb.append('"').toString();
	}
}
