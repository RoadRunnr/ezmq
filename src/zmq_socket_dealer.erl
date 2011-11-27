-module(zmq_socket_dealer).

%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------
-include("zmq_internal.hrl").

-export([init/1, close/4, idle/4]).

-record(state, {
}).

%%%===================================================================
%%% API
%%%===================================================================

%%%===================================================================
%%% zmq_socket callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the Fsm
%%
%% @spec init(Args) -> {ok, StateName, State} |
%%                     {stop, Reason}
%% @end
%%--------------------------------------------------------------------

init(_Opts) ->
	{ok, idle, #state{}}.

close(_StateName, _Transport, MqSState, State) ->
	{next_state, idle, MqSState, State}.

idle(check, send, #zmq_socket{transports = []}, _State) ->
	{queue, block};
idle(check, send, #zmq_socket{transports = [Head|_]}, _State) ->
	{ok, Head};
idle(check, dequeue_send, #zmq_socket{transports = [Head|_]}, _State) ->
	{ok, Head};
idle(check, dequeue_send, _MqSState, _State) ->
	keep;
idle(check, deliver, _MqSState, _State) ->
	ok;
idle(check, {deliver_recv, _Transport}, _MqSState, _State) ->
	ok;
idle(check, recv, _MqSState, _State) ->
	ok;
idle(check, _, _MqSState, _State) ->
	{error, fsm};

idle(do, queue_send, MqSState, State) ->
	{next_state, idle, MqSState, State};
idle(do, {deliver_send, Transport}, MqSState, State) ->
	MqSState1 = zmq:lb(Transport, MqSState),
	{next_state, idle, MqSState1, State};
idle(do, {deliver, _Transport}, MqSState, State) ->
	{next_state, idle, MqSState, State};
idle(do, {queue, _Transport}, MqSState, State) ->
	{next_state, idle, MqSState, State};
idle(do, {dequeue, _Transport}, MqSState, State) ->
	{next_state, idle, MqSState, State};
idle(do, _, _MqSState, _State) ->
	{error, fsm}.
