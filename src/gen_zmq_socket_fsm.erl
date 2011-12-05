% Copyright 2010-2011, Travelping GmbH <info@travelping.com>

% Permission is hereby granted, free of charge, to any person obtaining a
% copy of this software and associated documentation files (the "Software"),
% to deal in the Software without restriction, including without limitation
% the rights to use, copy, modify, merge, publish, distribute, sublicense,
% and/or sell copies of the Software, and to permit persons to whom the
% Software is furnished to do so, subject to the following conditions:

% The above copyright notice and this permission notice shall be included in
% all copies or substantial portions of the Software.

% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
% FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
% DEALINGS IN THE SOFTWARE.

-module(gen_zmq_socket_fsm).

%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------
-include("gen_zmq_debug.hrl").
-include("gen_zmq_internal.hrl").

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
			{ok, MqSState#gen_zmq_socket{fsm = #fsm_state{module = Module, state_name = StateName, state = State}}};
		Reply ->
			{Reply, MqSState}
	end.

%% check actions do not alter the state of the FSM
check(Action, MqSState = #gen_zmq_socket{fsm = Fsm}) ->
	#fsm_state{module = Module, state_name = StateName, state = State} = Fsm,
	R = Module:StateName(check, Action, MqSState, State),
	?DEBUG("gen_zmq_socket_fsm state: ~w, check: ~w, Result: ~w~n", [StateName, Action, R]),
	R.

do(Action, MqSState = #gen_zmq_socket{fsm = Fsm}) ->
	#fsm_state{module = Module, state_name = StateName, state = State} = Fsm,
	case Module:StateName(do, Action, MqSState, State) of
		{error, Reason} ->
			error_logger:error_msg("socket fsm for ~w exited with ~p, (~p,~p)~n", [Action, Reason, MqSState, State]),
			error(Reason);
		{next_state, NextStateName, NextMqSState, NextState} ->
			?DEBUG("gen_zmq_socket_fsm: state: ~w, Action: ~w, next_state: ~w~n", [StateName, Action, NextStateName]),
			NewFsm = Fsm#fsm_state{state_name = NextStateName, state = NextState},
			NextMqSState#gen_zmq_socket{fsm = NewFsm}
	end.

close(Transport, MqSState = #gen_zmq_socket{fsm = Fsm}) ->
	#fsm_state{module = Module, state_name = StateName, state = State} = Fsm,
	case Module:close(StateName, Transport, MqSState, State) of
		{error, Reason} ->
			error_logger:error_msg("socket fsm for ~w exited with ~p, (~p,~p)~n", [Transport, Reason, MqSState, State]),
			error(Reason);
		{next_state, NextStateName, NextMqSState, NextState} ->
			?DEBUG("gen_zmq_socket_fsm: state: ~w, Transport: ~w, next_state: ~w~n", [StateName, Transport, NextStateName]),
			NewFsm = Fsm#fsm_state{state_name = NextStateName, state = NextState},
			NextMqSState#gen_zmq_socket{fsm = NewFsm}
	end.

encap_msg({Transport, Msg}, MqSState = #gen_zmq_socket{fsm = Fsm})
  when is_pid(Transport), is_list(Msg) ->
	#fsm_state{module = Module, state_name = StateName, state = State} = Fsm,
	 Module:encap_msg({Transport, Msg}, StateName, MqSState, State);
encap_msg({Transport, Msg = {Identity, Parts}}, MqSState = #gen_zmq_socket{fsm = Fsm})
  when is_pid(Transport), is_pid(Identity), is_list(Parts) ->
	#fsm_state{module = Module, state_name = StateName, state = State} = Fsm,
	 Module:encap_msg({Transport, Msg}, StateName, MqSState, State).

decap_msg({Transport, Msg}, MqSState = #gen_zmq_socket{fsm = Fsm})
  when is_pid(Transport), is_list(Msg) ->
	#fsm_state{module = Module, state_name = StateName, state = State} = Fsm,
	 Module:decap_msg({Transport, Msg}, StateName, MqSState, State).
