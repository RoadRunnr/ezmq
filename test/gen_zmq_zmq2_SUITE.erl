% Copyright 2010-2011, Travelping GmbH <info@travelping.com>

% Permission is hereby granted, free of charge, to any person obtaining a
% copy of this software and associated documentation files (the "Software"),
% to deal in the Software without restriction, including without limitation
% the rights to use, copy, modify, merge, publish, distribute, sublicense,
% and/or sell copies of the Software, and to permit persons to whom the
% Software is furnished to do so, subject to the following conditions:

% The above copyright notice and this permission notice shall be included in
% all copies or substantial portions of the Software.

% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
% FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
% DEALINGS IN THE SOFTWARE.

-module(gen_zmq_zmq2_SUITE).

-compile(export_all).

-include_lib("common_test/include/ct.hrl").

reqrep_tcp_test_active(_Config) ->
    basic_tests_erlzmq(fun ping_pong_erlzmq/3, "tcp://127.0.0.1:5555", {127,0,0,1}, 5555, req, rep, active, 3),
    basic_tests_gen_zmq(fun ping_pong_gen_zmq/3, "tcp://127.0.0.1:5555", {127,0,0,1}, 5555, req, rep, active, 3).
reqrep_tcp_test_passive(_Config) ->
    basic_tests_erlzmq(fun ping_pong_erlzmq/3, "tcp://127.0.0.1:5556", {127,0,0,1}, 5556, req, rep, passive, 3),
    basic_tests_gen_zmq(fun ping_pong_gen_zmq/3, "tcp://127.0.0.1:5556", {127,0,0,1}, 5556, req, rep, passive, 3).

reqrep_tcp_large_active(_Config) ->
    basic_tests_erlzmq(fun ping_pong_erlzmq/3, "tcp://127.0.0.1:5557", {127,0,0,1}, 5557, req, rep, active, 256),
    basic_tests_gen_zmq(fun ping_pong_gen_zmq/3, "tcp://127.0.0.1:5557", {127,0,0,1}, 5557, req, rep, active, 256).
reqrep_tcp_large_passive(_Config) ->
    basic_tests_erlzmq(fun ping_pong_erlzmq/3, "tcp://127.0.0.1:5558", {127,0,0,1}, 5558, req, rep, passive, 256),
    basic_tests_gen_zmq(fun ping_pong_gen_zmq/3, "tcp://127.0.0.1:5558", {127,0,0,1}, 5558, req, rep, passive, 256).

dealerrep_tcp_test_active(_Config) ->
    basic_tests_erlzmq(fun dealer_ping_pong_erlzmq/3, "tcp://127.0.0.1:5559", {127,0,0,1}, 5559, dealer, rep, active, 4),
    basic_tests_gen_zmq(fun dealer_ping_pong_gen_zmq/3, "tcp://127.0.0.1:5559", {127,0,0,1}, 5559, dealer, rep, active, 4).
dealerrep_tcp_test_passive(_Config) ->
    basic_tests_erlzmq(fun dealer_ping_pong_erlzmq/3, "tcp://127.0.0.1:5560", {127,0,0,1}, 5560, dealer, rep, passive, 3),
	basic_tests_gen_zmq(fun dealer_ping_pong_gen_zmq/3, "tcp://127.0.0.1:5560", {127,0,0,1}, 5560, dealer, rep, passive, 3).

reqdealer_tcp_test_active(_Config) ->
    basic_tests_erlzmq(fun ping_pong_erlzmq_dealer/3, "tcp://127.0.0.1:5561", {127,0,0,1}, 5561, req, dealer, active, 3),
    basic_tests_gen_zmq(fun ping_pong_gen_zmq_dealer/3, "tcp://127.0.0.1:5561", {127,0,0,1}, 5561, req, dealer, active, 3).
reqdealer_tcp_test_passive(_Config) ->
    basic_tests_erlzmq(fun ping_pong_erlzmq_dealer/3, "tcp://127.0.0.1:5562", {127,0,0,1}, 5562, req, dealer, passive, 3),
    basic_tests_gen_zmq(fun ping_pong_gen_zmq_dealer/3, "tcp://127.0.0.1:5562", {127,0,0,1}, 5562, req, dealer, passive, 3).

