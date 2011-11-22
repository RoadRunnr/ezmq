-module(zmq).

-behaviour(gen_server).

%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------
-include("zmq_internal.hrl").

%% API scheduler
-export([start_link/1, start/1]).
-export([bind/3, connect/4, connect/5]).
-export([recv/1, recv/2]).
-export([send/2]).

%% Internal exports
-export([deliver_recv/2, deliver_accept/1, deliver_close/1, lb/2]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
		 terminate/2, code_change/3]).

-define(SERVER, ?MODULE). 

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @spec start_link() -> {ok, Pid} | ignore | {error, Error}
%% @end
%%--------------------------------------------------------------------

start_link(Opts) when is_list(Opts) ->
	gen_server:start_link(?MODULE, {self(), Opts}, []).
start(Opts) when is_list(Opts) ->
	gen_server:start(?MODULE, {self(), Opts}, []).

bind(Socket, Port, Opts) ->
	%%TODO: socket options
	gen_server:call(Socket, {bind, Port, Opts}).

connect(Socket, Address, Port, Opts) ->
	connect(Socket, Address, Port, Opts, infinity).
connect(Socket, Address, Port, Opts, Timeout) ->
	%%TODO: socket options
	TcpOpts = [binary, inet, {active,false}, {send_timeout,5000}, {nodelay,true}, {packet,raw}, {reuseaddr,true}],
	case gen_tcp:connect(Address, Port, TcpOpts, Timeout) of
		{ok, TcpSocket} ->
			gen_tcp:controlling_process(TcpSocket, Socket),
			gen_server:call(Socket, {connected, TcpSocket, Opts});
		Reply ->
			Reply
	end.

send(Socket, Msg) when is_pid(Socket), is_list(Msg) ->
	gen_server:call(Socket, {send, Msg}, infinity).

recv(Socket) ->
	gen_server:call(Socket, {recv, infinity}, infinity).

recv(Socket, Timeout) ->
	gen_server:call(Socket, {recv, Timeout}, infinity).

deliver_recv(Socket, Msg) ->
	gen_server:call(Socket, {deliver_recv, self(), Msg}).

deliver_accept(Socket) ->
	gen_server:call(Socket, {deliver_accept, self()}).

deliver_close(Socket) ->
	gen_server:call(Socket, {deliver_close, self()}).

