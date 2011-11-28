-module(ezmq_SUITE).

-compile(export_all).

-include_lib("common_test/include/ct.hrl").

%% hwm_test() ->
%%     {ok, C} = ezmq:context(),
%%     {ok, S1} = ezmq:socket(C, [pull, {active, false}]),
%%     {ok, S2} = ezmq:socket(C, [push, {active, false}]),

%%     ok = ezmq:setsockopt(S2, linger, 0),
%%     ok = ezmq:setsockopt(S2, hwm, 5),

%%     ok = ezmq:bind(S1, "tcp://127.0.0.1:5858"),
%%     ok = ezmq:connect(S2, "tcp://127.0.0.1:5858"),

%%     ok = hwm_loop(10, S2),

%%     ?assertMatch({ok, <<"test">>}, ezmq:recv(S1)),
%%     ?assertMatch(ok, ezmq:send(S2, <<"test">>)),
%%     ok = ezmq:close(S1),
%%     ok = ezmq:close(S2),
%%     ok = ezmq:term(C).

%% hwm_loop(0, _S) ->
%%     ok;
%% hwm_loop(N, S) when N > 5 ->
%%     ?assertMatch(ok, ezmq:send(S, <<"test">>, [noblock])),
%%     hwm_loop(N-1, S);
%% hwm_loop(N, S) ->
%%     ?assertMatch({error, _} ,ezmq:send(S, <<"test">>, [noblock])),
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
    basic_tests({127,0,0,1}, 5556, req, rep, active, 3).
reqrep_tcp_test_passive(_Config) ->
    basic_tests({127,0,0,1}, 5557, req, rep, passive, 3).

reqrep_tcp_large_active(_Config) ->
    basic_tests({127,0,0,1}, 5556, req, rep, active, 256).
reqrep_tcp_large_passive(_Config) ->
    basic_tests({127,0,0,1}, 5557, req, rep, passive, 256).

req_tcp_bind_close(_Config) ->
    {ok, S} = ezmq:socket([{type, req}, {active, false}]),
	ok = ezmq:bind(S, 5555, []),
	ezmq:close(S).

req_tcp_connect_close(_Config) ->
    {ok, S} = ezmq:socket([{type, req}, {active, false}]),
    ok = ezmq:connect(S, {127,0,0,1}, 5555, []),
	ezmq:close(S).

req_tcp_connect_timeout(_Config) ->
    {ok, S} = ezmq:socket([{type, req}, {active, false}]),
    ok = ezmq:connect(S, {127,0,0,1}, 5555, [{timeout, 1000}]),
	ct:sleep(2000),
	ezmq:close(S).

req_tcp_connecting_timeout(_Config) ->
	spawn(fun() ->
				  {ok, L} = gen_tcp:listen(5555,[{active, false}, {packet, raw}, {reuseaddr, true}]),
				  {ok, S1} = gen_tcp:accept(L),
				  ct:sleep(15000),   %% keep socket alive for at least 10sec...
				  gen_tcp:close(S1)
		  end),
    {ok, S} = ezmq:socket([{type, req}, {active, false}]),
    ok = ezmq:connect(S, {127,0,0,1}, 5555, [{timeout, 1000}]),
	ct:sleep(15000),    %% wait for the connection setup timeout
	ezmq:close(S).
dealer_tcp_bind_close(_Config) ->
    {ok, S} = ezmq:socket([{type, dealer}, {active, false}]),
	ok = ezmq:bind(S, 5555, []),
	ezmq:close(S).

dealer_tcp_connect_close(_Config) ->
    {ok, S} = ezmq:socket([{type, dealer}, {active, false}]),
    ok = ezmq:connect(S, {127,0,0,1}, 5555, []),
	ezmq:close(S).

dealer_tcp_connect_timeout(_Config) ->
    {ok, S} = ezmq:socket([{type, dealer}, {active, false}]),
    ok = ezmq:connect(S, {127,0,0,1}, 5555, [{timeout, 1000}]),
    ok = ezmq:connect(S, {127,0,0,1}, 5555, [{timeout, 1000}]),
    ok = ezmq:connect(S, {127,0,0,1}, 5555, [{timeout, 1000}]),
    ok = ezmq:connect(S, {127,0,0,1}, 5555, [{timeout, 1000}]),
	ct:sleep(2000),
	ezmq:close(S).

