

structure PqTest =
struct

fun main (name,args) =
  let
      val c = PgClient.conn "host=127.0.0.1 dbname=test user=test password=test"
      val q = PgClient.query c "select * from test2;"
  in
      print "selecting data from postgresql\n"
    ; PgClient.query c "drop table if exists test;"
    ; PgClient.query c "create table test(field1 varchar(20));"
    ; PgClient.query c "insert into test values ('one');"
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
