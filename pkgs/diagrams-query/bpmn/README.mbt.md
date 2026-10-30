# moonrockz/diagrams-query/bpmn

The opt-in query adapter for the immutable BPMN document tree of
`moonrockz/bpmn`. `moonrockz/bpmn` does not depend on this package; a
reader-only consumer keeps its core-only imports.

`BpmnTree::new(tree)` indexes a `DocumentTree` once without copying the
document. Adapter node `i` is the node whose `NodeHandle.ordinal` is `i`.
`captured` and `node` return the original `NodeRef`, so a capture has the same
revision, handle, path, attributes and optional location as the existing
traversal. `index` returns `None` for a node of another revision.

## Schema `moonrockz/bpmn-document-tree` version 1

| Part | Contents |
| --- | --- |
| Kinds | Every non-abstract element of the frozen OMG BPMN, BPMN DI, DC and DI schemas (`schema_elements`) |
| Fields | Every child field name of `schema_fields`, every element name (a child that matches no schema field is in the field of its own name) and the structural fields `text`, `comment`, `processing-instruction`, `root`, `prolog` and `epilog` in `urn:moonrockz:bpmn:tree` |
| Categories | `document`, `definitions`, `process`, `activity`, `event`, `gateway`, `sequence-flow`, `collaboration`, `participant`, `lane`, `choreography`, `choreography-activity`, `conversation`, `conversation-link`, `diagram-interchange`, `extension`, `other`, `text`, `comment`, `processing-instruction` |
| Reserved namespaces | BPMN MODEL, BPMN DI, DC, DI and `urn:moonrockz:bpmn:tree` |
| Extensions | Any other namespace is open: its names compile even when no document contains them |
| Scalar tags | `text`, `identifier`, `uri`, `boolean`, `integer`, `number`, `reference`, `enumeration`, `invalid` |
| Extra fields | `id` (the schema ID of `NodeRef::id`) |

`default_namespaces` binds `bpmn`, `bpmndi`, `dc`, `di` and `tree`; `compile`
adds them to your bindings. Attribute values compare by `Scalar::token`.
`#text-eq?` reads text and comment content, processing-instruction data and
element simple content. The adapter does not synthesize defaults or source
spans: constructed documents have no locations. Document, text, comment and
processing-instruction nodes are queryable by category.

```mbt check
///|
test "query a BPMN document" {
  let source =
    #|<definitions xmlns="http://www.omg.org/spec/BPMN/20100524/MODEL" targetNamespace="urn:t">
    #|  <process id="P">
    #|    <userTask id="A" name="Approve"/>
    #|    <subProcess id="S"><userTask id="B" name="Approve"/></subProcess>
    #|  </process>
    #|</definitions>
  let document = @model.read(source).document.unwrap()
  let tree = @bpmn.BpmnTree::new(@model.DocumentTree::new(document).tree.unwrap())
  // All candidate roots are searched, so the nested task matches too.
  let named = @bpmn.compile(
    "((bpmn.userTask) @task (#attr-eq? @task \"name\" \"Approve\"))",
  ).unwrap()
  let ids = named.collect(tree).matches.map(m => tree.captured(m.captures[0]).id())
  assert_eq(ids.iter().to_array(), [Some("A"), Some("B")])
  // A field pattern constrains direct children only.
  let direct = @bpmn.compile(
    "(bpmn.process bpmn.flowElement: (bpmn.userTask) @task) @process",
  ).unwrap()
  let rows = direct.collect(tree).matches
  assert_eq(rows.length(), 1)
  assert_eq(tree.captured(rows[0].captures[0]).id(), Some("A"))
  // Captured handles are graph endpoints without string IDs.
  let graph = @model.DocumentGraph::new(document).graph.unwrap()
  let task = tree.captured(rows[0].captures[0])
  assert_true(graph.lookup(Node(task.handle())) is Ok(Document(_)))
}
```