dealer_tcp_connecting_timeout(_Config) ->
	spawn(fun() ->
				  {ok, L} = gen_tcp:listen(5555,[{active, false}, {packet, raw}, {reuseaddr, true}]),
				  {ok, S1} = gen_tcp:accept(L),
				  ct:sleep(15000),   %% keep socket alive for at least 10sec...
				  gen_tcp:close(S1)
		  end),
    {ok, S} = ezmq:socket([{type, dealer}, {active, false}]),
    ok = ezmq:connect(S, {127,0,0,1}, 5555, [{timeout, 1000}]),
    ok = ezmq:connect(S, {127,0,0,1}, 5555, [{timeout, 1000}]),
    ok = ezmq:connect(S, {127,0,0,1}, 5555, [{timeout, 1000}]),
    ok = ezmq:connect(S, {127,0,0,1}, 5555, [{timeout, 1000}]),
	ct:sleep(15000),    %% wait for the connection setup timeout
	ezmq:close(S).

req_tcp_connecting_trash(_Config) ->
	Self = self(),
	spawn(fun() ->
				  {ok, L} = gen_tcp:listen(5555,[{active, false}, {packet, raw}, {reuseaddr, true}]),
				  {ok, S1} = gen_tcp:accept(L),
				  T = <<1,16#FF,"TRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASH">>,
				  gen_tcp:send(S1, list_to_binary([T,T,T,T,T])),
				  ct:sleep(500),
				  gen_tcp:close(S1),
				  Self ! done
		  end),
    {ok, S} = ezmq:socket([{type, req}, {active, false}]),
    ok = ezmq:connect(S, {127,0,0,1}, 5555, [{timeout, 1000}]),
	receive 
		done -> ok
	after
        1000 ->
            ct:fail(timeout)
    end,
	ezmq:close(S).

rep_tcp_connecting_timeout(_Config) ->
    {ok, S} = ezmq:socket([{type, rep}, {active, false}]),
	ok = ezmq:bind(S, 5555, []),
	spawn(fun() ->
				  {ok, L} = gen_tcp:connect({127,0,0,1},5555,[{active, false}, {packet, raw}]),
				  ct:sleep(15000),   %% keep socket alive for at least 10sec...
				  gen_tcp:close(L)
		  end),
	ct:sleep(15000),    %% wait for the connection setup timeout
	ezmq:close(S).

rep_tcp_connecting_trash(_Config) ->
	Self = self(),
    {ok, S} = ezmq:socket([{type, rep}, {active, false}]),
	ok = ezmq:bind(S, 5555, []),
	spawn(fun() ->
				  {ok, L} = gen_tcp:connect({127,0,0,1},5555,[{active, false}, {packet, raw}]),
				  T = <<1,16#FF,"TRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASHTRASH">>,
				  gen_tcp:send(L, list_to_binary([T,T,T,T,T])),
				  ct:sleep(500),
				  gen_tcp:close(L),
				  Self ! done
		  end),
	receive 
		done -> ok
	after
        1000 ->
            ct:fail(timeout)
    end,
	ezmq:close(S).

req_tcp_fragment_send(Socket, Data) ->
	lists:foreach(fun(X) ->	gen_tcp:send(Socket, X), ct:sleep(10) end, [<<X>> || <<X>> <= Data]).

