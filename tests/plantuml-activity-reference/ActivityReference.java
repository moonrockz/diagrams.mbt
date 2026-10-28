// Test-only PlantUML 1.2026.9 activity structure adapter. No MoonBit conversion.
import java.nio.file.*;
import java.lang.reflect.*;
import java.util.*;
import net.sourceforge.plantuml.*;
import net.sourceforge.plantuml.core.Diagram;
import net.sourceforge.plantuml.error.PSystemError;
import net.sourceforge.plantuml.abel.*;
import net.sourceforge.plantuml.activitydiagram.ActivityDiagram;
import net.sourceforge.plantuml.klimt.creole.Display;
import net.sourceforge.plantuml.activitydiagram3.LinkRendering;

class ActivityReference {
  static String q(Object value) {
    String s=String.valueOf(value); StringBuilder b=new StringBuilder("\"");
    for(char c:s.toCharArray()) { switch(c) {case '\\':b.append("\\\\");break;case '"':b.append("\\\"");break;case '\n':b.append("\\n");break;case '\r':b.append("\\r");break;case '\t':b.append("\\t");break;default:if(c<32)b.append(String.format("\\u%04x",(int)c));else b.append(c);} }
    return b.append('"').toString();
  }
  static String value(Object v) {
    if(v instanceof LinkRendering link) return value(link.getDisplay());
    if(v instanceof Display display) { if(Display.isNull(display))return q("");List<String> lines=new ArrayList<>();for(CharSequence line:display)lines.add(line.toString());return q(String.join("\n",lines)); }
    return q(v);
  }
  static Object field(Object o,String name) throws Exception {
    for(Class<?> c=o.getClass();c!=null;c=c.getSuperclass()) try {Field f=c.getDeclaredField(name);f.setAccessible(true);return f.get(o);}catch(NoSuchFieldException e){}
    return null;
  }
  static String tree(Object o,int depth) throws Exception {
    if(o==null)return "null";if(depth>256)throw new Exception("Reference depth exceeded");
    if(o instanceof Collection<?> values){List<String> out=new ArrayList<>();for(Object v:values)out.add(tree(v,depth+1));return "["+String.join(",",out)+"]";}
    String type=o.getClass().getSimpleName();List<String> parts=new ArrayList<>();parts.add("\"kind\":"+q(type));
    for(String name:List.of("activity","test","startLabel","labelTest","labelCase","label","name","backward","yes","out","labelPositive","inlabel","outColor","killed","style")) {Object v=field(o,name);if(v!=null)parts.add(q(name)+":"+value(v));}
    for(String name:List.of("all","thens","elseBranch","forks","splits","repeatList","list","switches","branches","specialOut")) {Object v=field(o,name);if(v!=null)parts.add(q(name)+":"+tree(v,depth+1));}
    return "{"+String.join(",",parts)+"}";
  }
  static String fixture(Path root,Path file) throws Exception {
    Diagram d=new SourceStringReader(Files.readString(file)).getBlocks().get(0).getDiagram();
    String prefix="{\"name\":"+q(root.relativize(file).toString().replace('\\','/'))+",\"class\":"+q(d.getClass().getSimpleName());
    if(d instanceof PSystemError) return prefix+",\"status\":\"refused\",\"error\":"+q(((PSystemError)d).getErrorsUml().toString())+"}";
    if(d instanceof ActivityDiagram legacy){List<String> nodes=new ArrayList<>();Map<Entity,Integer> ids=new IdentityHashMap<>();for(Entity e:legacy.leafs()){ids.put(e,ids.size());nodes.add("{\"id\":"+(ids.size()-1)+",\"label\":"+value(e.getDisplay())+",\"role\":"+q(e.getLeafType())+"}");}List<String> edges=new ArrayList<>();for(Link l:legacy.getLinks())edges.add("{\"source\":"+ids.get(l.isInverted()?l.getEntity2():l.getEntity1())+",\"target\":"+ids.get(l.isInverted()?l.getEntity1():l.getEntity2())+",\"label\":"+value(l.getLabel())+"}");return prefix+",\"status\":\"accepted\",\"nodes\":["+String.join(",",nodes)+"],\"edges\":["+String.join(",",edges)+"]}";}
    Object lanes=field(d,"swimlanes");if(lanes==null)return prefix+",\"status\":\"non-activity\"}";
    return prefix+",\"status\":\"accepted\",\"instructions\":"+tree(field(lanes,"root"),0)+"}";
  }
  public static void main(String[] args)throws Exception{Path root=Path.of(args[0]);List<Path> files;try(var walk=Files.walk(root)){files=walk.filter(p->p.toString().endsWith(".puml")).sorted().toList();}List<String> out=new ArrayList<>();for(Path file:files)out.add(fixture(root,file));Files.writeString(Path.of(args[1]),"{\"plantuml\":"+q(net.sourceforge.plantuml.version.Version.versionString())+",\"fixtures\":[\n"+String.join(",\n",out)+"\n]}\n");}
}
