///|
fn xml_errors(r : @bpmn.ReadResult) -> Array[String] { r.diagnostics.filter(d => d.code.has_prefix("xml/")).map(d => d.code).iter().to_array() }

///|
fn partition(source : String, r : @bpmn.ReadResult) -> Unit raise {
  assert_eq(r.tree.text(), source)
  let mut end = 0
  for token in r.tree.tokens {
    assert_eq(token.span.start, end)
    assert_eq(token.text, source[token.span.start:token.span.end].to_owned())
    assert_true(token.span.end > token.span.start)
    end = token.span.end
  }
  assert_eq(end, source.length())
}

///|
test "complete lexical source preserves declarations, comments, PI, CDATA and mixed content" {
  let source = "\uFEFF<?xml version='1.0' encoding=\"utf-8\"?>\r\n<!-- prolog --><?inspect a='b'?>\r\n<r xmlns='urn:r' xmlns:p='urn:p' p:a='&quot;&#x1F600;&#13;' plain=\"a\r\nb\tc\">left &amp; <![CDATA[<raw>&\r\n]]><p:child/>right&#10;</r><!-- tail -->"
  let r = @bpmn.read(source)
  partition(source, r)
  assert_true(r.tree.complete)
  assert_eq(xml_errors(r), [])
  let elements = r.tree.nodes.filter(n => n.kind == Element).iter().to_array()
  let root = elements[0]
  assert_eq(root.name.unwrap().namespace_uri, "urn:r")
  assert_eq(root.attributes[2].name.namespace_uri, "urn:p")
  assert_eq(root.attributes[2].value, "\"😀\r")
  assert_eq(root.attributes[3].name.namespace_uri, "")
  assert_eq(root.attributes[3].value, "a b c")
  let content = root.children.map(i => r.tree.nodes[i].kind).iter().to_array()
  assert_eq(content, [Text, CData, Element, Text])
  assert_eq(r.tree.nodes[root.children[1]].value, "<raw>&\n")
  assert_eq(r.tree.tokens.filter(t => t.kind == CharacterReference).length(), 5)
  assert_eq(r.tree.tokens.filter(t => t.kind == Declaration).length(), 1)
  assert_eq(r.tree.nodes.filter(n => n.kind == Comment).length(), 2)
  assert_eq(r.tree.nodes.filter(n => n.kind == ProcessingInstruction).length(), 1)
}

///|
test "namespace aliases give equal minimal typed BPMN values" {
  let a = "<b:definitions xmlns:b='http://www.omg.org/spec/BPMN/20100524/MODEL' targetNamespace='urn:t'><b:process id='P'><b:task name='A &amp; B 😀'/></b:process></b:definitions>"
  let b = a.replace(old="xmlns:b=", new="xmlns:z=").replace_all(old="b:", new="z:")
  let x = @bpmn.read(a)
  let y = @bpmn.read(b)
  assert_eq(x.diagnostics.length(), 0)
  assert_eq(y.document, x.document)
  partition(a, x); partition(b, y)
}

///|
test "namespace scopes restore and default namespaces never apply to ordinary attributes" {
  let source = "<r xmlns='urn:a' xmlns:p='urn:p'><s xmlns='' xmlns:p='urn:q' p:a='1' a='2'/><p:t/></r>"
  let r = @bpmn.read(source)
  assert_eq(xml_errors(r), [])
  let elements = r.tree.nodes.filter(n => n.kind == Element).iter().to_array()
  assert_eq(elements[1].name.unwrap().namespace_uri, "")
  assert_eq(elements[1].attributes[2].name.namespace_uri, "urn:q")
  assert_eq(elements[1].attributes[3].name.namespace_uri, "")
  assert_eq(elements[2].name.unwrap().namespace_uri, "urn:p")
  let xml = @bpmn.read("<r xml:lang='en'/>")
  assert_eq(xml_errors(xml), [])
  assert_eq(xml.tree.nodes[1].attributes[0].name.namespace_uri, "http://www.w3.org/XML/1998/namespace")
}

