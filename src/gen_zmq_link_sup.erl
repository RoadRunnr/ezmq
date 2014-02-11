%% This Source Code Form is subject to the terms of the Mozilla Public
%% License, v. 2.0. If a copy of the MPL was not distributed with this
%% file, You can obtain one at http://mozilla.org/MPL/2.0/.

-module(gen_zmq_link_sup).

-behaviour(supervisor).

%% API
-export([start_link/0]).
-export([start_connection/0, datapaths/0]).

%% Supervisor callbacks
-export([init/1]).

%% ===================================================================
%% API functions
%% ===================================================================

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

start_connection() ->
    supervisor:start_child(?MODULE, []).

datapaths() ->
    lists:map(fun({_, Child, _, _}) -> Child end, supervisor:which_children(?MODULE)).

%% ===================================================================
%% Supervisor callbacks
%% ===================================================================

init([]) ->
    {ok, {{simple_one_for_one, 0, 1},
          [{gen_zmq_link, {gen_zmq_link, start_link, []},
            temporary, brutal_kill, worker, [gen_zmq_link]}]}}.
