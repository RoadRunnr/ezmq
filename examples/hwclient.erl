%% This Source Code Form is subject to the terms of the Mozilla Public
%% License, v. 2.0. If a copy of the MPL was not distributed with this
%% file, You can obtain one at http://mozilla.org/MPL/2.0/.

-module(hwclient).

-export([main/0]).

main() ->
	application:start(sasl),
	application:start(gen_listener_tcp),
	application:start(ezmq),

	{ok, Socket} = ezmq:start([{type, req}]),
	ezmq:connect(Socket, {127,0,0,1}, 5555, []),
	loop(Socket, 0).

loop(_Socket, 10) ->
	ok;
loop(Socket, N) ->
	io:format("Sending Hello ~w ...~n",[N]),
	ezmq:send(Socket, [<<"Hello",0>>]),
	{ok, R} = ezmq:recv(Socket),
	io:format("Received '~s' ~w~n", [R, N]),
	loop(Socket, N+1).
