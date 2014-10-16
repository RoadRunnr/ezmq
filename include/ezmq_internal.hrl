%% This Source Code Form is subject to the terms of the Mozilla Public
%% License, v. 2.0. If a copy of the MPL was not distributed with this
%% file, You can obtain one at http://mozilla.org/MPL/2.0/.

-define(SUPPORTED_VERSIONS, [{2,0},{1,0}]).

-record(ezmq_socket, {
          version = {2,0},
          owner                  :: pid(),
          type                   :: atom(),
          fsm                    :: term(),
          identity = <<>>        :: binary(),
          need_events = false    :: boolean(),

          %% delivery mechanism
          mode = passive         :: 'active'|'active_once'|'passive',
          recv_q = [],                                 %% the queue of all recieved messages, that are blocked by a send op
          pending_recv = none    :: tuple()|'none',
          send_q = [],                                 %% the queue of all messages to send
          pending_send = none    :: tuple()|'none',

          %% all our registered transports
          connecting    :: orddict:orddict(),
          listen_trans  :: orddict:orddict(),
          transports    :: list(),
          remote_ids    :: orddict:orddict()
}).
