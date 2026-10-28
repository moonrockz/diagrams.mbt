///|
let state_mermaid_lifecycle : String = (
    #|stateDiagram-v2
    #|[*] --> Idle
    #|Idle --> Running : start
    #|Running --> Running : retry
    #|Running --> [*]
  ) +
  "\n"

///|
let state_mermaid_choice : String = (
    #|stateDiagram-v2
    #|    [*] --> Review
    #|    state Review {
    #|        [*] --> Draft
    #|        Draft --> Decision : submit
    #|        state Decision <<choice>>
    #|        Decision --> Approved : accepted
    #|        Decision --> Draft : revise
    #|        Approved --> [*]
    #|    }
    #|    Review --> Published : publish
    #|    Published --> [*]
  ) +
  "\n"

///|
let state_mermaid_concurrent : String = (
    #|stateDiagram-v2
    #|    [*] --> Work
    #|    state Work {
    #|        state Fork <<fork>>
    #|        state Join <<join>>
    #|        [*] --> Fork
    #|        Fork --> Validate
    #|        Fork --> Package
    #|        Validate --> Join
    #|        Package --> Join
    #|        Join --> [*]
    #|        --
    #|        [*] --> Monitor
    #|        Monitor --> Monitor : sample
    #|    }
    #|    Work --> [*]
  ) +
  "\n"

///|
let state_plantuml_lifecycle : String = (
    #|@startuml
    #|state "Ready" as Ready
    #|state Running
    #|[*] --> Ready
    #|Ready : entry / prepare
    #|Ready : tick [pending] / wait
    #|Ready --> Running : start
    #|Running --> Running : tick
    #|Running --> [*] : finish
    #|note right of Ready
    #|Descriptions are data.
    #|No actions execute.
    #|end note
    #|@enduml
  ) +
  "\n"

///|
let state_plantuml_composite : String = (
    #|@startuml
    #|state Session {
    #|  state Enter <<entryPoint>>
    #|  state Active
    #|  state Leave <<exitPoint>>
    #|  [*] --> Enter
    #|  Enter --> Active : begin
    #|  Active --> Leave : done
    #|}
    #|state Recovery {
    #|  state Waiting
    #|  state Complete
    #|  [*] --> Waiting
    #|  Waiting --> Complete
    #|}
    #|Session.Active --> Recovery.Waiting : recover
    #|Recovery.Complete --> Session.Active : retry
    #|@enduml
  ) +
  "\n"

///|
let state_plantuml_history : String = (
    #|@startuml
    #|state Service {
    #|  state Worker
    #|  [*] --> Worker
    #|  Worker --> Worker : work
    #|  --
    #|  state Monitor
    #|  [*] --> Monitor
    #|  Monitor --> Monitor : check
    #|}
    #|state Paused
    #|[*] --> Service
    #|Service --> Paused : pause
    #|Paused --> Service[H] : resume
    #|Paused --> Service[H*] : deep resume
    #|@enduml
  ) +
  "\n"
