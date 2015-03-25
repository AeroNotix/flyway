-module(flyway_migration).


-callback forwards()  -> list().
-callback backwards() -> list().

%% optional callbacks
%% -callback forwards_row(tuple())  -> tuple()
%% -callback backwards_row(tuple()) -> tuple()
