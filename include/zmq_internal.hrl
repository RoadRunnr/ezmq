-record(zmq_socket, {
		  owner      :: pid(),
		  fsm        :: term(),

		  %% delivery mechanism
		  mode = passive         :: 'active'|'active_once'|'passive',
		  recv_q = [],                                 %% the queue of all recieved messages, that are blocked by a send op
		  pending_recv = none    :: tuple()|'none',
		  send_q = [],                                 %% the queue of all messages to send
		  pending_send = none    :: tuple()|'none',

		  %% all our registered transports
		  connecting    :: orddict:orddict(),
		  listen_trans  :: orddict:orddict(),
		  transports    :: list()
}).
