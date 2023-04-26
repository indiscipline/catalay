# Package

version       = "0.1.0"
author        = "Kirill I"
description   = "Layout a Catalogue"
license       = "GPL-3.0-or-later"
srcDir        = "src"
bin           = @["catalay"]


# Dependencies

requires "nim >= 1.6.12", "yaml >= 1.1.0", "zero_functional", "parsetoml >= 0.7.0",
  "argparse >= 4.0.0", "os_files >= 0.1.2"

