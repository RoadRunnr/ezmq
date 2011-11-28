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

-module(ezmq_socket_dealer).

%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------
-include("ezmq_internal.hrl").

-export([init/1, close/4, encap_msg/4, decap_msg/4]).
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

encap_msg({_Transport, Msg}, _StateName, _MqSState, _State) ->
	ezmq:simple_encap_msg(Msg).
decap_msg({_Transport, Msg}, _StateName, _MqSState, _State) ->
	ezmq:simple_decap_msg(Msg).

idle(check, {send, _Msg}, #ezmq_socket{transports = []}, _State) ->
	{queue, block};
idle(check, {send, _Msg}, #ezmq_socket{transports = [Head|_]}, _State) ->
	{ok, Head};
idle(check, dequeue_send, #ezmq_socket{transports = [Head|_]}, _State) ->
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
