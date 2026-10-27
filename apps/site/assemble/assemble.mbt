///|
/// Write consumer release-policy inputs for Telescope's offline tree assembler.
async fn write_text(path : String, text : String) -> Unit {
  @fs.mkdir(@host.parent(path), recursive=true, allow_exist=true)
  @fs.write_file(path, text, create_mode=CreateOrTruncate)
}

///|
/// Copy the current next tree into the supplied-input boundary before assembly.
async fn copy_input(from : String, to : String) -> Unit {
  @fs.mkdir(to, recursive=true, allow_exist=true)
  for name in @fs.readdir(from) {
    let source = from + "/" + name
    let target = to + "/" + name
    if @fs.kind(source, follow_symlink=false) is Directory {
      copy_input(source, target)
    } else {
      @fs.write_file(target, @fs.read_file(source).binary(), create_mode=CreateOrTruncate)
    }
  }
}
