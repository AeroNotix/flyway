-module(migration_002).

-compile(export_all).


forwards() ->
    "ALTER TABLE foo ADD COLUMN col2 integer NOT NULL".
