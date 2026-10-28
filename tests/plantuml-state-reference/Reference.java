// Test-only pinned PlantUML semantic projection. No rendering determines topology.
import java.nio.file.*;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.stream.*;
import net.sourceforge.plantuml.*;
import net.sourceforge.plantuml.core.Diagram;
import net.sourceforge.plantuml.error.PSystemError;
import net.sourceforge.plantuml.statediagram.StateDiagram;
import net.sourceforge.plantuml.abel.*;
public class Reference {
  static String q(String s) {
    if (s == null) return "null";
    StringBuilder b = new StringBuilder("\"");
    for (char c : s.toCharArray()) switch(c) {
      case '"': b.append("\\\""); break;
      case '\\': b.append("\\\\"); break;
      case '\n': b.append("\\n"); break;
      case '\r': b.append("\\r"); break;
      case '\t': b.append("\\t"); break;
      default: if (c < 32) b.append(String.format("\\u%04x", (int)c)); else b.append(c);
    }
    return b.append('"').toString();
  }
  static String display(Object value) {
    if (value == null || value == net.sourceforge.plantuml.klimt.creole.Display.NULL) return "";
    List<String> rows = new ArrayList<>();
    if (value instanceof Iterable<?>) for (Object line : (Iterable<?>)value) rows.add(line.toString());
    return String.join("\n", rows);
  }
  static String name(Entity e) { return e.isRoot() ? "root" : e.getQuark().getQualifiedName(); }
  static String body(Entity e) {
    List<String> values = new ArrayList<>();
    for (CharSequence line : e.getBodier().getRawBody()) values.add(q(line.toString()));
    return "[" + String.join(",", values) + "]";
  }
  static String entity(Entity e) {
    return "{\"id\":" + q(name(e)) + ",\"parent\":" + q(name(e.getParentContainer())) +
      ",\"group\":" + e.isGroup() + ",\"role\":" + q(e.isGroup() ? e.getGroupType().name() : e.getLeafType().name()) + ",\"position\":" + q(e.isGroup() ? "NORMAL" : e.getEntityPosition().name()) + ",\"stereotype\":" + q(e.getStereotype() == null ? "" : e.getStereotype().toString()) +
      ",\"label\":" + q(display(e.getDisplay())) + ",\"descriptions\":" + body(e) + "}";
  }
  static String fixture(Path root, Path file) {
    String prefix = "{\"name\":" + q(root.relativize(file).toString().replace('\\','/'));
    try {
      Diagram d = new SourceStringReader(Files.readString(file)).getBlocks().get(0).getDiagram();
      if (d instanceof PSystemError) return prefix + ",\"status\":\"refused\",\"error\":" + q(d.getDescription().getDescription()) + "}";
      if (!(d instanceof StateDiagram)) return prefix + ",\"status\":\"other-family\",\"class\":" + q(d.getClass().getSimpleName()) + "}";
      StateDiagram s = (StateDiagram)d;
      List<String> entities = new ArrayList<>();
      for (Entity e : s.groups()) entities.add(entity(e));
      for (Entity e : s.leafs()) if (e.getLeafType() != LeafType.STATE_TRANSITION_LABEL) entities.add(entity(e));
      List<String> links = new ArrayList<>();
      for (Link l : s.getLinks()) {
        Entity a = l.isInverted() ? l.getEntity2() : l.getEntity1(), b = l.isInverted() ? l.getEntity1() : l.getEntity2();
        String label = display(l.getLabel());
        // Node-style transition labels are presentation nodes, with timestamp IDs.
        // Collapse their two links by inspecting actual upstream entities and links.
        if (a.getLeafType() == LeafType.STATE_TRANSITION_LABEL) continue;
        if (b.getLeafType() == LeafType.STATE_TRANSITION_LABEL) {
          Entity middle = b;
          label = display(middle.getDisplay());
          for (Link next : s.getLinks()) if ((next.isInverted() ? next.getEntity2() : next.getEntity1()) == middle) { b = next.isInverted() ? next.getEntity1() : next.getEntity2(); break; }
        }
        links.add("{\"source\":" + q(name(a)) + ",\"target\":" + q(name(b)) + ",\"label\":" + q(label) + "}");
      }
      return prefix + ",\"status\":\"accepted\",\"entities\":[" + String.join(",",entities) + "],\"links\":[" + String.join(",",links) + "]}";
    } catch (Throwable e) { return prefix + ",\"status\":\"crashed\",\"error\":" + q(e.toString()) + "}"; }
  }
  public static void main(String[] args) throws Exception {
    Path root = Path.of(args[0]);
    List<Path> files;
    try(Stream<Path> paths = Files.walk(root)) { files = paths.filter(p->p.toString().endsWith(".puml")).sorted().collect(Collectors.toList()); }
    List<String> result = new ArrayList<>();
    for(Path p : files) result.add(fixture(root,p));
    Files.writeString(Path.of(args[1]),"{\"plantuml\":" + q(net.sourceforge.plantuml.version.Version.versionString()) + ",\"fixtures\":[\n" + String.join(",\n",result) + "\n]}\n", StandardCharsets.UTF_8);
  }
}
