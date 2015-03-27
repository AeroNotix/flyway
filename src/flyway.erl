-module(flyway).

-compile(export_all).

-include_lib("epgsql/include/pgsql.hrl").
-define(MUTEX_GRAB_FAIL, <<"55P03">>).

migrate(App) ->
    case code:priv_dir(App) of
        {error, bad_name} ->
            {error, unknown_app};
        Path when is_list(Path) ->
            run_migrations(Path)
    end.

run_migrations(Path) ->
    MigrationFiles = filelib:wildcard(Path ++ "/**/migration_*.erl"),
    %% Have these opts passed in
    PSQLWorkerOpts = [{size, 1}],
    PSQLConnectionOpts =
        [{username, "ubic"},
         {password, "ubic"},
         {host,     "localhost"},
         {opts, [{database, "flyway_migrations"}]}],
    epgsql_poolboy:start_pool(?MODULE, PSQLWorkerOpts,
                              PSQLConnectionOpts),
    MigrationInTransaction =
        fun(Worker) ->
                LockTable = "LOCK TABLE migrations IN ACCESS EXCLUSIVE MODE NOWAIT",
                case pgsql:equery(Worker, LockTable) of
                    {ok, _, _} ->
                        put(pg_worker, Worker),
                        try
                            err_pipe([fun sort_migrations/1, fun compile_migrations/1,
                                      fun validate_migrations/1, fun execute_migrations/1],
                                     MigrationFiles)
                        after
                            erase(pg_worker)
                        end;
                    {error, _} = E->
                        E
                end
        end,
    case epgsql_poolboy:with_transaction(?MODULE, MigrationInTransaction) of
        ok ->
            ok;
        {error, #error{code = ?MUTEX_GRAB_FAIL}} ->
            timer:sleep(5000),
            run_migrations(Path);
        {error, #error{code = Code}} ->
            {error, flyway_postgres_codes:code_to_atom(Code)};
        O -> O
    end.

sort_migrations(Migrations) ->
    SortFn =
        fun(A, B) ->
                ADigit = extract_number(filename:basename(A)),
                BDigit = extract_number(filename:basename(B)),
                ADigit < BDigit
        end,
    {ok, lists:sort(SortFn, Migrations)}.

compile_migrations(Migrations) ->
    {ok,
     [begin
          compile:file(Migration),
          extract_mod_name(Migration)
      end || Migration <- Migrations]}.

validate_migrations(Migrations) ->
    {ok, Migrations}.

extract_mod_name(Migration) ->
    list_to_atom(filename:basename(Migration, ".erl")).

execute_migrations(Migrations) ->
    Worker = get(pg_worker),
    ToExecute =
        [fun() ->
                 case has_migration_ran(Migration) of
                     true ->
                         ok;
                     false ->
                         run_query(Worker, Migration:forwards())
                 end
         end || Migration <- Migrations],
    case thread_calls(ToExecute) of
        ok ->
            {ok, ok};
        {error, _} = E->
            E
    end.

run_query(Worker, Query) ->
    pgsql:equery(Worker, Query, []).

has_migration_ran(Migration) ->
    Worker = get(pg_worker),
    HasRanQuery = "SELECT has_ran FROM flyway_migrations.migrations WHERE name = $1",
    case pgsql:equery(Worker, HasRanQuery, [Migration]) of
        {ok, []} ->
            false;
        {ok, [HasRan]} ->
            HasRan
    end.

thread_calls([]) ->
    ok;
thread_calls([Fn|Fns]) ->
    case Fn() of
        ok ->
            thread_calls(Fns);
        {ok, _} ->
            thread_calls(Fns);
        {ok, _, _} ->
            thread_calls(Fns);
        {error, _} = E ->
            E
    end.

err_pipe([], Val) ->
    Val;
err_pipe([Fn|Fns], Val) ->
    case Fn(Val) of
        {ok, V} ->
            err_pipe(Fns, V);
        {ok, A, B} ->
            err_pipe(Fns, {A, B});
        {error, _} = E ->
            E
    end.

extract_number(S) ->
    [_, I, _] = re:split(S, "migration_(\\d+).erl"),
    binary_to_integer(I).
