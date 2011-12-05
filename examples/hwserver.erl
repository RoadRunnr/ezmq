-module(hwserver).

-export([main/0]).

main() ->
	application:start(sasl),
	application:start(gen_listener_tcp),
	application:start(gen_zmq),
	Opts = [{ip,{127,0,0,1}}],
	Port = 5555,

	{ok, Socket} = gen_zmq:start([{type, rep}]),
	gen_zmq:bind(Socket, Port, Opts),
	loop(Socket).

loop(Socket) ->
	gen_zmq:recv(Socket),
	io:format("Received Hello~n"),
	gen_zmq:send(Socket, [<<"World">>]),
	loop(Socket).
