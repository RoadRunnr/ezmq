-module(zmq_SUITE).

-compile(export_all).

-include_lib("common_test/include/ct.hrl").

%% hwm_test() ->
%%     {ok, C} = zmq:context(),
%%     {ok, S1} = zmq:socket(C, [pull, {active, false}]),
%%     {ok, S2} = zmq:socket(C, [push, {active, false}]),

%%     ok = zmq:setsockopt(S2, linger, 0),
%%     ok = zmq:setsockopt(S2, hwm, 5),

%%     ok = zmq:bind(S1, "tcp://127.0.0.1:5858"),
%%     ok = zmq:connect(S2, "tcp://127.0.0.1:5858"),

%%     ok = hwm_loop(10, S2),

%%     ?assertMatch({ok, <<"test">>}, zmq:recv(S1)),
%%     ?assertMatch(ok, zmq:send(S2, <<"test">>)),
%%     ok = zmq:close(S1),
%%     ok = zmq:close(S2),
%%     ok = zmq:term(C).

%% hwm_loop(0, _S) ->
%%     ok;
%% hwm_loop(N, S) when N > 5 ->
%%     ?assertMatch(ok, zmq:send(S, <<"test">>, [noblock])),
%%     hwm_loop(N-1, S);
%% hwm_loop(N, S) ->
%%     ?assertMatch({error, _} ,zmq:send(S, <<"test">>, [noblock])),
%%     hwm_loop(N-1, S).


%% pair_ipc_test() ->
%%     basic_tests("ipc:///tmp/tester", pair, pair, active),
%%     basic_tests("ipc:///tmp/tester", pair, pair, passive).

%% pair_tcp_test() ->
%%     basic_tests("tcp://127.0.0.1:5554", pair, pair, active),
%%     basic_tests("tcp://127.0.0.1:5555", pair, pair, passive).

%% reqrep_ipc_test() ->
%%     basic_tests("ipc:///tmp/tester", req, rep, active),
%%     basic_tests("ipc:///tmp/tester", req, rep, passive).

reqrep_tcp_test_active(_Config) ->
    basic_tests({127,0,0,1}, 5556, req, rep, active).
reqrep_tcp_test_passive(_Config) ->
    basic_tests({127,0,0,1}, 5557, req, rep, passive).

shutdown_stress_test(_Config) ->
    shutdown_stress_loop(10).

%% version_test() ->
%%     {Major, Minor, Patch} = zmq:version(),
%%     ?assert(is_integer(Major) andalso is_integer(Minor) andalso is_integer(Patch)).

shutdown_stress_loop(0) ->
    ok;
shutdown_stress_loop(N) ->
    {ok, S1} = zmq:socket([{type, rep}, {active, false}]),
	ok = zmq:bind(S1, 5558 + N, []),
	io:format("BOUND===================================================== ~w ~n", [S1]),
    shutdown_stress_worker_loop(N, 100),
    ok = join_procs(100),
    zmq:close(S1),
	io:format("BOUND CLOSED============================================== ~w~n", [S1]),
    shutdown_stress_loop(N-1).

shutdown_no_blocking_test(_Config) ->
    {ok, S} = zmq:socket([{type, req}, {active, false}]),
    zmq:close(S).

join_procs(0) ->
    ok;
join_procs(N) ->
    receive
        proc_end ->
            join_procs(N-1)
    after
        2000 ->
            throw(stuck)
    end.

shutdown_stress_worker_loop(_P, 0) ->
    ok;
shutdown_stress_worker_loop(P, N) ->
    {ok, S2} = zmq:socket([{type, rep}, {active, false}]),
    spawn(?MODULE, worker, [self(), S2, 5558 + P]),
    shutdown_stress_worker_loop(P, N-1).

worker(Pid, S, Port) ->
	io:format("TRY======================================================= ~w~n", [S]),
    ok = zmq:connect(S, {127,0,0,1}, Port, []),
	io:format("CONNECTED================================================= ~w~n", [Port]),
    ok = zmq:close(S),
	io:format("CLOSED==================================================== ~w~n", [S]),
    Pid ! proc_end.

create_bound_pair(Type1, Type2, Mode, IP, Port) ->
    Active = if
        Mode =:= active ->
            true;
        Mode =:= passive ->
            false
    end,
    {ok, S1} = zmq:socket([{type, Type1}, {active, Active}]),
    {ok, S2} = zmq:socket([{type, Type2}, {active, Active}]),
    ok = zmq:bind(S1, Port, []),
    ok = zmq:connect(S2, IP, Port, []),
    {S1, S2}.

ping_pong({S1, S2}, Msg, active) ->
    ok = zmq:send(S1, [Msg,Msg]),
    receive
        {zmq, S2, [Msg,Msg]} ->
            ok
    after
        1000 ->
            ct:fail(timeout)
    end,
    ok = zmq:send(S2, [Msg]),
    receive
        {zmq, S1, [Msg]} ->
            ok
    after
        1000 ->
            ct:fail(timeout)
    end,
    ok = zmq:send(S1, [Msg]),
    receive
        {zmq, S2, [Msg]} ->
            ok
    after
        1000 ->
            ct:fail(timeout)
    end,
    ok = zmq:send(S2, [Msg]),
    receive
        {zmq, S1, [Msg]} ->
            ok
    after
        1000 ->
            ct:fail(timeout)
    end,
    ok;
    
ping_pong({S1, S2}, Msg, passive) ->
    ok = zmq:send(S1, [Msg]),
    {ok, [Msg]} = zmq:recv(S2),
    ok = zmq:send(S2, [Msg]),
    {ok, [Msg]} = zmq:recv(S1),
    ok = zmq:send(S1, [Msg,Msg]),
    {ok, [Msg,Msg]} = zmq:recv(S2),
    ok.

basic_tests(IP, Port, Type1, Type2, Mode) ->
    {S1, S2} = create_bound_pair(Type1, Type2, Mode, IP, Port),
    ping_pong({S1, S2}, <<"XXX">>, Mode),
    ok = zmq:close(S1),
    ok = zmq:close(S2).

init_per_suite(Config) ->
	application:start(sasl),
	application:start(gen_listener_tcp),
	application:start(zmq),
	Config.

end_per_suite(Config) ->
	Config.

all() -> 
	[reqrep_tcp_test_active, reqrep_tcp_test_passive, shutdown_no_blocking_test, shutdown_stress_test].
