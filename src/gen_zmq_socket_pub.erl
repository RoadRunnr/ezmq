%% This Source Code Form is subject to the terms of the Mozilla Public
%% License, v. 2.0. If a copy of the MPL was not distributed with this
%% file, You can obtain one at http://mozilla.org/MPL/2.0/.

-module(gen_zmq_socket_pub).

%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------
-include("gen_zmq_internal.hrl").

-export([init/1, close/4, encap_msg/4, decap_msg/5]).
-export([idle/4]).

-record(state, {
}).

%%%===================================================================
%%% API
%%%===================================================================

%%%===================================================================
%%% gen_zmq_socket callbacks
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

encap_msg({_Transport, Msg}, _StateName, _MqSState, _State) ->
    gen_zmq:simple_encap_msg(Msg).
decap_msg(_Transport, {_RemoteId, Msg}, _StateName, _MqSState, _State) ->
    gen_zmq:simple_decap_msg(Msg).

idle(check, {send, _Msg}, #gen_zmq_socket{transports = []}, _State) ->
    {queue, block};
idle(check, {send, _Msg}, #gen_zmq_socket{transports = Transports}, _State) ->
    {ok, Transports};
idle(check, dequeue_send, #gen_zmq_socket{transports = Transports}, _State) ->
    {ok, Transports};
idle(check, dequeue_send, _MqSState, _State) ->
    keep;
idle(check, _, _MqSState, _State) ->
    {error, fsm};

idle(do, queue_send, MqSState, State) ->
    {next_state, idle, MqSState, State};
idle(do, {deliver_send, _Transport}, MqSState, State) ->
    {next_state, idle, MqSState, State};
idle(do, _, _MqSState, _State) ->
    {error, fsm}.
