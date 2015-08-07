(if CM.recomp "smlsql.cm" andalso CM.stabilize true "smlsql.cm" then
     OS.Process.exit OS.Process.success
 else
     OS.Process.exit OS.Process.failure) : unit;