reqrouter_tcp_test_active(_Config) ->
    basic_tests_erlzmq(fun ping_pong_erlzmq_router/3, "tcp://127.0.0.1:5561", {127,0,0,1}, 5561, req, router, active, 3),
    basic_tests_gen_zmq(fun ping_pong_gen_zmq_router/3, "tcp://127.0.0.1:5561", {127,0,0,1}, 5561, req, router, active, 3).
reqrouter_tcp_test_passive(_Config) ->
    basic_tests_erlzmq(fun ping_pong_erlzmq_router/3, "tcp://127.0.0.1:5562", {127,0,0,1}, 5562, req, router, passive, 3),
    basic_tests_gen_zmq(fun ping_pong_gen_zmq_router/3, "tcp://127.0.0.1:5562", {127,0,0,1}, 5562, req, router, passive, 3).

create_bound_pair_erlzmq(Ctx, Type1, Type2, Mode, Transport, IP, Port) ->
    Active = if
        Mode =:= active ->
            true;
        Mode =:= passive ->
            false
    end,
	{ok, S1} = erlzmq:socket(Ctx, [Type1, {active, Active}]),
    {ok, S2} = gen_zmq:socket([{type, Type2}, {active, Active}]),
	ok = erlzmq:bind(S1, Transport),
    ok = gen_zmq:connect(S2, IP, Port, []),
    {S1, S2}.

create_bound_pair_gen_zmq(Ctx, Type1, Type2, Mode, Transport, IP, Port) ->
    Active = if
        Mode =:= active ->
            true;
        Mode =:= passive ->
            false
    end,
    {ok, S1} = gen_zmq:socket([{type, Type1}, {active, Active}]),
	{ok, S2} = erlzmq:socket(Ctx, [Type2, {active, Active}]),
	ok = gen_zmq:bind(S1, Port, []),
    ok = erlzmq:connect(S2, Transport),
    {S1, S2}.

%% assert that message queue is empty....
assert_mbox_empty() ->
	receive
		M -> ct:fail({unexpected, M})
	after
		0 -> ok
	end.

%% assert that top message in the queue is what we think it should be
assert_mbox(Msg) ->
	assert_mbox_match({Msg,[],[ok]}).

assert_mbox_match(MatchSpec) ->
	CompiledMatchSpec = ets:match_spec_compile([MatchSpec]),
    receive
		M -> case ets:match_spec_run([M], CompiledMatchSpec) of
				 [] -> ct:fail({unexpected, M});
				 [Ret] -> Ret
			 end
    after
        1000 ->
            ct:fail(timeout)
    end.

ping_pong_erlzmq({S1, S2}, Msg, active) ->
    ok = erlzmq:send(S1, Msg, [sndmore]),
    ok = erlzmq:send(S1, Msg),
	assert_mbox({gen_zmq, S2, [Msg,Msg]}),
	assert_mbox_empty(),

    ok = gen_zmq:send(S2, [Msg]),
	assert_mbox({zmq, S1, Msg, []}),

    ok = erlzmq:send(S1, Msg),
	assert_mbox({gen_zmq, S2, [Msg]}),
	assert_mbox_empty(),

    ok = gen_zmq:send(S2, [Msg]),
	assert_mbox({zmq, S1, Msg, []}),
	assert_mbox_empty(),

    ok;
    
ping_pong_erlzmq({S1, S2}, Msg, passive) ->
	ok = erlzmq:send(S1, Msg),
    {ok, [Msg]} = gen_zmq:recv(S2),
    ok = gen_zmq:send(S2, [Msg]),
	{ok, Msg} = erlzmq:recv(S1),
    ok = erlzmq:send(S1, Msg, [sndmore]),
    ok = erlzmq:send(S1, Msg),
    {ok, [Msg,Msg]} = gen_zmq:recv(S2),
    ok.

ping_pong_gen_zmq({S1, S2}, Msg, active) ->
    ok = gen_zmq:send(S1, [Msg,Msg]),
	assert_mbox({zmq, S2, Msg, [rcvmore]}),
	assert_mbox({zmq, S2, Msg, []}),
	assert_mbox_empty(),

    ok = erlzmq:send(S2, Msg),
	assert_mbox({gen_zmq, S1, [Msg]}),
	assert_mbox_empty(),

    ok = gen_zmq:send(S1, [Msg]),
	assert_mbox({zmq, S2, Msg, []}),
	assert_mbox_empty(),

    ok = erlzmq:send(S2, Msg, [sndmore]),
    ok = erlzmq:send(S2, Msg),
	assert_mbox({gen_zmq, S1, [Msg,Msg]}),
	assert_mbox_empty(),

    ok;
    
