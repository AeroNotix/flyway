-module(migration_003).

-compile(export_all).


forwards() ->
    "ALTER TABLE foo ADD COLUMN col3 integer NOT NULL".
