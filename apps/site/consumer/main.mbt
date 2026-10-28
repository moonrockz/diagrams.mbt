///|
fn option(args : Array[String], name : String, fallback : String) -> String {
  for i in 0..<(args.length() - 1) {
    if args[i] == name {
      return args[i + 1]
    }
  }
  fallback
}

///|
/// The host owns site generation; this executable supplies the repository revision
/// and compiled diagram callbacks. The configuration snapshot is never published.
async fn build(args : Array[String]) -> Unit {
  let root = option(args, "--root", ".")
  let out = option(args, "--out", root + "/_site")
  let tree = option(args, "--tree-path", "")
  let config_path = root + "/site/site.json"
  let config = @host.configuration(config_path)
  let (code, revision) = @process.collect_stdout(
    "git",
    ["rev-parse", "HEAD"],
    cwd=root,
  )
  guard code == 0 else { fail("cannot determine source revision") }
  guard @json.parse(@fs.read_file(config_path).text()) is Object(fields) else {
    fail("site/site.json must be an object")
  }
  fields["repo_ref"] = Json::string(revision.text().trim().to_owned())
  fields["site_url"] = Json::string(config.site_url + tree)
  let snapshot = root + "/_build/site-config.json"
  @fs.mkdir(root + "/_build", recursive=true, allow_exist=true)
  @fs.write_file(
    snapshot,
    Json::object(fields).stringify(),
    create_mode=CreateOrTruncate,
  )
  let warnings = @host.build(
    root,
    snapshot,
    out,
    base=config.base_path + tree,
    providers=providers(),
    main_build=args.contains("--main"),
  )
  for problem in warnings {
    eprintln("warning: " + problem.render())
  }
  println("site: Telescope " + @host.version + " wrote " + out)
}

///|
async fn main {
  build(@env.args()) catch {
    @model.Invalid(problems) => {
      eprintln(@host.diagnostics(problems, "human"))
      @sys.exit(1)
    }
    error => {
      eprintln("site: \{error}")
      @sys.exit(1)
    }
  }
}
