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

-module(ezmq_zmq2_SUITE).

-compile(export_all).

-include_lib("common_test/include/ct.hrl").

reqrep_tcp_test_active(_Config) ->
    basic_tests(fun ping_pong/3, "tcp://127.0.0.1:5555", {127,0,0,1}, 5555, req, rep, active, 3).
reqrep_tcp_test_passive(_Config) ->
    basic_tests(fun ping_pong/3, "tcp://127.0.0.1:5556", {127,0,0,1}, 5556, req, rep, passive, 3).

reqrep_tcp_large_active(_Config) ->
    basic_tests(fun ping_pong/3, "tcp://127.0.0.1:5557", {127,0,0,1}, 5557, req, rep, active, 256).
reqrep_tcp_large_passive(_Config) ->
    basic_tests(fun ping_pong/3, "tcp://127.0.0.1:5558", {127,0,0,1}, 5558, req, rep, passive, 256).

dealerrep_tcp_test_active(_Config) ->
    basic_tests(fun dealer_ping_pong/3, "tcp://127.0.0.1:5559", {127,0,0,1}, 5559, dealer, rep, active, 3).
dealerrep_tcp_test_passive(_Config) ->
    basic_tests(fun dealer_ping_pong/3, "tcp://127.0.0.1:5560", {127,0,0,1}, 5560, dealer, rep, passive, 3).

reqdealer_tcp_test_active(_Config) ->
    basic_tests(fun ping_pong/3, "tcp://127.0.0.1:5561", {127,0,0,1}, 5561, req, dealer, active, 3).
reqdealer_tcp_test_passive(_Config) ->
    basic_tests(fun ping_pong/3, "tcp://127.0.0.1:5562", {127,0,0,1}, 5562, req, dealer, passive, 3).

reqrouter_tcp_test_active(_Config) ->
    basic_tests(fun ping_pong_router/3, "tcp://127.0.0.1:5561", {127,0,0,1}, 5561, req, router, active, 3).
reqrouter_tcp_test_passive(_Config) ->
    basic_tests(fun ping_pong_router/3, "tcp://127.0.0.1:5562", {127,0,0,1}, 5562, req, router, passive, 3).

create_bound_pair(Ctx, Type1, Type2, Mode, Transport, IP, Port) ->
    Active = if
        Mode =:= active ->
            true;
        Mode =:= passive ->
            false
    end,
	{ok, S1} = erlzmq:socket(Ctx, [Type1, {active, Active}]),
    {ok, S2} = ezmq:socket([{type, Type2}, {active, Active}]),
	ok = erlzmq:bind(S1, Transport),
    ok = ezmq:connect(S2, IP, Port, []),
    {S1, S2}.

ping_pong({S1, S2}, Msg, active) ->
    ok = erlzmq:send(S1, Msg, [sndmore]),
    ok = erlzmq:send(S1, Msg),
    receive
        {ezmq, S2, [Msg,Msg]} ->
            ok
    after
        1000 ->
            ct:fail(timeout)
    end,
    ok = ezmq:send(S2, [Msg]),
    receive
        {zmq, S1, Msg, []} ->
            ok
    after
        1000 ->
            ct:fail(timeout)
    end,
    ok = erlzmq:send(S1, Msg),
    receive
        {ezmq, S2, [Msg]} ->
            ok
    after
        1000 ->
            ct:fail(timeout)
    end,
    ok = ezmq:send(S2, [Msg]),
    receive
        {zmq, S1, Msg, []} ->
            ok
    after
        1000 ->
            ct:fail(timeout)
    end,
    ok;
    
ping_pong({S1, S2}, Msg, passive) ->
	ok = erlzmq:send(S1, Msg),
    {ok, [Msg]} = ezmq:recv(S2),
    ok = ezmq:send(S2, [Msg]),
	{ok, Msg} = erlzmq:recv(S1),
    ok = erlzmq:send(S1, Msg, [sndmore]),
    ok = erlzmq:send(S1, Msg),
    {ok, [Msg,Msg]} = ezmq:recv(S2),
    ok.