ping_pong_gen_zmq({S1, S2}, Msg, passive) ->
	ok = gen_zmq:send(S1, [Msg]),
    {ok, Msg} = erlzmq:recv(S2),
    ok = erlzmq:send(S2, Msg),
	{ok, [Msg]} = gen_zmq:recv(S1),
    ok = gen_zmq:send(S1, [Msg,Msg]),
    {ok, Msg} = erlzmq:recv(S2),
    {ok, Msg} = erlzmq:recv(S2),
    ok.

ping_pong_erlzmq_dealer({S1, S2}, Msg, active) ->
    ok = erlzmq:send(S1, Msg, [sndmore]),
    ok = erlzmq:send(S1, Msg),
	assert_mbox({gen_zmq, S2, [Msg,Msg]}),
	assert_mbox_empty(),

    ok = gen_zmq:send(S2, [Msg]),
	assert_mbox({zmq, S1, Msg, []}),

    ok = erlzmq:send(S1, Msg),
	assert_mbox({gen_zmq, S2, [Msg]}),
	assert_mbox_empty(),

    ok = gen_zmq:send(S2, [Msg]),
	assert_mbox({zmq, S1, Msg, []}),
	assert_mbox_empty(),

    ok;
    
ping_pong_erlzmq_dealer({S1, S2}, Msg, passive) ->
	ok = erlzmq:send(S1, Msg),
    {ok, [Msg]} = gen_zmq:recv(S2),
    ok = gen_zmq:send(S2, [Msg]),
	{ok, Msg} = erlzmq:recv(S1),
    ok = erlzmq:send(S1, Msg, [sndmore]),
    ok = erlzmq:send(S1, Msg),
    {ok, [Msg,Msg]} = gen_zmq:recv(S2),
    ok.

ping_pong_gen_zmq_dealer({S1, S2}, Msg, active) ->
    ok = gen_zmq:send(S1, [Msg,Msg]),
	assert_mbox({zmq, S2, <<>>, [rcvmore]}),
	assert_mbox({zmq, S2, Msg, [rcvmore]}),
	assert_mbox({zmq, S2, Msg, []}),
	assert_mbox_empty(),

    ok = erlzmq:send(S2, <<>>, [sndmore]),
    ok = erlzmq:send(S2, Msg),
	assert_mbox({gen_zmq, S1, [Msg]}),
	assert_mbox_empty(),

    ok = gen_zmq:send(S1, [Msg]),
	assert_mbox({zmq, S2, <<>>, [rcvmore]}),
	assert_mbox({zmq, S2, Msg, []}),
	assert_mbox_empty(),

    ok = erlzmq:send(S2, <<>>, [sndmore]),
    ok = erlzmq:send(S2, Msg, [sndmore]),
    ok = erlzmq:send(S2, Msg),
	assert_mbox({gen_zmq, S1, [Msg,Msg]}),
	assert_mbox_empty(),

    ok;
    
ping_pong_gen_zmq_dealer({S1, S2}, Msg, passive) ->
	ok = gen_zmq:send(S1, [Msg]),
    {ok, <<>>} = erlzmq:recv(S2),
    {ok, Msg} = erlzmq:recv(S2),
    ok = erlzmq:send(S2, <<>>, [sndmore]),
    ok = erlzmq:send(S2, Msg),
	{ok, [Msg]} = gen_zmq:recv(S1),
    ok = gen_zmq:send(S1, [Msg,Msg]),
    {ok, <<>>} = erlzmq:recv(S2),
    {ok, Msg} = erlzmq:recv(S2),
    {ok, Msg} = erlzmq:recv(S2),
    ok.

