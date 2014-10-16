%% This Source Code Form is subject to the terms of the Mozilla Public
%% License, v. 2.0. If a copy of the MPL was not distributed with this
%% file, You can obtain one at http://mozilla.org/MPL/2.0/.
-module(ezmq_event_tests).

-include_lib("eunit/include/eunit.hrl").

-define(RECEIVE_TIMEOUT, 100).

complex_test_() ->
    {foreach,
        % Setup fun
        fun() ->
            application:ensure_all_started(ezmq)
        end,
        % Destruct fun
        fun(_) ->
            application:stop(ezmq)
        end,
        [
            {inorder, [
                {"Client connected/closed events test.", fun ezmq_client_events_t/0},
                {"Server accepted/closed events test.", fun ezmq_server_events_t/0},
                {"No events test.", fun no_events_t/0}
            ]}
        ]
    }.
%%++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

ezmq_server_events_t() ->
    clear_mailbox(),
    % Start server
    IP = {127,0,0,1},
    Port = 5555,
    ClientIdentity = <<"client">>,
    ServerIdentity = <<"server">>,
    {ok, ServerSocket} = ezmq:socket([{type, router}, {active, true}, {reuseaddr, true}, {identity, ServerIdentity}, {need_events, true}]),
    ?assertEqual(ok, ezmq:bind(ServerSocket, tcp, Port, [{ip, IP}])),
    receive
        {zmq_event, ServerSocket, Event} ->
            ?debugFmt("ERROR: No connections. Unhandled events: ~p~n", [Event]),
            ?assert(false)
    after
        ?RECEIVE_TIMEOUT ->
            ok
    end,
    %% Start client
    {ok, ClientSocket} = ezmq:start([{type, dealer}, {identity, ClientIdentity}]),
    ezmq:connect(ClientSocket, tcp, IP, Port, []),
    %% accepted event
    receive
        Event1 ->
            ?assertMatch({zmq_event, ServerSocket, {ClientIdentity, accepted}}, Event1)
    after
        ?RECEIVE_TIMEOUT ->
            ?debugFmt("ERROR: Missing accepted event~n", []),
            ?assert(false)
    end,
    % Wait connection established
    timer:sleep(500),
    %% Stop client
    ezmq:close(ClientSocket),
    %% closed event
    receive
        Event2 ->
            ?assertMatch({zmq_event, ServerSocket, {ClientIdentity, closed}}, Event2)
    after
        ?RECEIVE_TIMEOUT ->
            ?debugFmt("ERROR: Missing closed event~n", []),
            ?assert(false)
    end,
    %% no more events
    receive
        Event3 ->
            ?debugFmt("ERROR: Unknown event ~p~n", [Event3]),
            ?assert(false)
    after
        ?RECEIVE_TIMEOUT ->
            ok
    end,
    ezmq:close(ServerSocket).
%%++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

ezmq_client_events_t() ->
    clear_mailbox(),
    % Start server
    IP = {127,0,0,1},
    Port = 5555,
    ClientIdentity = <<"client">>,
    ServerIdentity = <<"server">>,
    {ok, ServerSocket} = ezmq:socket([{type, router}, {active, true}, {reuseaddr, true}, {identity, ServerIdentity}]),
    ?assertEqual(ok, ezmq:bind(ServerSocket, tcp, Port, [{ip, IP}])),
    receive
        {zmq_event, ServerSocket, Event} ->
            ?debugFmt("ERROR: No connections. Unhandled events: ~p~n", [Event]),
            ?assert(false)
    after
        ?RECEIVE_TIMEOUT ->
            ok
    end,
    %% Start client
    {ok, ClientSocket} = ezmq:start([{type, dealer}, {identity, ClientIdentity}, {need_events, true}]),
    ezmq:connect(ClientSocket, tcp, IP, Port, []),
    %% connected event
    receive
        Event1 ->
            ?assertMatch({zmq_event, ClientSocket, {ServerIdentity, connected}}, Event1)
    after
        ?RECEIVE_TIMEOUT ->
            ?debugFmt("ERROR: Missing connected event~n", []),
            ?assert(false)
    end,
    % Wait connection established
    timer:sleep(500),
    %% Stop client
    ezmq:close(ClientSocket),
    %% closed event
    receive
        Event2 ->
            ?assertMatch({zmq_event, ClientSocket, {ServerIdentity, closed}}, Event2)
    after
        ?RECEIVE_TIMEOUT ->
            ?debugFmt("ERROR: Missing closed event~n", []),
            ?assert(false)
    end,
    %% no more events
    receive
        Event3 ->
            ?debugFmt("ERROR: Unknown event ~p~n", [Event3]),
            ?assert(false)
    after
        ?RECEIVE_TIMEOUT ->
            ok
    end,
    ezmq:close(ServerSocket).
%%++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

no_events_t() ->
    clear_mailbox(),
    % Start server
    IP = {127,0,0,1},
    Port = 5555,
    ClientIdentity = <<"client">>,
    ServerIdentity = <<"server">>,
    {ok, ServerSocket} = ezmq:socket([{type, router}, {active, true}, {identity, ServerIdentity}, {reuseaddr, true}]),
    ?assertEqual(ok, ezmq:bind(ServerSocket, tcp, Port, [{ip, IP}])),
    %% Start client
    {ok, ClientSocket} = ezmq:start([{type, dealer}, {identity, ClientIdentity}]),
    ezmq:connect(ClientSocket, tcp, IP, Port, []),
    % Wait connection established
    timer:sleep(500),
    %% Stop client
    ezmq:close(ClientSocket),
    ezmq:close(ServerSocket),
    receive
        {zmq_event, From, Event} ->
            ?debugFmt("ERROR: No ZMQ event from ~p: ~p~n", [From, Event]),
            ?assert(false)
    after
        ?RECEIVE_TIMEOUT ->
            ok
    end.
%%++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

clear_mailbox() ->
    receive
        _Any ->
            clear_mailbox()
    after 0 ->
        ok
    end.
%%++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++