///|
test "duplicate expanded attributes point at the second spelling" {
  let source = "<r xmlns:p='urn:x' xmlns:q='urn:x' p:a='1' q:a='2'/>"
  let r = @bpmn.read(source)
  assert_eq(xml_errors(r), ["xml/duplicate-attribute"])
  assert_eq(r.document, None)
  let span = r.diagnostics[0].span.unwrap()
  assert_eq(source[span.start:span.end], "q:a='2'")
  partition(source, r)
}

///|
test "recovery finds later tag errors and restores namespaces" {
  let source = "<r xmlns:p='urn:a'><s xmlns:p='urn:b'></wrong></s><p:t/><x:bad a=unquoted/></r>"
  let r = @bpmn.read(source)
  partition(source, r)
  assert_false(r.tree.complete)
  assert_eq(r.document, None)
  assert_true(xml_errors(r).contains("xml/mismatched-tag"))
  assert_true(xml_errors(r).contains("xml/invalid-tag"))
  assert_eq(r.tree.nodes.filter(n => n.raw_name == "p:t")[0].name.unwrap().namespace_uri, "urn:a")
  let r = @bpmn.read("<r><s></r><t></u>")
  assert_eq(r.document, None)
  assert_true(r.diagnostics.length() >= 3)
  assert_true(r.tree.nodes.iter().any(n => n.kind == Error))
}

///|
test "UTF-16 source maps count CRLF once and supplementary characters twice" {
  let source = "<r>\r\n😀<p:x/>\r\n</r>"
  let r = @bpmn.read(source, source_id="memory:test")
  assert_eq(xml_errors(r), ["xml/undeclared-prefix"])
  partition(source, r)
  let d = r.diagnostics[0]
  let location = d.location.unwrap()
  assert_eq(location.source_id, Some("memory:test"))
  assert_eq(location.start.line, 2)
  assert_eq(location.start.column, 4)
  assert_eq(source[d.span.unwrap().start:d.span.unwrap().end], "p:x")
  let map = r.source_map.unwrap()
  assert_eq(map.position(source.length()).unwrap().line, 3)
  assert_eq(map.position(-1), None)
  assert_eq(map.position(source.length()+1), None)
  assert_eq(@bpmn.read("<r/>\r").source_map.unwrap().position(5).unwrap().line, 2)
}

///|
test "numeric references accept XML scalars and reject invalid, overflowing and external entities" {
  let valid = @bpmn.read("<r a='&#9;&#10;&#13;&#x1F600;&#1114111;'>&lt;&gt;&amp;&quot;&apos;</r>")
  assert_eq(xml_errors(valid), [])
  assert_eq(valid.tree.nodes[1].attributes[0].value, "\t\n\r😀\u{10ffff}")
  for value in ["&#0;", "&#xD800;", "&#x110000;", "&#999999999999999999999;", "&#x;", "&#X41;", "&missing;", "&amp", "&&;"] {
    let source = "<r>\{value}</r>"
    let r = @bpmn.read(source)
    assert_true(xml_errors(r).contains("xml/character-reference"), msg=value)
    assert_eq(r.document, None)
    partition(source, r)
  }
}

///|
test "syntax rejects malformed comments, PI, CDATA, names, values, root content and bindings" {
  for (source, code) in [
    ("<!-- x--y --><r/>", "xml/invalid-comment"),
    ("<!-- missing", "xml/unclosed-comment"),
    ("<r><![CDATA[missing</r>", "xml/unclosed-cdata"),
    ("<![CDATA[x]]><r/>", "xml/outside-root"),
    ("<?XML?><r/>", "xml/invalid-pi"),
    ("<?missing<r/>", "xml/unclosed-pi"),
    ("<1bad/>", "xml/invalid-name"),
    ("<a:b:c/>", "xml/invalid-name"),
    ("<r a='a' a='b'/>", "xml/duplicate-attribute"),
    ("<r a='x'b='y'/>", "xml/invalid-tag"),
    ("<r>]]></r>", "xml/cdata-close"),
    ("<r>\u0001</r>", "xml/invalid-character"),
    ("<r/>text", "xml/outside-root"),
    ("<r/><s/>", "xml/root-required"),
    (" ", "xml/root-required"),
    ("<r xmlns:p=''/>", "xml/invalid-namespace"),
    ("<r xmlns:xml='urn:wrong'/>", "xml/invalid-namespace"),
    ("<r xmlns:other='http://www.w3.org/XML/1998/namespace'/>", "xml/invalid-namespace"),
    ("<r xmlns='http://www.w3.org/2000/xmlns/'/>", "xml/invalid-namespace"),
    ("<r p:a='1'/>", "xml/undeclared-prefix"),
    ("<r xmlns:p='a' xmlns:p='b'/>", "xml/duplicate-attribute"),
  ] {
    let r = @bpmn.read(source)
    partition(source, r)
    assert_false(r.tree.complete, msg=source)
    assert_eq(r.document, None)
    assert_true(xml_errors(r).contains(code), msg=source)
  }
  assert_true(@bpmn.read("<𐀀/>").tree.complete)
}

