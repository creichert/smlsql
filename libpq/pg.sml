(*
 * SQL database interfaces for Standard ML
 * Copyright (C) 2003  Adam Chlipala
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *)

structure PgDriver :> SQL_DRIVER =
struct
    val print = TextIO.print

    type conn = (ST_pg_conn.tag, C.rw) C.su_obj C.ptr'

    exception Sql of string

    fun cerrmsg con = Int32.toString (F_PQstatus.f' (C.Ptr.ro' con)) ^ ": "
		      ^ ZString.toML' (F_PQerrorMessage.f' (C.Ptr.ro' con))

    fun errmsg (con, res, query) = Int32.toString (F_PQresultStatus.f' (C.Ptr.ro' res)) ^ ": " ^ ZString.toML' (F_PQresultErrorMessage.f' (C.Ptr.ro' res)) ^ ": " ^ ZString.toML' query

    fun conn params =
	let
	    val params = ZString.dupML' params
	    val c = F_PQconnectdb.f' params
	    val _ = C.free' params
	in
	    if C.Ptr.isNull' c then
		raise Sql "Null connection returned"
	    else
		(case F_PQstatus.f' (C.Ptr.ro' c) of
		     0 => c
		   | _ =>
		     let
			 val msg = cerrmsg c
		     in
			 F_PQfinish.f' c;
			 raise Sql msg
		     end)
	end

    fun close c = ignore (F_PQfinish.f' c)

    fun dml c q =
	let
	    val q = ZString.dupML' q
	    val res = F_PQexec.f' (c, q)
	    val roRes = C.Ptr.ro' res
	    val code = F_PQresultStatus.f' roRes
	    fun done () = (C.free' q;
			   F_PQclear.f' res)
	in
	    case code of
		1 => (done ();
		      "")
	      | _ =>
		let
		    val msg = errmsg (c, res, q)
		in
		    done ();
		    raise Sql msg
		end
	end

    fun fold c f b q =
	let
	    val q = ZString.dupML' q
	    val res = F_PQexec.f' (c, q)
	    val roRes = C.Ptr.ro' res
	    fun done () = (C.free' q;
			   F_PQclear.f' res)

	    val code = F_PQresultStatus.f' roRes
	in
	    case code of
		2 =>
		let
		    val nt = F_PQntuples.f' roRes
		    val nf = F_PQnfields.f' roRes

		    fun builder (i, acc) =
			if i = nt then
			    acc
			else
			    let
    				fun build (~1, acc) = acc
				  | build (j, acc) =
				    build (j-1, ZString.toML' (F_PQgetvalue.f' (roRes, i, j)) :: acc)
			    in
				builder (i+1, f (build (nf-1, []), acc))
			    end
		in
		    builder (0, b)
		    before done ()
		end
	      | code =>
		let
		    val msg = errmsg (c, res, q)
		in
		    done ();
		    raise Sql msg
		end
	end


    type timestamp = Time.time
    exception Format of string

    fun isNull s = s = ""

    fun intToSql n =
	if n < 0 then
	    "-" ^ Int.toString(~n)
	else
	    Int.toString n
    fun intFromSql "" = 0
      | intFromSql s =
	(case Int.fromString s of
	     NONE => raise Format ("Bad integer: " ^ s)
	   | SOME n => n)

    fun stringToSql s =
	let
	    fun xch #"'" = "\\'"
	      | xch #"\n" = "\\n"
	      | xch #"\r" = "\\r"
	      | xch c = str c
	in
	    foldl (fn (c, s) => s ^ xch c) "'" (String.explode s) ^ "'"
	end
    fun stringFromSql s = s

    fun realToSql s =
	if s < 0.0 then
	    "-" ^ Real.toString(~s)
	else
	    Real.toString s
    fun realFromSql "" = 0.0
      | realFromSql s =
	(case Real.fromString s of
	     NONE => raise Format ("Bad real: " ^ s)
	   | SOME r => r)
    fun realToString s = realToSql s

    fun toMonth m =
	let
	    open Date
	in
	    case m of
		1 => Jan
	      | 2 => Feb
	      | 3 => Mar
	      | 4 => Apr
	      | 5 => May
	      | 6 => Jun
	      | 7 => Jul
	      | 8 => Aug
	      | 9 => Sep
	      | 10 => Oct
	      | 11 => Nov
	      | 12 => Dec
	      | _ => raise Format "Invalid month number"
	end

    fun fromMonth m =
	let
	    open Date
	in
	    case m of
		Jan => 1
	      | Feb => 2
	      | Mar => 3
	      | Apr => 4
	      | May => 5
	      | Jun => 6
	      | Jul => 7
	      | Aug => 8
	      | Sep => 9
	      | Oct => 10
	      | Nov => 11
	      | Dec => 12
	end

    fun pad' (s, 0) = s
      | pad' (s, n) = pad' ("0" ^ s, n-1)
    fun pad (n, i) =
	let
	    val base = Int.toString n
	in
	    pad' (base, Int.max (i - size base, 0))
	end

    fun offsetStr NONE = "+00"
      | offsetStr (SOME n) =
	let
	    val n = LargeInt.toInt (Time.toSeconds n) div 3600
	in
	    if n < 0 then
		"-" ^ pad (~n, 2)
	    else
		"+" ^ pad (n, 2)
	end

    fun timestampToSqlUnquoted t =
	let
	    val d = Date.fromTimeLocal t
	in
	    pad (Date.year d, 4) ^ "-" ^ pad (fromMonth (Date.month d), 2) ^ "-" ^ pad (Date.day d, 2) ^
	    " " ^ pad (Date.hour d, 2) ^ ":" ^ pad (Date.minute d, 2) ^ ":" ^ pad (Date.second d, 2) ^
	    ".000000" ^ offsetStr (Date.offset d)
	end
    fun timestampToSql t = "'" ^ timestampToSqlUnquoted t ^ "'"
    fun timestampFromSql s =
	let
	    val tokens = String.tokens (fn ch => ch = #"-" orelse ch = #" " orelse ch = #":"
						 orelse ch = #"." orelse ch = #"+") s
	in
	    case tokens of
		[year, mon, day, hour, minute, second, _, offset] =>
		Date.toTime (Date.date {day = intFromSql day, hour = intFromSql hour, minute = intFromSql minute,
					month = toMonth (intFromSql mon),
					offset = SOME (Time.fromSeconds (LargeInt.fromInt (intFromSql offset * 3600))),
					second = intFromSql second div 1000, year = intFromSql year})
	      | [year, mon, day, hour, minute, second, _] =>
		Date.toTime (Date.date {day = intFromSql day, hour = intFromSql hour, minute = intFromSql minute,
					month = toMonth (intFromSql mon),
					offset = NONE,
					second = intFromSql second, year = intFromSql year})
	      | [year, mon, day, hour, minute, second] =>
		Date.toTime (Date.date {day = intFromSql day, hour = intFromSql hour, minute = intFromSql minute,
					month = toMonth (intFromSql mon),
					offset = NONE,
					second = intFromSql second div 1000, year = intFromSql year})
	      | _ => raise Format ("Invalid timestamp " ^ s)
	end
		

    fun boolToSql true = "TRUE"
      | boolToSql false = "FALSE"

    fun boolFromSql "FALSE" = false
      | boolFromSql "f" = false
      | boolFromSql "false" = false
      | boolFromSql "n" = false
      | boolFromSql "no" = false
      | boolFromSql "0" = false
      | boolFromSql "" = false
      | boolFromSql _ = true
end

structure PgClient = SqlClient(PgDriver)