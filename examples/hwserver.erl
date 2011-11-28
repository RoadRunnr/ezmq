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
	ezmq:send(Socket, [{normal,<<"World">>}]),
	loop(Socket).