%%
%% load balance sending sockets
%% - simple round robin 
%%
%% CHECK: is 0MQ actually doing anything else?
%%
lb(Transports, MqSState = #zmq_socket{transports = Trans}) when is_list(Transports) ->
	Trans1 = lists:subtract(Trans, Transports) ++ Transports,
	MqSState#zmq_socket{transports = Trans1};

lb(Transport, MqSState = #zmq_socket{transports = Trans}) ->
	Trans1 = lists:delete(Transport, Trans) ++ [Transport],
	MqSState#zmq_socket{transports = Trans1}.

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%%
%% @spec init(Args) -> {ok, State} |
%%                     {ok, State, Timeout} |
%%                     ignore |
%%                     {stop, Reason}
%% @end
%%--------------------------------------------------------------------
socket_types(Type) ->
	SupMod = [{req, zmq_socket_req},{rep, zmq_socket_rep}],
	proplists:get_value(Type, SupMod).
			
init({Owner, Opts}) ->
	case socket_types(proplists:get_value(type, Opts, req)) of
		undefined ->
			{stop, invalid_opts};
		Type ->
			init_socket(Owner, Type, Opts)
	end.

init_socket(Owner, Type, Opts) ->
	process_flag(trap_exit, true),
	MqSState = #zmq_socket{owner = Owner, pending_q = orddict:new(), listen_trans = [], transports = []},
	zmq_socket_fsm:init(Type, Opts, MqSState).

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @spec handle_call(Request, From, State) ->
%%                                   {reply, Reply, State} |
%%                                   {reply, Reply, State, Timeout} |
%%                                   {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, Reply, State} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_call({bind, Port, Opts}, _From, State) ->
	IP = case proplists:get_value(ip, Opts) of
			 undefined -> [];
			 I -> {ip, I}
		 end,
	TcpOpts = [binary,inet, {active,false}, {send_timeout,5000}, {backlog,10}, {nodelay,true}, {packet,raw}, {reuseaddr,true}],
	case zmq_tcp_socket:start_link(Port, [IP|TcpOpts]) of
		{ok, Pid} ->
			{reply, ok, State#zmq_socket{listen_trans = [Pid|State#zmq_socket.listen_trans]}};
		Reply ->
			{reply, Reply, State}
	end;

handle_call({connected, TcpSocket, _Opts}, _From, State) ->
	{ok, Transport} = zmq_link:start_connection(),
	zmq_link:connect(Transport, TcpSocket),
	State1 = State#zmq_socket{transports = [Transport|State#zmq_socket.transports]},
	{reply, ok, State1};

handle_call({recv, _Timeout}, _From, #zmq_socket{pending_recv = PendingRecv} = State)
  when PendingRecv /= none ->
	Reply = {error, already_recv},
	{reply, Reply, State};
handle_call({recv, Timeout}, From, State) ->
	handle_recv(Timeout, From, State);

handle_call({send, Msg}, _From, State) ->
	case zmq_socket_fsm:check(send, State) of
		{error, Reason} ->
			{reply, {error, Reason}, State};
		{ok, Transports} ->
			zmq_link_send(Transports, Msg),
			State1 = zmq_socket_fsm:do({deliver_send, Transports}, State),
			State2 = queue_run(State1),
			{reply, ok, State2}
	end;

handle_call({deliver_accept, Transport}, _From, State) ->
	State1 = State#zmq_socket{transports = [Transport|State#zmq_socket.transports]},
	io:format("DELIVER_ACCPET: ~p~n", [State1]),
	{reply, ok, State1};

handle_call({deliver_close, Transport}, _From, State = #zmq_socket{transports = Transports}) ->
	State0 = State#zmq_socket{transports = lists:delete(Transport, Transports)},
	State1 = queue_close(Transport, State0),
	State2 = zmq_socket_fsm:close(Transport, State1),
	State3 = queue_run(State2),
	io:format("DELIVER_CLOSE: ~p~n", [State3]),
	{reply, ok, State3};

handle_call({deliver_recv, Transport, Msg}, _From, State) ->
	handle_deliver_recv({Transport, Msg}, State).

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @spec handle_cast(Msg, State) -> {noreply, State} |
%%                                  {noreply, State, Timeout} |
%%                                  {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_cast(_Msg, State) ->
	{noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_info(recv_timeout, #zmq_socket{pending_recv = {From, _}} = State) ->
	gen_server:reply(From, {error, timeout}),
	State1 = State#zmq_socket{pending_recv = none},
	{noreply, State1};

handle_info(_Info, State) ->
	{noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @spec terminate(Reason, State) -> void()
%% @end
%%--------------------------------------------------------------------
terminate(_Reason, _State) ->
	ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @end
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
	{ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

%% check if should deliver the 'top of queue' message
queue_run(State) ->
	case zmq_socket_fsm:check(deliver, State) of
		ok -> queue_run_2(State);
		_ -> State
	end.
queue_run_2(#zmq_socket{mode = Mode} = State)
  when Mode == active; Mode == active_once ->
	run_pending_q(State);
queue_run_2(#zmq_socket{pending_recv = {_From, _Ref}} = State) ->
	run_pending_q(State);
queue_run_2(#zmq_socket{mode = passive} = State) ->
	State.

run_pending_q(State) ->
	case dequeue(State) of
		{{Transport, Msg}, State0} ->
			send_owner({Transport, Msg}, State0);
		_ ->
			State
	end.

%% send a specific message to the owner
send_owner({Transport, Msg}, #zmq_socket{pending_recv = {From, Ref}} = State) ->
	case Ref of
		none -> ok;
		_ -> erlang:cancel_timer(Ref)
	end,
	State1 = State#zmq_socket{pending_recv = none},
	gen_server:reply(From, Msg),
	zmq_socket_fsm:do({deliver, Transport}, State1);
send_owner({Transport, Msg}, #zmq_socket{owner = Owner, mode = active} = State) ->
	Owner ! {zmq, self(), Msg},
	zmq_socket_fsm:do({deliver, Transport}, State).

handle_deliver_recv({Transport, Msg}, MqSState) ->
	io:format("deliver_recv: ~w, ~w~n", [Transport, Msg]),
	case zmq_socket_fsm:check({deliver_recv, Transport}, MqSState) of
		ok ->
			MqSState0 = handle_deliver_recv_2({Transport, Msg}, queue_size(MqSState), MqSState),
			{reply, ok, MqSState0};
		{error, Reason} ->
			{reply, {error, Reason}, MqSState}
	end.

handle_deliver_recv_2({Transport, Msg}, 0, #zmq_socket{mode = Mode} = MqSState)
  when Mode == active; Mode == active_once ->
	case zmq_socket_fsm:check(deliver, MqSState) of
		ok -> send_owner({Transport, Msg}, MqSState);
		_ -> queue({Transport, Msg}, MqSState)
	end;

handle_deliver_recv_2({Transport, Msg}, 0, #zmq_socket{pending_recv = {_From, _Ref}} = MqSState) ->
	case zmq_socket_fsm:check(deliver, MqSState) of
		ok -> send_owner({Transport, Msg}, MqSState);
		_ -> queue({Transport, Msg}, MqSState)
	end;

handle_deliver_recv_2({Transport, Msg}, _, MqSState) ->
	queue({Transport, Msg}, MqSState).

handle_recv(Timeout, From, MqSState) ->
	case zmq_socket_fsm:check(recv, MqSState) of
		{error, Reason} ->
			{reply, {error, Reason}, MqSState};
		ok ->
			handle_recv_2(Timeout, From, queue_size(MqSState), MqSState)
	end.

handle_recv_2(Timeout, From, 0, State) ->
	Ref = case Timeout of
			  infinity -> none;
			  _ -> erlang:send_after(Timeout, self(), recv_timeout)
		  end,
	State1 = State#zmq_socket{pending_recv = {From, Ref}},
	{noreply, State1};

handle_recv_2(_Timeout, _From, _, State) ->
	case dequeue(State) of
		{{Transport, Msg}, State0} ->
			State2 = zmq_socket_fsm:do({deliver, Transport}, State0),
			{reply, Msg, State2};
		_ ->
			{reply, {error, internal}, State}
	end.

zmq_link_send(Transports, Msg)
  when is_list(Transports) ->
	lists:foreach(fun(T) -> zmq_link:send(T, Msg) end, Transports);
zmq_link_send(Transport, Msg) ->
	zmq_link:send(Transport, Msg).

%%
%% round robin queue
%%

queue_size(#zmq_socket{pending_q = Q}) ->
	orddict:size(Q).

queue({Transport, Msg}, MqSState = #zmq_socket{pending_q = Q}) ->
	Q1 = orddict:update(Transport, fun(V) -> queue:in(Msg, V) end,
						queue:from_list([Msg]), Q),
	MqSState1 = MqSState#zmq_socket{pending_q = Q1},
	zmq_socket_fsm:do({queue, Transport}, MqSState1).

queue_close(Transport, MqSState = #zmq_socket{pending_q = Q}) ->
	Q1 = orddict:erase(Transport, Q),
	MqSState#zmq_socket{pending_q = Q1}.
	
dequeue(MqSState = #zmq_socket{pending_q = Q, transports = Transports}) ->
	io:format("TRANS: ~p, PENDING: ~p~n", [Transports, Q]),
	case do_dequeue(Transports, Q) of
		{{Transport, Msg}, Q1} ->
			Transports1 = lists:delete(Transport, Transports) ++ [Transport],
			MqSState0 = MqSState#zmq_socket{pending_q = Q1, transports = Transports1},
			MqSState1 = zmq_socket_fsm:do({dequeue, Transport}, MqSState0),
			{{Transport, Msg}, MqSState1};
		Reply ->
			Reply
	end.

do_dequeue([], _Q) ->
	empty;
do_dequeue([Transport|Rest], Q) ->
	case orddict:find(Transport, Q) of
		{ok, V} ->
			{{value, Msg}, V1} = queue:out(V),
			Q1 = case queue:is_empty(V1) of
					 true -> orddict:erase(Transport, Q);
					 false -> orddict:store(Transport, V1, Q)
				 end,
				{{Transport, Msg}, Q1};
		_ ->
			do_dequeue(Rest, Q)
	end.
