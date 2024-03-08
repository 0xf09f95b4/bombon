# This is a wrapper around nixpkgs' closureInfo. It returns a newline
# separated list of the store paths of drv's runtime dependencies.
{ runCommand
, closureInfo
}:

drv:
runCommand "${drv.name}-runtime-dependencies.txt" { } ''
  cat ${closureInfo { rootPaths = [ drv ]; }}/store-paths > $out
''
