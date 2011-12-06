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

-record(gen_zmq_socket, {
		  owner                  :: pid(),
		  fsm                    :: term(),
		  identity = <<>>        :: binary(),

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