///|
test "encoding declarations are explicit and resource-looking declarations never resolve" {
  for source in ["<?xml version='1.0' encoding='UTF-8'?><r/>", "<?xml version='1.0' encoding='US-ASCII' standalone='no'?><r/>"] {
    assert_eq(xml_errors(@bpmn.read(source)), [])
  }
  for (source, code) in [
    ("<?xml version='1.0' encoding='UTF-16'?><r/>", "xml/encoding"),
    ("<?xml version='1.0' encoding='US-ASCII'?><r>😀</r>", "xml/encoding"),
    ("<?xml version='1.1'?><r/>", "xml/invalid-declaration"),
    (" <?xml version='1.0'?><r/>", "xml/invalid-declaration"),
    ("<?xml encoding='utf-8' version='1.0'?><r/>", "xml/invalid-declaration"),
    ("<!DOCTYPE r SYSTEM 'file:///must-not-read'><r/>", "xml/prohibited-declaration"),
    ("<!DOCTYPE r [<!ENTITY e SYSTEM 'http://127.0.0.1:1/no'>]><r>&e;</r>", "xml/prohibited-declaration"),
    ("<!ENTITY e SYSTEM 'file:///secret'><r/>", "xml/prohibited-declaration"),
  ] {
    let r = @bpmn.read(source)
    partition(source, r)
    assert_true(xml_errors(r).contains(code), msg=source)
    assert_eq(r.document, None)
  }
}

///|
test "source, token, node, attribute, depth and finding limits have inclusive boundaries" {
  let simple = "<r/>"
  assert_true(@bpmn.read(simple, limits=@bpmn.Limits::new(source_units=4, nodes=2, depth=1, token_units=2)).tree.complete)
  let cases = [
    (simple, @bpmn.Limits::new(source_units=3), "xml/source-limit"),
    (simple, @bpmn.Limits::new(nodes=1), "xml/node-limit"),
    ("<r a='x'/>", @bpmn.Limits::new(nodes=2), "xml/node-limit"),
    ("<r>abc</r>", @bpmn.Limits::new(token_units=2), "xml/token-limit"),
    ("<r a='abc'/>", @bpmn.Limits::new(token_units=2), "xml/token-limit"),
    ("<r><s/></r>", @bpmn.Limits::new(depth=1), "xml/depth-limit"),
    ("<r><a></bad><b></wrong></r>", @bpmn.Limits::new(diagnostics=2), "xml/diagnostic-limit"),
    (simple, @bpmn.Limits::new(depth=0), "xml/invalid-limits"),
  ]
  for (source, limits, code) in cases {
    let r = @bpmn.read(source, limits~)
    partition(source, r)
    assert_eq(r.document, None)
    assert_true(xml_errors(r).contains(code), msg=source)
    assert_true(r.diagnostics.length() <= limits.diagnostics)
  }
  assert_true(@bpmn.read("<r a='x'/>", limits=@bpmn.Limits::new(nodes=3)).tree.complete)
  assert_true(@bpmn.read("<r>abc</r>", limits=@bpmn.Limits::new(token_units=3)).tree.complete)
  assert_true(@bpmn.read("<r><s/></r>", limits=@bpmn.Limits::new(depth=2)).tree.complete)
  assert_eq(@bpmn.read("<r></bad></r>", limits=@bpmn.Limits::new(diagnostics=1)).diagnostics.length(), 1)
}

