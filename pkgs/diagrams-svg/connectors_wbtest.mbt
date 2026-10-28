///|
fn crossing_fixture(
  first~ : String = "M20 70 L140 70",
  second~ : String = "M80 20 L80 140",
) -> @writer.Node {
  @writer.element("svg", attrs=[("width", "180"), ("height", "180")], children=[
    @writer.element(
      "g",
      attrs=[
        ("class", "flowchart-connection"),
        ("data-flowchart-id", "horizontal"),
        ("data-source", "a"),
        ("data-target", "b"),
      ],
      children=[
        @writer.element("path", attrs=[
          ("class", "flowchart-connector"),
          ("d", first),
          ("stroke", "#123456"),
          ("stroke-dasharray", "4 4"),
          ("marker-end", "url(#head)"),
        ]),
      ],
    ),
    @writer.element(
      "g",
      attrs=[
        ("class", "flowchart-connection"),
        ("data-flowchart-id", "vertical"),
        ("data-source", "c"),
        ("data-target", "d"),
      ],
      children=[
        @writer.element("path", attrs=[
          ("class", "flowchart-connector"),
          ("d", second),
          ("stroke", "#abcdef"),
          ("marker-end", "url(#head)"),
        ]),
      ],
    ),
    @writer.element("path", attrs=[
      ("class", "lifeline"),
      ("d", "M0 0 L180 180"),
    ]),
  ])
}

///|
test "default hop has a scoped transparent underpass and retained route identities" {
  let diagnostics = []
  let resolved = finalize_connectors(
    crossing_fixture(),
    ConnectorOptions::new(),
    diagnostics,
  ).unwrap()
  assert_eq(diagnostics, [])
  let output = @writer.to_string(resolved)
  let paths = inspect_connectors(output)
  assert_eq(paths.length(), 2)
  assert_eq(paths[0].id, "horizontal")
  assert_eq(paths[0].source, "a")
  assert_eq(paths[0].target, "b")
  assert_true(paths[0].mask is Some(_))
  assert_true(paths[1].mask is None)
  assert_eq(paths[1].route.svg(), "M80 20 L80 140")
  assert_true(paths[1].path.svg().contains("C"))
  assert_true(output.contains("stroke-dasharray=\"4 4\""))
  assert_true(output.contains("r=\"10\""))
  assert_true(!output.contains("fill=\"#020617\""))
  assert_eq(check_connectors(paths[:], [], width=180.0, height=180.0), [])
  inspect(
    output,
    content=(
      #|<svg width="180" height="180" data-connector-options="{&#xa;  style: None,&#xa;  crossing: Bridge,&#xa;  minimum_approach: 24,&#xa;  corner_radius: 8,&#xa;  bridge_radius: 5,&#xa;  style_supplied_bpmn: false,&#xa;  limits: {&#xa;    candidates: 2000000,&#xa;    subdivisions: 200000,&#xa;    segments: 100000,&#xa;    crossings: 10000,&#xa;    output_units: 16777216,&#xa;  },&#xa;}">
      #|  <g class="flowchart-connection" data-flowchart-id="horizontal" data-source="a" data-target="b">
      #|    <path class="flowchart-connector" d="M20 70 L140 70" stroke="#123456" stroke-dasharray="4 4" marker-end="url(#head)" data-connector-id="horizontal" data-connector-source="a" data-connector-target="b" data-connector-route="M20 70 L140 70" data-connector-key="0" mask="url(#connector-underpass-0)"/>
      #|  </g>
      #|  <g class="flowchart-connection" data-flowchart-id="vertical" data-source="c" data-target="d">
      #|    <path class="flowchart-connector" d="M80 20 L80 65 C80 67.5 85 67.5 85 70 C85 72.5 80 72.5 80 75 L80 140" stroke="#abcdef" marker-end="url(#head)" data-connector-id="vertical" data-connector-source="c" data-connector-target="d" data-connector-route="M80 20 L80 140" data-connector-key="1"/>
      #|  </g>
      #|  <path class="lifeline" d="M0 0 L180 180"/>
      #|  <defs>
      #|    <mask id="connector-underpass-0" maskUnits="userSpaceOnUse" x="0" y="0" width="180" height="180">
      #|      <rect x="0" y="0" width="180" height="180" fill="white"/>
      #|      <circle cx="80" cy="70" r="10" fill="black"/>
      #|    </mask>
      #|  </defs>
      #|</svg>
      #|
    ),
  )
}

///|
test "plain crossings preserve routes without masks" {
  let diagnostics = []
  let root = finalize_connectors(
    crossing_fixture(),
    ConnectorOptions::new(crossing=Plain),
    diagnostics,
  ).unwrap()
  let paths = inspect_connectors(@writer.to_string(root))
  assert_eq(paths.length(), 2)
  assert_true(paths.iter().all(p => p.path == p.route && p.mask is None))
  assert_eq(diagnostics, [])
}

