-module(flyway_SUITE).

-compile(export_all).

-include_lib("common_test/include/ct.hrl").

suite() ->
    [{timetrap,{seconds,30}}].

init_per_suite(Config) ->
    {ok, _} = application:ensure_all_started(flyway),
    PoolOpts =
        [{username, "flyway"},
         {password, "flyway"},
         {host,     "localhost"},
         {opts, [{database, "flyway_migrations"}]}],
    [{pool_opts, PoolOpts}|Config].

end_per_suite(_Config) ->
    ok.

init_per_group(_GroupName, Config) ->
    Config.

end_per_group(_GroupName, _Config) ->
    ok.

init_per_testcase(_TestCase, Config) ->
    Config.

end_per_testcase(_TestCase, _Config) ->
    ok.

groups() ->
    [].

all() ->
    [t_simple_migration].

t_simple_migration() -> [].

t_simple_migration(Config) ->
    PoolOpts = ?config(pool_opts, Config),
    Res = flyway:migrate(flyway, PoolOpts),
    ct:pal("~p", [Res]),
    ok = Res.
