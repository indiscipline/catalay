import std/[terminal]

proc panic*(msg: varargs[string, `$`]) =
  stderr.setForegroundColor(fgRed)
  for s in msg:
    stderr.write(s)
  stderr.setForegroundColor(fgDefault)
  stderr.write('\n')
  quit(1)
