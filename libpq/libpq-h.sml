structure LibpqH = struct
    local
        val lh = DynLinkage.open_lib
             (* TODO fix - does not link against libpq x86_64
              { name = "/usr/lib/libpq.so.5", global = true, lazy = true }
	      *)
              { name = "/usr/lib/i386-linux-gnu/libpq.so.5", global = true, lazy = true }
    in
        fun libh s = let
            val sh = DynLinkage.lib_symbol (lh, s)
        in
            fn () => DynLinkage.addr sh
        end
    end
end
