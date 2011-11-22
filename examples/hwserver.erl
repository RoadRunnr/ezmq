-module(hwserver).

-export([main/0]).

main() ->
	application:start(sasl),
	application:start(gen_listener_tcp),
	application:start(zmq),
	Opts = [{ip,{127,0,0,1}}],
	Port = 5555,

	{ok, Socket} = zmq:start([{type, rep}]),
	zmq:bind(Socket, Port, Opts),
	loop(Socket).

loop(Socket) ->
	zmq:recv(Socket),
	io:format("Received Hello~n"),
	zmq:send(Socket, [{normal,<<"World">>}]),
	loop(Socket).
