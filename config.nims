--mm:arc
--threads:off


when defined(release) or defined(danger):
  --opt:speed
  --passC:"-flto"
  --passL:"-flto"
  --passL:"-s"
