-module(zmq_socket_fsm).

%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------
-include("zmq_internal.hrl").

-export([init/3, check/2, do/2, close/2]).

-record(fsm_state, {
		  module      :: atom(),
		  state_name  :: atom(),
		  state       :: term()
}).

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
	io:format("zmq_socket_fsm state: ~w, check: ~w, Result: ~w~n", [StateName, Action, R]),
	R.

do(Action, MqSState = #zmq_socket{fsm = Fsm}) ->
	#fsm_state{module = Module, state_name = StateName, state = State} = Fsm,
	case Module:StateName(do, Action, MqSState, State) of
		{error, Reason} ->
			error_logger:error_msg("socket fsm for ~w exited with ~p, (~p,~p)~n", [Action, Reason, MqSState, State]),
			error(Reason);
		{next_state, NextStateName, NextMqSState, NextState} ->
			io:format("zmq_socket_fsm: state: ~w, Action: ~w, next_state: ~w~n", [StateName, Action, NextStateName]),
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
			io:format("zmq_socket_fsm: state: ~w, Transport: ~w, next_state: ~w~n", [StateName, Transport, NextStateName]),
			NewFsm = Fsm#fsm_state{state_name = NextStateName, state = NextState},
			NextMqSState#zmq_socket{fsm = NewFsm}
	end.
