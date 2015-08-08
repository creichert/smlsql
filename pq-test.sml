(*

Load toplevel:

1) Load this file into sml toplevel. Some errors will popup, that's okay.

2) Fix the errors

   - CM.autoload "libpq/FFI/libpq.h.cm";
   - CM.autoload "libpq/sources.cm";


Other useful load commands:

CM.autoload "smlsql.cm";
CM.autoload "pq-test.cm";
CM.autoload "libpq/sources.cm";

use "libpq/libpq-h.sml";
use "libpq/pg.sml";
use "build.sml";

*)

structure PqTest =
struct

fun main (name,args) =
  let
      val c = PgClient.conn "host=127.0.0.1 dbname=test user=test password=test"
      val t = PgClient.query c "select 2 + 2 ;" ;
      (* val _ = PgClient.query c "create table if not exists test(field1 text);"; *)
      val q = PgClient.query c "insert into test values ('one'); select * from test;"
  in
      print "selecting data from postgresql\n"
    ; map print (List.concat t)
    ; map print (List.concat q)
    ; PgClient.close c
    ; print "done\n"
    ; OS.Process.success
  end
   handle (PgClient.Sql e) => ( print "exception caught: \n"
		              ; print "  ----> "
			      ; print e
			      ; print "\n"
		              ; OS.Process.failure
			      )
end