///|
test "typed styles retain a full straight marked approach" {
  let original = ConnectorPath::parse("M20 20 L90 20 L90 110 L160 110").unwrap()
  for style in [Elbow, Rounded, Curved] {
    let styled = cstyle(
      original,
      ConnectorOptions::new(style~, minimum_approach=32.0),
      true,
      true,
    )
    let last = styled.commands[styled.commands.length() - 1]
    assert_eq(cend(last), ConnectorPoint::{ x: 160.0, y: 110.0, })
    let start = cend(styled.commands[styled.commands.length() - 2])
    assert_true(last is Line(_))
    assert_true(cdist(start, cend(last)) >= 32.0)
    if style == Elbow {
      assert_true(styled.commands.iter().all(c => c is Move(_) || c is Line(_)))
    }
    if style == Rounded {
      assert_true(styled.commands.iter().any(c => c is Quadratic(_, _)))
    }
    if style == Curved {
      assert_true(styled.commands.iter().any(c => c is Cubic(_, _, _)))
    }
  }
  assert_eq(original.svg(), "M20 20 L90 20 L90 110 L160 110")
}

///|
test "invalid options and each exhausted work budget refuse partial SVG" {
  for
    options in [
      ConnectorOptions::new(minimum_approach=-1.0),
      ConnectorOptions::new(corner_radius=0.0),
      ConnectorOptions::new(bridge_radius=0.0),
      ConnectorOptions::new(minimum_approach=1.0 / 0.0),
    ] {
    let diagnostics = []
    assert_true(
      finalize_connectors(crossing_fixture(), options, diagnostics) is None,
    )
    assert_eq(diagnostics[0].code, "connector/invalid-option")
  }
  for
    limits in [
      ConnectorLimits::new(candidates=0),
      ConnectorLimits::new(subdivisions=0),
      ConnectorLimits::new(segments=0),
      ConnectorLimits::new(crossings=0),
      ConnectorLimits::new(output_units=0),
    ] {
    let diagnostics = []
    assert_true(
      finalize_connectors(
        crossing_fixture(),
        ConnectorOptions::new(limits~),
        diagnostics,
      )
      is None,
    )
    assert_eq(diagnostics[0].code, "connector/limit")
  }
}

///|
test "endpoint contacts and real junctions are not bridges" {
  let diagnostics = []
  let root = finalize_connectors(
    crossing_fixture(first="M20 70 L80 70", second="M80 70 L80 140"),
    ConnectorOptions::new(),
    diagnostics,
  ).unwrap()
  assert_true(!@writer.to_string(root).contains("<mask"))
  assert_eq(diagnostics, [])
}

///|
test "independent collinear overlap is a routing conflict" {
  let diagnostics = []
  assert_true(
    finalize_connectors(
      crossing_fixture(first="M20 70 L140 70", second="M50 70 L160 70"),
      ConnectorOptions::new(),
      diagnostics,
    )
    is None,
  )
  assert_eq(diagnostics[0].code, "connector/routing-conflict")
}

///|
test "the checker detects bridge collisions even with an underpass" {
  let diagnostics = []
  let root = finalize_connectors(
    crossing_fixture(),
    ConnectorOptions::new(),
    diagnostics,
  ).unwrap()
  let paths = inspect_connectors(@writer.to_string(root))
  let findings = check_connectors(
    paths[:],
    [{ owner: "label", x: 83.0, y: 66.0, width: 2.0, height: 2.5, }],
    width=180.0,
    height=180.0,
  )
  assert_true(findings.iter().any(d => d.code == "connector/routing-conflict"))
  assert_true(findings.iter().any(d => d.message.contains("vertical")))
  let guarded = []
  let obstacle : ConnectorObstacle = {
    owner: "label",
    x: 83.0,
    y: 66.0,
    width: 2.0,
    height: 2.5,
  }
  let safe = finalize_connectors(
    crossing_fixture(),
    ConnectorOptions::new(),
    guarded,
    obstacles=[obstacle],
  ).unwrap()
  assert_eq(guarded, [])
  assert_eq(
    check_connectors(
      inspect_connectors(@writer.to_string(safe))[:],
      [obstacle],
      width=180.0,
      height=180.0,
    ),
    [],
  )
}

