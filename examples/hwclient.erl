-module(hwclient).

-export([main/0]).

main() ->
	application:start(sasl),
	application:start(gen_listener_tcp),
	application:start(zmq),

	{ok, Socket} = zmq:start([{type, req}]),
	zmq:connect(Socket, {127,0,0,1}, 5555, []),
	loop(Socket, 0).

loop(_Socket, 10) ->
	ok;
loop(Socket, N) ->
	io:format("Sending Hello ~w ...~n",[N]),
	zmq:send(Socket, [{normal,<<"Hello",0>>}]),
	zmq:recv(Socket),
	io:format("Received World ~w~n", [N]),
	loop(Socket, N+1).
