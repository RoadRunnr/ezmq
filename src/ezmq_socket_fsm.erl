%% This Source Code Form is subject to the terms of the Mozilla Public
%% License, v. 2.0. If a copy of the MPL was not distributed with this
%% file, You can obtain one at http://mozilla.org/MPL/2.0/.

-module(ezmq_socket_fsm).

%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------
-include("ezmq_debug.hrl").
-include("ezmq_internal.hrl").

-export([init/3, check/2, do/2, close/2, encap_msg/2, decap_msg/3]).

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
            {ok, MqSState#ezmq_socket{fsm = #fsm_state{module = Module, state_name = StateName, state = State}}};
        Reply ->
            {Reply, MqSState}
    end.

%% check actions do not alter the state of the FSM
check(Action, MqSState = #ezmq_socket{fsm = Fsm}) ->
    #fsm_state{module = Module, state_name = StateName, state = State} = Fsm,
    R = Module:StateName(check, Action, MqSState, State),
    ?DEBUG("ezmq_socket_fsm state: ~w, check: ~w, Result: ~w~n", [StateName, Action, R]),
    R.

do(Action, MqSState = #ezmq_socket{fsm = Fsm}) ->
    #fsm_state{module = Module, state_name = StateName, state = State} = Fsm,
    case Module:StateName(do, Action, MqSState, State) of
        {error, Reason} ->
            error_logger:error_msg("socket fsm for ~w exited with ~p, (~p,~p)~n", [Action, Reason, MqSState, State]),
            error(Reason);
        {next_state, NextStateName, NextMqSState, NextState} ->
            ?DEBUG("ezmq_socket_fsm: state: ~w, Action: ~w, next_state: ~w~n", [StateName, Action, NextStateName]),
            NewFsm = Fsm#fsm_state{state_name = NextStateName, state = NextState},
            NextMqSState#ezmq_socket{fsm = NewFsm}
    end.

close(Transport, MqSState = #ezmq_socket{fsm = Fsm}) ->
    #fsm_state{module = Module, state_name = StateName, state = State} = Fsm,
    case Module:close(StateName, Transport, MqSState, State) of
        {error, Reason} ->
            error_logger:error_msg("socket fsm for ~w exited with ~p, (~p,~p)~n", [Transport, Reason, MqSState, State]),
            error(Reason);
        {next_state, NextStateName, NextMqSState, NextState} ->
            ?DEBUG("ezmq_socket_fsm: state: ~w, Transport: ~w, next_state: ~w~n", [StateName, Transport, NextStateName]),
            NewFsm = Fsm#fsm_state{state_name = NextStateName, state = NextState},
            NextMqSState#ezmq_socket{fsm = NewFsm}
    end.

encap_msg({Transport, Msg}, MqSState = #ezmq_socket{fsm = Fsm})
  when is_pid(Transport), is_list(Msg) ->
    #fsm_state{module = Module, state_name = StateName, state = State} = Fsm,
     Module:encap_msg({Transport, Msg}, StateName, MqSState, State);
encap_msg({Transport, Msg = {Identity, Parts}}, MqSState = #ezmq_socket{fsm = Fsm})
  when is_pid(Transport), is_list(Parts) ->
    #fsm_state{module = Module, state_name = StateName, state = State} = Fsm,
     Module:encap_msg({Transport, Msg}, StateName, MqSState, State).

decap_msg(Transport, IdMsg = {_, Msg}, MqSState = #ezmq_socket{fsm = Fsm})
  when is_pid(Transport), is_list(Msg) ->
    #fsm_state{module = Module, state_name = StateName, state = State} = Fsm,
     Module:decap_msg(Transport, IdMsg, StateName, MqSState, State).
