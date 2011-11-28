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
	ezmq:send(Socket, [{normal,<<"Hello",0>>}]),
	ezmq:recv(Socket),
	io:format("Received World ~w~n", [N]),
	loop(Socket, N+1).
