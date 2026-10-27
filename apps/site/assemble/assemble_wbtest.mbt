///|
/// One line of `gh api --paginate` output with `releases_filter`.
fn release_line(
  tag : String,
  assets~ : String = "",
  draft~ : Bool = false,
  prerelease~ : Bool = false,
) -> String {
  "\{tag}\t\{draft}\t\{prerelease}\t\{assets}"
}

///|
fn tags(releases : Array[Release]) -> Array[String] {
  releases.map(release => release.tag)
}

///|
test "Patch release" {
  let text = [
    release_line("v0.1.3", assets="site-0.1.tar.gz"),
    release_line("v0.1.2", assets="site-0.1.tar.gz"),
  ].join("\n")
  assert_eq(tags(select_releases(parse_releases(text), "0.1")), ["v0.1.3"])
}

///|
test "Release before site assets" {
  let text = [release_line("v0.2.0"), release_line("v0.1.0")].join("\n")
  assert_eq(select_releases(parse_releases(text), "0.3"), [])
}

///|
test "More than 30 releases" {
  let lines = []
  for patch = 38; patch >= 0; patch = patch - 1 {
    lines.push(release_line("v0.5.\{patch}", assets="site-0.5.tar.gz"))
  }
  for patch = 5; patch >= 0; patch = patch - 1 {
    lines.push(release_line("v0.2.\{patch}", assets="site-0.2.tar.gz"))
  }
  assert_eq(lines.length(), 45)
  assert_eq(lines[39], release_line("v0.2.5", assets="site-0.2.tar.gz"))
  let selected = select_releases(parse_releases(lines.join("\n")), "0.2")
  assert_eq(tags(selected), ["v0.5.38", "v0.2.5"])
}

///|
test "drafts, prereleases and other tags are left out" {
  let text = [
    release_line("v0.4.0", draft=true),
    release_line("v0.4.0-rc.1", prerelease=true),
    release_line("v0.3.1", prerelease=true),
    release_line("v0.3.0", assets="notes.txt,site-0.3.tar.gz"),
    release_line("nightly"),
  ].join("\n")
  let selected = select_releases(parse_releases(text), "0.3")
  assert_eq(tags(selected), ["v0.3.0"])
  assert_eq(selected[0].assets, ["notes.txt", "site-0.3.tar.gz"])
  assert_eq(missing_assets(selected), [])
}

///|
test "Missing asset" {
  let text = [
    release_line("v0.4.0"),
    release_line("v0.3.0", assets="site-0.3.tar.gz"),
  ].join("\n")
  let selected = select_releases(parse_releases(text), "0.3")
  assert_eq(missing_assets(selected).map(p => p.render()), [
    "v0.4.0: the release has no site asset `site-0.4.tar.gz`",
  ])
}

///|
test "versions.since comes from site.json" {
  assert_eq(versions_since("{\"versions\": {\"since\": \"0.3\"}}"), "0.3")
  let message = try versions_since("{}") catch {
    @model.Invalid(problems) => problems[0].render()
  } noraise {
    _ => ""
  }
  assert_eq(
    message, "site/site.json: `versions.since` must be a minor line, such as \"0.3\"",
  )
}

///|
/// A clean directory below `_build/` for one test. Under `moon test` the working directory is the
/// module root, `apps/site`.
async fn test_dir(name : String) -> String {
  let dir = "_build/assemble-\{name}"
  if @fs.exists(dir) {
    @fs.rmdir(dir, recursive=true)
  }
  @fs.mkdir(dir, recursive=true)
  dir
}

///|
async test "fixture archive unpacks, and a corrupt one names the release" {
  let dir = test_dir("archive")
  write_text("\{dir}/tree/index.html", "<p>0.3</p>")
  let (code, _, _) = @process.collect_output("tar", [
    "-czf",
    "\{dir}/site-0.3.tar.gz",
    "-C",
    "\{dir}/tree",
    ".",
  ])
  assert_eq(code, 0)
  unpack("v0.3.0", "\{dir}/site-0.3.tar.gz", "\{dir}/out")
  assert_eq(@fs.read_file("\{dir}/out/index.html").text(), "<p>0.3</p>")
  write_text("\{dir}/bad.tar.gz", "not an archive")
  let message = try unpack("v0.3.1", "\{dir}/bad.tar.gz", "\{dir}/bad") catch {
    @model.Invalid(problems) => problems[0].file
    _ => "another error"
  } noraise {
    _ => "no error"
  }
  assert_eq(message, "v0.3.1")
}