///|
test "small malformed sources preserve partition laws without a parser progress failure" {
  let pieces = ["<", ">", "/", "'", "\"", "&", ";", "=", "a", " ", "\r\n", "😀"]
  for a in pieces { for b in pieces { for c in pieces {
    let source = a+b+c
    partition(source, @bpmn.read(source))
    partition(source, @bpmn.read(source, limits=@bpmn.Limits::new(nodes=2, token_units=2, diagnostics=2)))
  } } }
}

///|
test "configured depth uses a parser stack and CST indexes rather than host recursion" {
  let source = "<r>".repeat(5000) + "</r>".repeat(5000)
  let r = @bpmn.read(source, limits=@bpmn.Limits::new(depth=5000))
  assert_true(r.tree.complete)
  assert_eq(r.tree.nodes.length(), 5001)
  partition(source, r)
  let rejected = @bpmn.read(source)
  assert_false(rejected.tree.complete)
  assert_true(xml_errors(rejected).contains("xml/depth-limit"))
  partition(source, rejected)
}

///|
test "limit rejection keeps source identity without building an oversized map" {
  let r = @bpmn.read("<r/>", source_id="memory:large", limits=@bpmn.Limits::new(source_units=3))
  assert_eq(r.source_map, None)
  assert_eq(r.diagnostics[0].location.unwrap().source_id, Some("memory:large"))
  assert_eq(r.diagnostics[0].location.unwrap().start.line, 1)
  let invalid = @bpmn.read("<r/>", limits=@bpmn.Limits::new(diagnostics=0))
  assert_eq(invalid.diagnostics[0].code, "xml/invalid-limits")
  assert_eq(invalid.diagnostics[0].span, None)
  for source in ["<r>😀</r>", "<😀/>a", "<r a='😀'/>", "<?p 😀?><r/>", "<!--😀--><r/>"] {
    partition(source, @bpmn.read(source, limits=@bpmn.Limits::new(token_units=2)))
  }
}

///|
test "namespace declarations apply to the whole tag even when written after use" {
  let r = @bpmn.read("<p:r p:a='1' xmlns:p='urn:p'/>")
  assert_true(r.tree.complete)
  assert_eq(r.tree.nodes[1].name.unwrap().namespace_uri, "urn:p")
  assert_eq(r.tree.nodes[1].attributes[0].name.namespace_uri, "urn:p")
}

///|
test "physical whitespace normalization differs from referenced whitespace" {
  let r = @bpmn.read("<r a='x\r\ny\rz\tw&#13;&#10;&#9;'/>")
  assert_true(r.tree.complete)
  assert_eq(r.tree.nodes[1].attributes[0].value, "x y z w\r\n\t")
}

///|
test "reads have independent namespace and recovery state" {
  let first = @bpmn.read("<p:r xmlns:p='urn:first'/>")
  let second = @bpmn.read("<p:r xmlns:p='urn:second'/>")
  let third = @bpmn.read("<p:r/>")
  assert_eq(first.tree.nodes[1].name.unwrap().namespace_uri, "urn:first")
  assert_eq(second.tree.nodes[1].name.unwrap().namespace_uri, "urn:second")
  assert_eq(xml_errors(third), ["xml/undeclared-prefix"])
}

///|
test "supplementary name characters bind prefixes using UTF-16 source offsets" {
  let source = "<𐀀:r xmlns:𐀀='urn:unicode' 𐀀:a='1'/>"
  let r = @bpmn.read(source)
  partition(source, r)
  assert_true(r.tree.complete)
  assert_eq(r.tree.nodes[1].name.unwrap().namespace_uri, "urn:unicode")
  assert_eq(r.tree.nodes[1].attributes[1].name.local_name, "a")
  assert_eq(r.tree.nodes[1].attributes[1].name.namespace_uri, "urn:unicode")
}
