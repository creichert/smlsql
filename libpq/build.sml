(if CM.recomp "sources.cm" andalso CM.stabilize true "sources.cm" then
     OS.Process.exit OS.Process.success
 else
     OS.Process.exit OS.Process.failure) : unit;