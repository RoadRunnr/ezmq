-module(zmq_socket_req).

%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------
-include("zmq_internal.hrl").

-export([init/1, close/4, idle/4, pending/4, send_queued/4, reply/4]).

-record(state, {
		  last_send = none  :: pid()|'none'
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
	State1 = State#state{last_send = none},
	{next_state, idle, MqSState, State1}.

idle(check, send, #zmq_socket{transports = []}, _State) ->
	{queue, block};
idle(check, send, #zmq_socket{transports = [Head|_]}, _State) ->
	{ok, Head};
idle(check, _, _MqSState, _State) ->
	{error, fsm};

idle(do, {deliver_send, Transport}, MqSState, State) ->
	State1 = State#state{last_send = Transport},
	MqSState1 = zmq:lb(Transport, MqSState),
	{next_state, pending, MqSState1, State1};

idle(do, queue_send, MqSState, State) ->
	{next_state, send_queued, MqSState, State};
idle(do, _, _MqSState, _State) ->
	{error, fsm}.

send_queued(check, send, #zmq_socket{transports = []}, _State) ->
	{queue, block};
send_queued(check, dequeue_send, #zmq_socket{transports = [Head|_]}, _State) ->
	{ok, Head};
send_queued(check, dequeue_send, _MqSState, _State) ->
	keep;
send_queued(check, _, _MqSState, _State) ->
	{error, fsm};

send_queued(do, {deliver_send, Transport}, MqSState, State) ->
	State1 = State#state{last_send = Transport},
	MqSState1 = zmq:lb(Transport, MqSState),
	{next_state, pending, MqSState1, State1};
send_queued(do, _, _MqSState, _State) ->
	{error, fsm}.

pending(check, recv, _MqSState, _State) ->
	ok;
pending(check, {deliver_recv, Transport}, _MqSState, State)
  when State#state.last_send == Transport ->
	ok;
pending(check, deliver, _MqSState, _State) ->
	ok;
pending(check, _, _MqSState, _State) ->
	{error, fsm};

pending(do, {queue, _Transport}, MqSState, State) ->
	{next_state, reply, MqSState, State};
pending(do, {deliver, Transport}, MqSState, State)
  when State#state.last_send == Transport ->
	State1 = State#state{last_send = none},
	{next_state, idle, MqSState, State1};
pending(do, _, _MqSState, _State) ->
	{error, fsm}.

reply(check, recv, _MqSState, _State) ->
	ok;
reply(check, deliver, _MqSState, _State) ->
	ok;
reply(check, _, _MqSState, _State) ->
	{error, fsm};

reply(do, {dequeue, _Transport}, MqSState, State) ->
	{next_state, reply, MqSState, State};
reply(do, {deliver, _Transport}, MqSState, State) ->
	State1 = State#state{last_send = none},
	{next_state, idle, MqSState, State1};

reply(do, _, _MqSState, _State) ->
	{error, fsm}.