///|
test "curve intersections, multiple crossings and shallow angles are deterministic" {
  for
    (first, second) in [
      ("M20 70 C60 10 100 130 140 70", "M80 10 L80 150"),
      ("M20 60 L140 80", "M80 10 L80 150"),
    ] {
    let diagnostics = []
    let a = finalize_connectors(
      crossing_fixture(first~, second~),
      ConnectorOptions::new(),
      diagnostics,
    ).unwrap()
    let b = finalize_connectors(
      crossing_fixture(first~, second~),
      ConnectorOptions::new(),
      [],
    ).unwrap()
    assert_eq(a, b)
    assert_eq(diagnostics, [])
    assert_true(@writer.to_string(a).contains("<mask"))
  }
}

///|
test "subdivision depth exhaustion never accepts geometry above its tolerance" {
  let path = ConnectorPath::parse("M0 0 Q1000000000 0 0 1000000000").unwrap()
  let connector : ResolvedConnector = {
    id: "bounded",
    source: "a",
    target: "b",
    route: path,
    path,
    mask: None,
  }
  let findings = check_connectors(
    [connector],
    [],
    width=1000000000.0,
    height=1000000000.0,
  )
  assert_true(findings.iter().any(d => d.code == "connector/limit"))
}

///|
test "connector ornaments remain outside final geometry" {
  let root = @writer.element(
    "svg",
    attrs=[("width", "180"), ("height", "180")],
    children=[
      @writer.element("g", attrs=[("class", "bpmn-flow")], children=[
        @writer.element("path", attrs=[
          ("class", "bpmn-connector"),
          ("d", "M20 70 L140 70"),
        ]),
        @writer.element("g", attrs=[("transform", "translate(20 20)")], children=[
          @writer.element("path", attrs=[("d", "M1 4 L12 13")]),
        ]),
      ]),
    ],
  )
  let diagnostics = []
  let output = finalize_connectors(root, ConnectorOptions::new(), diagnostics).unwrap()
  let geometry = inspect_connectors(@writer.to_string(output))
  assert_eq(geometry.length(), 1)
  assert_eq(geometry[0].path.svg(), "M20 70 L140 70")
  assert_eq(diagnostics, [])
}

///|
test "a large hop chooses a clear corridor beside a third connection" {
  let third = @writer.element("path", attrs=[
    ("class", "data-connector"),
    ("data-member", "third"),
    ("data-source", "e"),
    ("data-target", "f"),
    ("d", "M100 180 L220 180"),
  ])
  guard crossing_fixture(first="M240 40 L240 360", second="M40 200 L440 200")
    is Element(name, attrs, children) else {
    fail("SVG required")
  }
  let root = @writer.element(
    name,
    attrs=attrs.iter().to_array(),
    children=[..children, third],
  )
  let diagnostics = []
  let resolved = finalize_connectors(
    root,
    ConnectorOptions::new(bridge_radius=50.0),
    diagnostics,
    viewport=(0.0, 0.0, 500.0, 400.0),
  ).unwrap()
  assert_eq(diagnostics, [])
  let paths = inspect_connectors(@writer.to_string(resolved))
  let work : ConnectorWork = {
    options: ConnectorOptions::new(),
    diagnostics: [],
    candidates: 0,
    subdivisions: 0,
    segments: 0,
    crossings: 0,
    failed: false,
  }
  let pieces = cflatten(paths[1].path, work)
  assert_true(
    !pieces
    .iter()
    .any(p => {
      cintersects(p.a, p.b, {
        owner: "third",
        x: 100.0,
        y: 179.99,
        width: 120.0,
        height: 0.02,
      })
    }),
  )
}

///|
test "a hop refuses an unreadable gap beside a third connector" {
  let third = @writer.element("path", attrs=[
    ("class", "data-connector"),
    ("data-member", "third"),
    ("data-source", "e"),
    ("data-target", "f"),
    ("d", "M100 199 L239 199"),
  ])
  guard crossing_fixture(first="M240 40 L240 360", second="M40 200 L440 200")
    is Element(name, attrs, children) else {
    fail("SVG required")
  }
  let root = @writer.element(
    name,
    attrs=attrs.iter().to_array(),
    children=[
      ..children,
      third,
      @writer.element("path", attrs=[
        ("class", "data-connector"),
        ("data-member", "fourth"),
        ("data-source", "g"),
        ("data-target", "h"),
        ("d", "M100 201 L239 201"),
      ]),
    ],
  )
  let diagnostics = []
  assert_true(
    finalize_connectors(
      root,
      ConnectorOptions::new(bridge_radius=50.0),
      diagnostics,
      viewport=(0.0, 0.0, 500.0, 400.0),
    )
    is None,
  )
  assert_eq(diagnostics[0].code, "connector/routing-conflict")
}