dealer_ping_pong_erlzmq({S1, S2}, Msg, active) ->
    ok = erlzmq:send(S1, <<>>, [sndmore]),
    ok = erlzmq:send(S1, Msg, [sndmore]),
    ok = erlzmq:send(S1, Msg),

	assert_mbox({gen_zmq, S2, [Msg,Msg]}),
	assert_mbox_empty(),

    ok = gen_zmq:send(S2, [Msg]),
	assert_mbox({zmq, S1, <<>>, [rcvmore]}),
	assert_mbox({zmq, S1, Msg, []}),
	assert_mbox_empty(),

    ok = erlzmq:send(S1, <<>>, [sndmore]),
    ok = erlzmq:send(S1, Msg),
	assert_mbox({gen_zmq, S2, [Msg]}),
	assert_mbox_empty(),

    ok = gen_zmq:send(S2, [Msg]),
	assert_mbox({zmq, S1, <<>>, [rcvmore]}),
	assert_mbox({zmq, S1, Msg, []}),
	assert_mbox_empty(),

    ok;
    
dealer_ping_pong_erlzmq({S1, S2}, Msg, passive) ->
    ok = erlzmq:send(S1, <<>>, [sndmore]),
	ok = erlzmq:send(S1, Msg),
    {ok, [Msg]} = gen_zmq:recv(S2),
    ok = gen_zmq:send(S2, [Msg]),
	{ok, <<>>} = erlzmq:recv(S1),
	{ok, Msg} = erlzmq:recv(S1),
    ok = erlzmq:send(S1, <<>>, [sndmore]),
    ok = erlzmq:send(S1, Msg, [sndmore]),
    ok = erlzmq:send(S1, Msg),
    {ok, [Msg,Msg]} = gen_zmq:recv(S2),
    ok.

dealer_recv_loop() ->
	receive
        M ->
			ct:pal("got: ~w~n", [M]),
			dealer_recv_loop()
    after
        1000 ->
            ct:fail(timeout)
    end.

dealer_ping_pong_gen_zmq({S1, S2}, Msg, active) ->
    ok = gen_zmq:send(S1, [Msg,Msg]),
	assert_mbox({zmq, S2, Msg, [rcvmore]}),
	assert_mbox({zmq, S2, Msg, []}),
	assert_mbox_empty(),

    ok = erlzmq:send(S2, Msg),
	assert_mbox({gen_zmq, S1, [Msg]}),
	assert_mbox_empty(),

    ok = gen_zmq:send(S1, [Msg]),
	assert_mbox({zmq, S2, Msg, []}),
	assert_mbox_empty(),

    ok = erlzmq:send(S2, Msg),
	assert_mbox({gen_zmq, S1, [Msg]}),
    ok;
    
dealer_ping_pong_gen_zmq({S1, S2}, Msg, passive) ->
	ok = gen_zmq:send(S1, [Msg]),
    {ok, Msg} = erlzmq:recv(S2),
    ok = erlzmq:send(S2, Msg),
	{ok, [Msg]} = gen_zmq:recv(S1),
    ok = gen_zmq:send(S1, [Msg,Msg]),
    {ok, Msg} = erlzmq:recv(S2),
    {ok, Msg} = erlzmq:recv(S2),
    ok.

ping_pong_erlzmq_router({S1, S2}, Msg, active) ->
    ok = erlzmq:send(S1, Msg, [sndmore]),
    ok = erlzmq:send(S1, Msg),
	%% {gen_zmq, S2, {Id,[Msg,Msg]}} = 
	Id = assert_mbox_match({{gen_zmq, S2, {'$1',[Msg,Msg]}},[], ['$1']}),
	io:format("Id: ~w~n", [Id]),
	assert_mbox_empty(),

    ok = gen_zmq:send(S2, {Id, [Msg]}),
	assert_mbox({zmq, S1, Msg, []}),
	assert_mbox_empty(),

    ok = erlzmq:send(S1, Msg),
	assert_mbox({gen_zmq, S2, {Id, [Msg]}}),
	assert_mbox_empty(),

    ok = gen_zmq:send(S2, {Id, [Msg]}),
	assert_mbox({zmq, S1, Msg, []}),
	assert_mbox_empty(),

    ok;
   
ping_pong_erlzmq_router({S1, S2}, Msg, passive) ->
	ok = erlzmq:send(S1, Msg),
    {ok, {Id, [Msg]}} = gen_zmq:recv(S2),
    ok = gen_zmq:send(S2, {Id, [Msg]}),
	{ok, Msg} = erlzmq:recv(S1),
    ok = erlzmq:send(S1, Msg, [sndmore]),
    ok = erlzmq:send(S1, Msg),
    {ok, {Id, [Msg,Msg]}} = gen_zmq:recv(S2),
	ok.

