// Exact portable source fixtures. scripts/gallery.mbtx checks these against site/examples/flowcharts.

///|
let flowchart_mermaid_review : String = "---\ntitle: Request review\n---\nflowchart LR\n  accTitle: Request validation and retry\n  accDescr: Structural branches and a return path, without condition evaluation\n  subgraph Intake\n    subgraph Validation\n      Read[Read request] --> Complete{Complete?}\n    end\n  end\n  Complete -->|yes| Save[Save]\n  Complete -->|no| Read\n  Save --> Notify[Notify]\n  Inspect[Manual inspection]\n"

///|
let flowchart_plantuml_modern : String = "@startuml\ntitle Order review\n|Customer|\nstart\npartition Request {\n:Submit order;\n}\n|Service|\nrepeat\n:Review;\nrepeat while (Retry?) is (yes) not (no)\nfork\n:Save;\nfork again\n:Notify;\nend fork\nstop\n@enduml\n"

///|
let flowchart_plantuml_legacy : String = "@startuml\ntitle Request handling\npartition Intake {\n(*) --> \"Read request\" as R\n}\nif \"Valid?\" then\n-->[yes] \"Process\" as P\nP --> \"Complete\" as Done\nelse\n-->[no] \"Reject\"\n--> Done\nendif\nDone --> (*)\n@enduml\n"
