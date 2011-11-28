-module(ezmq_tcp_socket).
-behaviour(gen_listener_tcp).

-include("ezmq_debug.hrl").

-define(TCP_PORT, 5555).
-define(TCP_OPTS, [binary, inet,
                   {ip,           {127,0,0,1}},
                   {active,       false},
				   {send_timeout, 5000},
                   {backlog,      10},
                   {nodelay,      true},
                   {packet,       raw},
                   {reuseaddr,    true}]).

%% --------------------------------------------------------------------
%% External exports
-export([start/2, start_link/2]).

%% gen_listener_tcp callbacks
-export([init/1, handle_accept/2, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

%%-record(state, {}).

-ifdef(debug).
-define(SERVER_OPTS,{debug,[trace]}).
-else.
-define(SERVER_OPTS,).
-endif.

%% ====================================================================
%% External functions
%% ====================================================================

%% @doc Start the server.
start(Port, Opts) ->
    gen_listener_tcp:start(?MODULE, [self(), Port, Opts], [?SERVER_OPTS]).

start_link(Port, Opts) ->
    gen_listener_tcp:start_link(?MODULE, [self(), Port, Opts], [?SERVER_OPTS]).

init([MqSocket, Port, Opts]) ->
    {ok, {Port, Opts}, MqSocket}.

handle_accept(Sock, State) ->
	case ezmq_link:start_connection() of
		{ok, Pid} ->
			ezmq_link:accept(State, Pid, Sock);
		_ ->
			error_logger:error_report([{event, accept_failed}]),
			gen_tcp:close(Sock)
	end,
    {noreply, State}.

handle_call(Request, _From, State) ->
    {reply, {illegal_request, Request}, State}.

handle_cast(_Request, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(Reason, _State) ->
	?DEBUG("ezmq_tcp_socket terminate on ~p", [Reason]),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.
