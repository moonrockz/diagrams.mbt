///|
test "printer uses typed values after AST edits and ignores stale source spelling" {
 let source="swimlane-beta LR\nsubgraph Owner [Original group]\ndirection TB\nA[Original label]\nend\nA edge@-->|old edge| B"
 let original=@syntax.read(source).ast.unwrap()
 let statements=original.statements.iter().to_array()
 guard statements[0].kind is Subgraph(id~,..) else { fail("group required") }
 statements[0]={..statements[0],kind:Subgraph(id~,label="Changed group")}
 statements[1]={..statements[1],kind:Direction("RL")}
 guard statements[2].kind is Nodes(nodes) else { fail("nodes required") }
 statements[2]={..statements[2],kind:Nodes([{..nodes[0],label:Some("Changed label 😀")}])}
 guard statements[4].kind is Edges(chain) else { fail("chain required") }
 statements[4]={..statements[4],kind:Edges({..chain,links:[{..chain.links[0],label:"changed edge"}]})}
 let updated=@ast.Diagram::new(statements[:],direction="BT")
 let output=print(updated).output.unwrap()
 assert_true(output.contains("Changed label 😀"))
 assert_true(output.contains("Changed group"))
 assert_true(output.contains("direction RL"))
 assert_true(output.contains("changed edge"))
 assert_true(!output.contains("Original"))
 assert_eq(@syntax.read(output).ast,Some(updated))
 assert_eq(print(@syntax.read(output).ast.unwrap()).output,Some(output))
}
///|
test "printer limits bound constructed path lengths and output" {
 let original=@syntax.read("swimlane-beta\nA --> B").ast.unwrap()
 let statement=original.statements[0]
 guard statement.kind is Edges(chain) else { fail("chain required") }
 let huge={..statement,kind:Edges({..chain,links:[{..chain.links[0],length:2147483647}]})}
 let ast=@ast.Diagram::new([huge])
 assert_eq(print(ast).output,None)
 assert_eq(print(original,limits=@syntax.Limits::new(output=10)).output,None)
 assert_eq(print(original,limits=@syntax.Limits::new(work=0)).output,None)
}
