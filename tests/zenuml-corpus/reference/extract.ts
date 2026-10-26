// Independent semantic oracle. Run only against the pinned ZenUML source commit.
// Usage: bun --tsconfig-override=<source>/tsconfig.app.json extract.ts <source> <output>
import { join } from 'node:path';
import { readFile, writeFile } from 'node:fs/promises';
const source = process.argv[2];
const destination = process.argv[3];
if (!source || !destination) throw new Error('Expected pinned source root and output path');
const {RootContext,default: parser} = await import(join(source, 'src/parser/index.js'));
const {OrderedParticipants} = await import(join(source, 'src/parser/OrderedParticipants.ts'));
const {walkStatements} = await import(join(source, 'src/svg/walkStatements.ts'));
const {createStatementKey} = await import(join(source, 'src/positioning/vertical/StatementIdentifier.ts'));
const docs = await readFile(new URL('../upstream/zenuml.md', import.meta.url), 'utf8');
const examples = [...docs.matchAll(/```mermaid-example\n([\s\S]*?)\n```/g)].map((m,i) => ({id:`docs-${i+1}`,source:m[1]}));
examples.push(
 {id:'nested-return',source:'zenuml\nClient->A.method() {\n B.nested() {\n return result\n }\n return done\n}'},
 {id:'assignments',source:'zenuml\na = A.foo()\nSomeType b = B.bar(x, y)'},
 {id:'multi-catch',source:'zenuml\ntry {\n A->B: work\n} catch(one) {\n B->A: first\n} catch(two) {\n B->A: second\n} finally {\n A->B: clean\n}'},
 {id:'reply',source:'zenuml\nA->B: request\n@reply\nB->A: response'},
 {id:'loops',source:'zenuml\nforEach(item in items) {\nA->B: iterate\n}\nforeach(item in items) {\nA->B: next\n}\nloop(3) {\nA->B: last\n}'},
 {id:'async-payload-punctuation',source:'zenuml\nA->B: https://unit.invalid/v1; retain // literal comment\nA->B: literal "unclosed quote; } { %%{not metadata}%%\nA->B: don\'t reinterpret `ticks` or punctuation; keep all text\nB->A: next'},
 {id:'quoted-call-return-creation',source:'zenuml\nClient->API.send("Hello, world", "two  spaces", "(x) ; . ,") {\nreturn "done, now  please"\n}\nnew Worker("queue, east", "two  spaces")'},
 {id:'quoted-reply',source:'zenuml\nA->B: request\n@reply\nB->A: "Hello, world; two  spaces"'},
 {id:'doubled-quote-literals',source:'zenuml\nA.send("say ""hi, friend""  now", "left  right")'},
);
const results=[];
for(const example of examples) {
 parser.Errors.length=0; parser.ErrorDetails.length=0;
 const ctx=RootContext(example.source.replace(/^zenuml\s*\n/,''));
 if(parser.ErrorDetails.length) throw new Error(`${example.id}: source rejected: ${JSON.stringify(parser.ErrorDetails)}`);
 // Use the pinned grammar's actual statement nodes, including returns and async
 // messages whose renderer projection does not retain statNode.
 const nativeStatements=new Map(); const pending=[ctx];
 while(pending.length) {
  const node=pending.pop();
  if(node?.constructor?.name==='StatContext') nativeStatements.set(createStatementKey(node),node);
  for(const child of node?.children??[]) pending.push(child);
 }
 const participants=OrderedParticipants(ctx).map((p:any)=>({id:p.name,label:p.label??p.name,type:p.type??null}));
 const messages:any[]=[]; const returns:any[]=[];
 for (const m of walkStatements(ctx)) {
  while(returns.length && m.depth <= returns.at(-1).depth) {const r=returns.pop(); messages.push(r.message)}
  if(!['sync','async','creation','return'].includes(m.kind)) continue;
  const native=m.statNode??nativeStatements.get(m.key);
  // Upstream's presentation formatter rewrites punctuation and whitespace even
  // inside CSTRING tokens. Our preservation contract uses ANTLR token text for
  // quoted expression contents, while the renderer projection remains the
  // independent oracle for message order, endpoints, kind and scope.
  let tokenLabel:string|undefined;
  if(m.kind==='sync') {
   const signatures=native?.message?.()?.messageBody?.()?.func?.()?.signature?.()??[];
   const text=signatures.map((part:any)=>part.getText()).join('.');
   if(text.includes('"')) tokenLabel=text;
  } else if(m.kind==='creation') {
   const parameters=native?.creation?.()?.creationBody?.()?.parameters?.()?.parameter?.()??[];
   const text=parameters.map((part:any)=>part.getText()).join(',');
   if(text.includes('"')) tokenLabel=`«${text}»`;
  } else if(m.kind==='return') {
   const ret=native?.ret?.();
   const text=ret?.expr?.()?.getText?.()??(ret?.asyncMessage?.()??ret?.returnAsyncMessage?.())?.content?.()?.getText?.();
   if(text?.includes('"')) tokenLabel=text.trim();
  }
  messages.push({from:m.from,to:m.to,label:tokenLabel??m.label,kind:m.kind,...(tokenLabel===undefined?{}:{labelSource:'antlr-token-text',upstreamDisplayLabel:m.label})});
  const assignment=(native?.message?.()??native?.creation?.())?.Assignment?.();
  if(assignment?.assignee && !m.isSelf) returns.push({depth:m.depth,message:{from:m.to,to:m.from,label:assignment.assignee,kind:'assignment-return'}});
 }
 while(returns.length) messages.push(returns.pop().message);
 results.push({...example,participants,messages});
}
await writeFile(destination,JSON.stringify({reference:{plugin:'1.0.1',core:'3.47.9',commit:'e3f93e0eb65d23fa3520e8691a5bca883853aa4b',extractor:'RootContext + OrderedParticipants + walkStatements + Assignment',quotedLiteralOracle:'Pinned ANTLR signature/parameter/expr token text preserves CSTRING contents; renderer display normalization is recorded separately when it differs'},examples:results},null,2)+'\n');

// Check canonical native output against the independent upstream grammar.
if(process.argv[4]) {
 const canonical=JSON.parse(await readFile(process.argv[4],'utf8'));
 for(const [id,text] of canonical) {
  parser.Errors.length=0; parser.ErrorDetails.length=0;
  RootContext(text.replace(/^zenuml\s*\n/,''));
  if(parser.ErrorDetails.length) throw new Error(`${id}: canonical output rejected: ${JSON.stringify(parser.ErrorDetails)}`);
 }
}
