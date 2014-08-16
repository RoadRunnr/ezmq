%% This Source Code Form is subject to the terms of the Mozilla Public
%% License, v. 2.0. If a copy of the MPL was not distributed with this
%% file, You can obtain one at http://mozilla.org/MPL/2.0/.

-module(ezmq_socket_router).

%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------
-include("ezmq_internal.hrl").

-export([init/1, close/4, encap_msg/4, decap_msg/5]).
-export([idle/4]).

-record(state, {
}).

%%%===================================================================
%%% API
%%%===================================================================

%%%===================================================================
%%% ezmq_socket callbacks
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

encap_msg({_Transport, {_Identity, Msg}}, _StateName, _MqSState, _State) ->
    ezmq:simple_encap_msg(Msg).
decap_msg(_Transport, {RemoteId, Msg}, _StateName, _MqSState, _State) ->
    {RemoteId, ezmq:simple_decap_msg(Msg)}.

idle(check, {send, _Msg}, #ezmq_socket{transports = []}, _State) ->
    {drop, not_connected};
idle(check, {send, {Identity, _Msg}}, MqSState, _State) ->
    case ezmq:transports_get(Identity, MqSState) of
        Pid when is_pid(Pid) ->
            {ok, Pid};
        _ ->
            {drop, invalid_identity}
    end;
idle(check, deliver, _MqSState, _State) ->
    ok;
idle(check, {deliver_recv, _Transport, _IdMsg}, _MqSState, _State) ->
    ok;
idle(check, recv, _MqSState, _State) ->
    ok;
idle(check, _, _MqSState, _State) ->
    {error, fsm};

idle(do, queue_send, MqSState, State) ->
    {next_state, idle, MqSState, State};
idle(do, {deliver_send, abort}, MqSState, State) ->
    {next_state, idle, MqSState, State};
idle(do, {deliver_send, Transport}, MqSState, State) ->
    MqSState1 = ezmq:lb(Transport, MqSState),
    {next_state, idle, MqSState1, State};
idle(do, {deliver, _Transport}, MqSState, State) ->
    {next_state, idle, MqSState, State};
idle(do, {queue, _Transport}, MqSState, State) ->
    {next_state, idle, MqSState, State};
idle(do, {dequeue, _Transport}, MqSState, State) ->
    {next_state, idle, MqSState, State};
idle(do, _, _MqSState, _State) ->
    {error, fsm}.