///|
test "label protection cannot alias an endpoint or connection identity" {
  let label : ConnectorObstacle = {
    owner: "a",
    x: 64.0,
    y: 24.0,
    width: 3.0,
    height: 3.0,
  }
  let diagnostics = []
  let root = finalize_connectors(
    crossing_fixture(
      first="M20 20 L70 20 L70 70 L120 70",
      second="M150 10 L150 170",
    ),
    ConnectorOptions::new(style=Rounded, corner_radius=20.0),
    diagnostics,
    labels=[("", label)],
  ).unwrap()
  let paths = inspect_connectors(@writer.to_string(root))
  let work : ConnectorWork = {
    options: ConnectorOptions::new(),
    diagnostics: [],
    candidates: 0,
    subdivisions: 0,
    segments: 0,
    crossings: 0,
    failed: false,
  }
  let pieces = cflatten(paths[0].path, work)
  assert_true(paths[0].path.svg().contains("Q"))
  assert_true(!pieces.iter().any(p => cintersects(p.a, p.b, label)))
  assert_eq(diagnostics, [])
}

///|
test "trace highlights retain identity when equal routes have different marked approaches" {
  let d = "M20 20 L70 20 L70 50"
  let root = @writer.element(
    "svg",
    attrs=[("width", "100"), ("height", "100")],
    children=[
      @writer.element("path", attrs=[
        ("class", "rr-connector enter"),
        ("data-connector", "first"),
        ("data-owner", "rule"),
        ("d", d),
      ]),
      @writer.element("path", attrs=[
        ("class", "rr-connector return"),
        ("data-connector", "second"),
        ("data-owner", "rule"),
        ("d", d),
        ("marker-end", "url(#return)"),
      ]),
      @writer.element("path", attrs=[
        ("class", "rr-trace-path rr-trace-taken"),
        ("data-target", "second"),
        ("d", d),
      ]),
    ],
  )
  let diagnostics = []
  let output = @writer.to_string(
    finalize_connectors(
      root,
      ConnectorOptions::new(style=Curved, crossing=Plain),
      diagnostics,
    ).unwrap(),
  )
  let paths = inspect_connectors(output)
  assert_true(paths[0].path != paths[1].path)
  let traced = output
    .split("\n")
    .find_first(line => line.contains("rr-trace-path"))
    .unwrap()
    .to_owned()
  assert_eq(scene_attribute(traced, "d"), Some(paths[1].path.svg()))
  assert_eq(diagnostics, [])
}

///|
test "bridge entry peak and exit retain continuous curve tangent directions" {
  for
    (start, command) in [
      (
        ConnectorPoint::{ x: 0.0, y: 0.0, },
        ConnectorCommand::Line({ x: 120.0, y: 0.0, }),
      ),
      ({ x: 0.0, y: 0.0, }, Line({ x: 0.0, y: 120.0, })),
      ({ x: 120.0, y: 0.0, }, Line({ x: 0.0, y: 0.0, })),
      ({ x: 0.0, y: 120.0, }, Line({ x: 0.0, y: 0.0, })),
      (
        { x: 0.0, y: 0.0, },
        Cubic({ x: 40.0, y: 0.0, }, { x: 80.0, y: 80.0, }, {
          x: 120.0,
          y: 80.0,
        }),
      ),
    ] {
    for flip in [false, true] {
      let hop : ConnectorHop = {
        command: 1,
        lo: 0.4,
        hi: 0.6,
        radius: 5.0,
        flip,
      }
      let (entry, curves) = cbridge(start, command, hop)
      let first = ctangent(entry, curves[0], 0.0)
      let peak = cend(curves[0])
      let before = ctangent(entry, curves[0], 1.0)
      let after = ctangent(peak, curves[1], 0.0)
      let last = ctangent(peak, curves[1], 1.0)
      for
        (a, b) in [
          (first, ctangent(start, command, hop.lo)),
          (before, after),
          (last, ctangent(start, command, hop.hi)),
        ] {
        assert_true(ccross(a, b).abs() < 0.000001)
        assert_true(a.x * b.x + a.y * b.y > 0.0)
      }
    }
  }
}

///|
test "maximum integer work limits cannot wrap their counters" {
  let maximum = 2147483647
  for kind in 0..<4 {
    let work : ConnectorWork = {
      options: ConnectorOptions::new(
        limits=ConnectorLimits::new(
          candidates=maximum,
          subdivisions=maximum,
          segments=maximum,
          crossings=maximum,
        ),
      ),
      diagnostics: [],
      candidates: maximum,
      subdivisions: maximum,
      segments: maximum,
      crossings: maximum,
      failed: false,
    }
    assert_true(!work.charge(kind))
    assert_eq(work.diagnostics[0].code, "connector/limit")
    assert_eq(work.candidates, maximum)
    assert_eq(work.subdivisions, maximum)
    assert_eq(work.segments, maximum)
    assert_eq(work.crossings, maximum)
  }
}