ping_pong_gen_zmq_router({S1, S2}, Msg, active) ->
    ok = gen_zmq:send(S1, [Msg,Msg]),
	Id = assert_mbox_match({{zmq, S2, '$1', [rcvmore]},[], ['$1']}),
	assert_mbox({zmq, S2, <<>>, [rcvmore]}),
	assert_mbox({zmq, S2, Msg, [rcvmore]}),
	assert_mbox({zmq, S2, Msg, []}),
	assert_mbox_empty(),

    ok = erlzmq:send(S2, Id, [sndmore]),
    ok = erlzmq:send(S2, <<>>, [sndmore]),
    ok = erlzmq:send(S2, Msg),
	assert_mbox({gen_zmq, S1, [Msg]}),
	assert_mbox_empty(),

    ok = gen_zmq:send(S1, [Msg]),
	assert_mbox({zmq, S2, Id, [rcvmore]}),
	assert_mbox({zmq, S2, <<>>, [rcvmore]}),
	assert_mbox({zmq, S2, Msg, []}),
	assert_mbox_empty(),

    ok = erlzmq:send(S2, Id, [sndmore]),
    ok = erlzmq:send(S2, <<>>, [sndmore]),
    ok = erlzmq:send(S2, Msg, [sndmore]),
    ok = erlzmq:send(S2, Msg),
	assert_mbox({gen_zmq, S1, [Msg,Msg]}),
	assert_mbox_empty(),

    ok;
    
ping_pong_gen_zmq_router({S1, S2}, Msg, passive) ->
	ok = gen_zmq:send(S1, [Msg]),
    {ok, Id} = erlzmq:recv(S2),
    {ok, <<>>} = erlzmq:recv(S2),
    {ok, Msg} = erlzmq:recv(S2),
    ok = erlzmq:send(S2, Id, [sndmore]),
    ok = erlzmq:send(S2, <<>>, [sndmore]),
    ok = erlzmq:send(S2, Msg),
	{ok, [Msg]} = gen_zmq:recv(S1),
    ok = gen_zmq:send(S1, [Msg,Msg]),
    {ok, Id} = erlzmq:recv(S2),
    {ok, <<>>} = erlzmq:recv(S2),
    {ok, Msg} = erlzmq:recv(S2),
    {ok, Msg} = erlzmq:recv(S2),
    ok.

basic_tests_erlzmq(Fun, Transport, IP, Port, Type1, Type2, Mode, Size) ->
	{ok, C} = erlzmq:context(1),
    {S1, S2} = create_bound_pair_erlzmq(C, Type1, Type2, Mode, Transport, IP, Port),
	Msg = list_to_binary(string:chars($X, Size)),
    Fun({S1, S2}, Msg, Mode),
    ok = erlzmq:close(S1),
    ok = gen_zmq:close(S2),
    ok = erlzmq:term(C).

basic_tests_gen_zmq(Fun, Transport, IP, Port, Type1, Type2, Mode, Size) ->
	{ok, C} = erlzmq:context(1),
    {S1, S2} = create_bound_pair_gen_zmq(C, Type1, Type2, Mode, Transport, IP, Port),
	Msg = list_to_binary(string:chars($X, Size)),
    Fun({S1, S2}, Msg, Mode),
    ok = gen_zmq:close(S1),
    ok = erlzmq:close(S2),
    ok = erlzmq:term(C).

init_per_suite(Config) ->
	application:start(sasl),
	application:start(gen_listener_tcp),
	application:start(gen_zmq),
	Config.

end_per_suite(Config) ->
	Config.

all() ->
	case code:ensure_loaded(erlzmq) of
		{error, _} ->
			ct:pal("Skipping erlzmq tests"),
			[];
		_ ->
			[reqrep_tcp_test_active, reqrep_tcp_test_passive, reqrep_tcp_large_active, reqrep_tcp_large_passive,
			 dealerrep_tcp_test_active, dealerrep_tcp_test_passive,
			 reqdealer_tcp_test_active, reqdealer_tcp_test_passive,
			 reqrouter_tcp_test_active, reqrouter_tcp_test_passive]
	end.