dealer_ping_pong({S1, S2}, Msg, active) ->
    ok = erlzmq:send(S1, <<>>, [sndmore]),
    ok = erlzmq:send(S1, Msg, [sndmore]),
    ok = erlzmq:send(S1, Msg),
    receive
        {ezmq, S2, [Msg,Msg]} ->
            ok
    after
        1000 ->
            ct:fail(timeout)
    end,
    ok = ezmq:send(S2, [Msg]),
    receive
        {zmq, S1, Msg, []} ->
            ok
    after
        1000 ->
            ct:fail(timeout)
    end,
    ok = erlzmq:send(S1, <<>>, [sndmore]),
    ok = erlzmq:send(S1, Msg),
    receive
        {ezmq, S2, [Msg]} ->
            ok
    after
        1000 ->
            ct:fail(timeout)
    end,
    ok = ezmq:send(S2, [Msg]),
    receive
        {zmq, S1, Msg, []} ->
            ok
    after
        1000 ->
            ct:fail(timeout)
    end,
    ok;
    
dealer_ping_pong({S1, S2}, Msg, passive) ->
    ok = erlzmq:send(S1, <<>>, [sndmore]),
	ok = erlzmq:send(S1, Msg),
    {ok, [Msg]} = ezmq:recv(S2),
    ok = ezmq:send(S2, [Msg]),
	{ok, <<>>} = erlzmq:recv(S1),
	{ok, Msg} = erlzmq:recv(S1),
    ok = erlzmq:send(S1, <<>>, [sndmore]),
    ok = erlzmq:send(S1, Msg, [sndmore]),
    ok = erlzmq:send(S1, Msg),
    {ok, [Msg,Msg]} = ezmq:recv(S2),
    ok.

ping_pong_router({S1, S2}, Msg, active) ->
    ok = erlzmq:send(S1, Msg, [sndmore]),
    ok = erlzmq:send(S1, Msg),
    P = receive
        {ezmq, S2, {Pid,[Msg,Msg]}} ->
            Pid
    after
        1000 ->
            ct:fail(timeout)
    end,
    ok = ezmq:send(S2, {P, [Msg]}),
    receive
        {zmq, S1, Msg, []} ->
            ok
    after
        1000 ->
            ct:fail(timeout)
    end,
    ok = erlzmq:send(S1, Msg),
    receive
        {ezmq, S2, {P, [Msg]}} ->
            ok
    after
        1000 ->
            ct:fail(timeout)
    end,
    ok = ezmq:send(S2, {P, [Msg]}),
    receive
        {zmq, S1, Msg, []} ->
            ok
    after
        1000 ->
            ct:fail(timeout)
    end,
    ok;
    
ping_pong_router({S1, S2}, Msg, passive) ->
	ok = erlzmq:send(S1, Msg),
    {ok, {Id, [Msg]}} = ezmq:recv(S2),
    ok = ezmq:send(S2, {Id, [Msg]}),
	{ok, Msg} = erlzmq:recv(S1),
    ok = erlzmq:send(S1, Msg, [sndmore]),
    ok = erlzmq:send(S1, Msg),
    {ok, {Id, [Msg,Msg]}} = ezmq:recv(S2),
    ok.

basic_tests(Fun, Transport, IP, Port, Type1, Type2, Mode, Size) ->
	{ok, C} = erlzmq:context(1),
    {S1, S2} = create_bound_pair(C, Type1, Type2, Mode, Transport, IP, Port),
	Msg = list_to_binary(string:chars($X, Size)),
    Fun({S1, S2}, Msg, Mode),
    ok = erlzmq:close(S1),
    ok = ezmq:close(S2),
    ok = erlzmq:term(C).

init_per_suite(Config) ->
	application:start(sasl),
	application:start(gen_listener_tcp),
	application:start(ezmq),
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
			 reqrouter_tcp_test_active, reqrouter_tcp_test_passive
			]
	end.
