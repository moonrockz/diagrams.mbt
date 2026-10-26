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
const docs = await readFile(new URL('../upstream/zenuml.md', import.meta.url), 'utf8');
const examples = [...docs.matchAll(/```mermaid-example\n([\s\S]*?)\n```/g)].map((m,i) => ({id:`docs-${i+1}`,source:m[1]}));
examples.push(
 {id:'nested-return',source:'zenuml\nClient->A.method() {\n B.nested() {\n return result\n }\n return done\n}'},
 {id:'assignments',source:'zenuml\na = A.foo()\nSomeType b = B.bar(x, y)'},
 {id:'multi-catch',source:'zenuml\ntry {\n A->B: work\n} catch(one) {\n B->A: first\n} catch(two) {\n B->A: second\n} finally {\n A->B: clean\n}'},
 {id:'reply',source:'zenuml\nA->B: request\n@reply\nB->A: response'},
 {id:'loops',source:'zenuml\nforEach(item in items) {\nA->B: iterate\n}\nforeach(item in items) {\nA->B: next\n}\nloop(3) {\nA->B: last\n}'},
);
const results=[];
for(const example of examples) {
 const ctx=RootContext(example.source.replace(/^zenuml\s*\n/,''));
 const participants=OrderedParticipants(ctx).map((p:any)=>({id:p.name,label:p.label??p.name,type:p.type??null}));
 const messages:any[]=[]; const returns:any[]=[];
 for (const m of walkStatements(ctx)) {
  while(returns.length && m.depth <= returns.at(-1).depth) {const r=returns.pop(); messages.push(r.message)}
  if(!['sync','async','creation','return'].includes(m.kind)) continue;
  messages.push({from:m.from,to:m.to,label:m.label,kind:m.kind});
  const assignment=(m.statNode?.message?.()??m.statNode?.creation?.())?.Assignment?.();
  if(assignment?.assignee && !m.isSelf) returns.push({depth:m.depth,message:{from:m.to,to:m.from,label:assignment.assignee,kind:'assignment-return'}});
 }
 while(returns.length) messages.push(returns.pop().message);
 results.push({...example,participants,messages});
}
await writeFile(destination,JSON.stringify({reference:{plugin:'1.0.1',core:'3.47.9',commit:'e3f93e0eb65d23fa3520e8691a5bca883853aa4b',extractor:'RootContext + OrderedParticipants + walkStatements + Assignment'},examples:results},null,2)+'\n');

// Check canonical native output against the independent upstream grammar.
if(process.argv[4]) {
 const canonical=JSON.parse(await readFile(process.argv[4],'utf8'));
 for(const [id,text] of canonical) {
  parser.Errors.length=0; parser.ErrorDetails.length=0;
  RootContext(text.replace(/^zenuml\s*\n/,''));
  if(parser.ErrorDetails.length) throw new Error(`${id}: canonical output rejected: ${JSON.stringify(parser.ErrorDetails)}`);
 }
}