req_tcp_fragment(_Config) ->
	Self = self(),
	spawn(fun() ->
				  {ok, L} = gen_tcp:listen(5555,[binary, {active, false}, {packet, raw}, {reuseaddr, true}, {nodelay, true}]),
				  {ok, S1} = gen_tcp:accept(L),
				  req_tcp_fragment_send(S1, <<16#01, 16#7E>>),
				  gen_tcp:recv(S1, 0),
				  Self ! connected,
				  {ok,<<_:4/bytes,"ZZZ">>} = gen_tcp:recv(S1, 0),
				  req_tcp_fragment_send(S1, <<16#01, 16#7F, 16#06, 16#7E, "Hello">>),
				  gen_tcp:close(S1),
				  Self ! done
		  end),
    {ok, S} = ezmq:socket([{type, req}, {active, false}]),
    ok = ezmq:connect(S, {127,0,0,1}, 5555, [{timeout, 1000}]),
	receive 
		connected -> ok
	after
        1000 ->
            ct:fail(timeout)
    end,
	ok = ezmq:send(S, [<<"ZZZ">>]),
	{ok, [<<"Hello">>]} = ezmq:recv(S),
	ezmq:close(S).

create_multi_connect(Type, Active, IP, Port, 0, Acc) ->
	Acc;
create_multi_connect(Type, Active, IP, Port, Cnt, Acc) ->
	{ok, S2} = ezmq:socket([{type, Type}, {active, Active}]),
    ok = ezmq:connect(S2, IP, Port, []),
	create_multi_connect(Type, Active, IP, Port, Cnt - 1, [S2|Acc]).

create_bound_pair_multi(Type1, Type2, Cnt2, Mode, IP, Port) ->
    Active = if
        Mode =:= active ->
            true;
        Mode =:= passive ->
            false
    end,
    {ok, S1} = ezmq:socket([{type, Type1}, {active, Active}]),
    ok = ezmq:bind(S1, Port, []),

	S2 = create_multi_connect(Type2, Active, IP, Port, Cnt2, []),
	ct:sleep(10),  %% give it a moment to establish all sockets....
    {S1, S2}.

basic_test_dealer_rep(IP, Port, Cnt2, Mode, Size) ->
    {S1, S2} = create_bound_pair_multi(dealer, rep, Cnt2, Mode, IP, Port),
	Msg = list_to_binary(string:chars($X, Size)),

	%% send a message for each client Socket and expect a result on each socket
	lists:foreach(fun(_S) -> ok = ezmq:send(S1, [Msg]) end, S2),
	lists:foreach(fun(S) -> {ok, [Msg]} = ezmq:recv(S) end, S2),

    ok = ezmq:close(S1),
	lists:foreach(fun(S) -> ok = ezmq:close(S) end, S2).

basic_test_dealer_req(IP, Port, Cnt2, Mode, Size) ->
    {S1, S2} = create_bound_pair_multi(dealer, req, Cnt2, Mode, IP, Port),
	Msg = list_to_binary(string:chars($X, Size)),

	%% send a message for each client Socket and expect a result on each socket
	lists:foreach(fun(S) -> ok = ezmq:send(S, [Msg]) end, S2),
	lists:foreach(fun(_S) -> {ok, [Msg]} = ezmq:recv(S1) end, S2),

    ok = ezmq:close(S1),
	lists:foreach(fun(S) -> ok = ezmq:close(S) end, S2).

basic_tests_dealer(_Config) ->
	basic_test_dealer_req({127,0,0,1}, 5559, 10, passive, 3),
	basic_test_dealer_rep({127,0,0,1}, 5560, 10, passive, 3).

basic_test_router_req(IP, Port, Cnt2, Mode, Size) ->
    {S1, S2} = create_bound_pair_multi(router, req, Cnt2, Mode, IP, Port),
	Msg = list_to_binary(string:chars($X, Size)),

	%% send a message for each client Socket and expect a result on each socket
	lists:foreach(fun(S) -> ok = ezmq:send(S, [Msg]) end, S2),
	lists:foreach(fun(_S) ->
						  {ok, {Id, [Msg]}} = ezmq:recv(S1),
						  ok = ezmq:send(S1, {Id, [Msg]})
				  end, S2),
	lists:foreach(fun(S) -> {ok, [Msg]} = ezmq:recv(S) end, S2),

    ok = ezmq:close(S1),
	lists:foreach(fun(S) -> ok = ezmq:close(S) end, S2).

basic_tests_router(_Config) ->
	basic_test_router_req({127,0,0,1}, 5561, 10, passive, 3).

shutdown_stress_test(_Config) ->
    shutdown_stress_loop(10).

%% version_test() ->
%%     {Major, Minor, Patch} = ezmq:version(),
%%     ?assert(is_integer(Major) andalso is_integer(Minor) andalso is_integer(Patch)).

shutdown_stress_loop(0) ->
    ok;
shutdown_stress_loop(N) ->
    {ok, S1} = ezmq:socket([{type, rep}, {active, false}]),
	ok = ezmq:bind(S1, 5558 + N, []),
    shutdown_stress_worker_loop(N, 100),
    ok = join_procs(100),
    ezmq:close(S1),
    shutdown_stress_loop(N-1).

shutdown_no_blocking_test(_Config) ->
    {ok, S} = ezmq:socket([{type, req}, {active, false}]),
    ezmq:close(S).

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
    {ok, S2} = ezmq:socket([{type, rep}, {active, false}]),
    spawn(?MODULE, worker, [self(), S2, 5558 + P]),
    shutdown_stress_worker_loop(P, N-1).

worker(Pid, S, Port) ->
    ok = ezmq:connect(S, {127,0,0,1}, Port, []),
    ok = ezmq:close(S),
    Pid ! proc_end.

create_bound_pair(Type1, Type2, Mode, IP, Port) ->
    Active = if
        Mode =:= active ->
            true;
        Mode =:= passive ->
            false
    end,
    {ok, S1} = ezmq:socket([{type, Type1}, {active, Active}]),
    {ok, S2} = ezmq:socket([{type, Type2}, {active, Active}]),
    ok = ezmq:bind(S1, Port, []),
    ok = ezmq:connect(S2, IP, Port, []),
    {S1, S2}.

ping_pong({S1, S2}, Msg, active) ->
    ok = ezmq:send(S1, [Msg,Msg]),
    receive
        {ezmq, S2, [Msg,Msg]} ->
            ok
    after
        1000 ->
            ct:fail(timeout)
    end,
    ok = ezmq:send(S2, [Msg]),
    receive
        {ezmq, S1, [Msg]} ->
            ok
    after
        1000 ->
            ct:fail(timeout)
    end,
    ok = ezmq:send(S1, [Msg]),
    receive
        {ezmq, S2, [Msg]} ->
            ok
    after
        1000 ->
            ct:fail(timeout)
    end,
    ok = ezmq:send(S2, [Msg]),
    receive
        {ezmq, S1, [Msg]} ->
            ok
    after
        1000 ->
            ct:fail(timeout)
    end,
    ok;
    
ping_pong({S1, S2}, Msg, passive) ->
    ok = ezmq:send(S1, [Msg]),
    {ok, [Msg]} = ezmq:recv(S2),
    ok = ezmq:send(S2, [Msg]),
    {ok, [Msg]} = ezmq:recv(S1),
    ok = ezmq:send(S1, [Msg,Msg]),
    {ok, [Msg,Msg]} = ezmq:recv(S2),
    ok.

basic_tests(IP, Port, Type1, Type2, Mode, Size) ->
    {S1, S2} = create_bound_pair(Type1, Type2, Mode, IP, Port),
	Msg = list_to_binary(string:chars($X, Size)),
    ping_pong({S1, S2}, Msg, Mode),
    ok = ezmq:close(S1),
    ok = ezmq:close(S2).

init_per_suite(Config) ->
	application:start(sasl),
	application:start(gen_listener_tcp),
	application:start(ezmq),
	Config.

end_per_suite(Config) ->
	Config.

all() ->
	[reqrep_tcp_test_active, reqrep_tcp_test_passive,
	 reqrep_tcp_large_active, reqrep_tcp_large_passive,
	 shutdown_no_blocking_test,
	 req_tcp_bind_close, req_tcp_connect_close, req_tcp_connect_timeout,
	 req_tcp_connecting_timeout, req_tcp_connecting_trash,
	 rep_tcp_connecting_timeout, rep_tcp_connecting_trash,
	 req_tcp_fragment,
	 dealer_tcp_bind_close, dealer_tcp_connect_close, dealer_tcp_connect_timeout, basic_tests_dealer,
	 basic_tests_router,
	 shutdown_stress_test].
