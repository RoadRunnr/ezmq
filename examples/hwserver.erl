%% This Source Code Form is subject to the terms of the Mozilla Public
%% License, v. 2.0. If a copy of the MPL was not distributed with this
%% file, You can obtain one at http://mozilla.org/MPL/2.0/.

-module(hwserver).

-export([main/0]).

main() ->
	application:start(sasl),
	application:start(gen_listener_tcp),
	application:start(ezmq),
	Opts = [{ip,{127,0,0,1}}],
	Port = 5555,

	{ok, Socket} = ezmq:start([{type, rep}]),
	ezmq:bind(Socket, Port, Opts),
	loop(Socket).

loop(Socket) ->
	ezmq:recv(Socket),
	io:format("Received Hello~n"),
	ezmq:send(Socket, [<<"World">>]),
	loop(Socket).
