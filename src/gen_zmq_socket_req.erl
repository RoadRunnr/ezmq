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

-module(gen_zmq_socket_req).

%% --------------------------------------------------------------------
%% Include files
%% --------------------------------------------------------------------
-include("gen_zmq_internal.hrl").

-export([init/1, close/4, encap_msg/4, decap_msg/5]).
-export([idle/4, pending/4, send_queued/4, reply/4]).

-record(state, {
		  last_send = none  :: pid()|'none'
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
	State1 = State#state{last_send = none},
	{next_state, idle, MqSState, State1}.

encap_msg({_Transport, Msg}, _StateName, _MqSState, _State) ->
	gen_zmq:simple_encap_msg(Msg).
decap_msg(_Transport, {_RemoteId, Msg}, _StateName, _MqSState, _State) ->
	gen_zmq:simple_decap_msg(Msg).

idle(check, {send, _Msg}, #gen_zmq_socket{transports = []}, _State) ->
	{queue, block};
idle(check, {send, _Msg}, #gen_zmq_socket{transports = [Head|_]}, _State) ->
	{ok, Head};
idle(check, _, _MqSState, _State) ->
	{error, fsm};

idle(do, {deliver_send, Transport}, MqSState, State) ->
	State1 = State#state{last_send = Transport},
	MqSState1 = gen_zmq:lb(Transport, MqSState),
	{next_state, pending, MqSState1, State1};

idle(do, queue_send, MqSState, State) ->
	{next_state, send_queued, MqSState, State};
idle(do, _, _MqSState, _State) ->
	{error, fsm}.

send_queued(check, {send, _Msg}, #gen_zmq_socket{transports = []}, _State) ->
	{queue, block};
send_queued(check, dequeue_send, #gen_zmq_socket{transports = [Head|_]}, _State) ->
	{ok, Head};
send_queued(check, dequeue_send, _MqSState, _State) ->
	keep;
send_queued(check, _, _MqSState, _State) ->
	{error, fsm};

send_queued(do, {deliver_send, Transport}, MqSState, State) ->
	State1 = State#state{last_send = Transport},
	MqSState1 = gen_zmq:lb(Transport, MqSState),
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
