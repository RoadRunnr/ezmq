-module(zmq_socket_fsm).

%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------
-include("zmq_debug.hrl").
-include("zmq_internal.hrl").

-export([init/3, check/2, do/2, close/2, encap_msg/2, decap_msg/2]).

-record(fsm_state, {
		  module      :: atom(),
		  state_name  :: atom(),
		  state       :: term()
}).

-type transport()  :: pid().
-type check_type() :: 'send' | 'dequeue_send' | 'deliver' | 'deliver_recv' | 'recv'.
-type do_type()    :: 'queue_send' | {'deliver_send', list(transport())} | {'deliver', transport()} | {'queue', transport()} | {'dequeue', transport()}.

init(Module, Opts, MqSState) ->
	case Module:init(Opts) of
		{ok, StateName, State} ->
			{ok, MqSState#zmq_socket{fsm = #fsm_state{module = Module, state_name = StateName, state = State}}};
		Reply ->
			{Reply, MqSState}
	end.

%% check actions do not alter the state of the FSM
check(Action, MqSState = #zmq_socket{fsm = Fsm}) ->
	#fsm_state{module = Module, state_name = StateName, state = State} = Fsm,
	R = Module:StateName(check, Action, MqSState, State),
	?DEBUG("zmq_socket_fsm state: ~w, check: ~w, Result: ~w~n", [StateName, Action, R]),
	R.

do(Action, MqSState = #zmq_socket{fsm = Fsm}) ->
	#fsm_state{module = Module, state_name = StateName, state = State} = Fsm,
	case Module:StateName(do, Action, MqSState, State) of
		{error, Reason} ->
			error_logger:error_msg("socket fsm for ~w exited with ~p, (~p,~p)~n", [Action, Reason, MqSState, State]),
			error(Reason);
		{next_state, NextStateName, NextMqSState, NextState} ->
			?DEBUG("zmq_socket_fsm: state: ~w, Action: ~w, next_state: ~w~n", [StateName, Action, NextStateName]),
			NewFsm = Fsm#fsm_state{state_name = NextStateName, state = NextState},
			NextMqSState#zmq_socket{fsm = NewFsm}
	end.

close(Transport, MqSState = #zmq_socket{fsm = Fsm}) ->
	#fsm_state{module = Module, state_name = StateName, state = State} = Fsm,
	case Module:close(StateName, Transport, MqSState, State) of
		{error, Reason} ->
			error_logger:error_msg("socket fsm for ~w exited with ~p, (~p,~p)~n", [Transport, Reason, MqSState, State]),
			error(Reason);
		{next_state, NextStateName, NextMqSState, NextState} ->
			?DEBUG("zmq_socket_fsm: state: ~w, Transport: ~w, next_state: ~w~n", [StateName, Transport, NextStateName]),
			NewFsm = Fsm#fsm_state{state_name = NextStateName, state = NextState},
			NextMqSState#zmq_socket{fsm = NewFsm}
	end.

encap_msg({Transport, Msg}, MqSState = #zmq_socket{fsm = Fsm}) when is_pid(Transport), is_list(Msg) ->
	#fsm_state{module = Module, state_name = StateName, state = State} = Fsm,
	 Module:encap_msg({Transport, Msg}, StateName, MqSState, State).
decap_msg({Transport, Msg}, MqSState = #zmq_socket{fsm = Fsm}) when is_pid(Transport), is_list(Msg) ->
	#fsm_state{module = Module, state_name = StateName, state = State} = Fsm,
	 Module:decap_msg({Transport, Msg}, StateName, MqSState, State).
