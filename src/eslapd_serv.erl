
-module('eslapd_serv').
-author('firstyear@redhat.com').
-behaviour(gen_server).

-record(state, {socket, next}).

-export([start_link/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, code_change/3, terminate/2]).

-define(SOCK(Data), {tcp, _Port, Data}).

start_link(Socket) ->
    gen_server:start_link(?MODULE, Socket, []).

init(Socket) ->
    <<A:32, B:32, C:32>> = crypto:rand_bytes(12),
    random:seed({A,B,C}),
    gen_server:cast(self(), accept),
    io:fwrite("Init Pid ~p~n", [self()]),
    { ok, #state{socket=Socket}}.


handle_cast(accept, S = #state{socket=Socket}) ->
    {ok, AcceptSocket} = gen_tcp:accept(Socket),
    eslapd:start_socket(), % Replace the acceptor we just consumed
    io:fwrite("Accepted Socket ~p~n", [self()]),
    % gen_server:cast(self(), recv),
    {noreply, S#state{socket=AcceptSocket, next=listen}}.

%handle_cast(action, S = #state{socket=Socket})->
%    % Do something
%    send(Socket, Data)
%    {noreply, S#state{next=listen}}

handle_info(?SOCK(Data), S = #state{next=listen}) ->
    io:fwrite("~p ~n", [Data]),
    % Send to the protocol handler.
    % Send off a response.
    {noreply, S#state{next=listen}}.

handle_call(_E, _From, State) ->
    io:fwrite("Handle Call~p~n", [_E]),
    {noreply, State}.

%handle_info(_E, State) ->
%    io:fwrite("Handle Info~p~n", [_E]),
%    {noreply, State}.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.


terminate(normal, _State) ->
    ok;
terminate(_Reason, _State) ->
    io:format("Terminate reason: ~p~n", [_Reason]).

% Server protocol handler

handle_ldapmsg(S, LDAPMessage) ->
    case LDAPMessage of
        {ok, {'LDAPMessage', MsgID, ProtocolOp, Controls}} ->
            {ok, Result} = handle_op(MsgID, ProtocolOp, Controls),
            io:fwrite("~p ~n", [Result]),
            % This doesn't seem to actually send the data ...
            % Maybe there is a socket option I am missing
            gen_tcp:send(S, Result),
            gen_tcp:shutdown(S);
        {ok, _} ->
            io:fwrite("ASN Decoded, but not to an LDAPMessage, Closing socket ~p~n", [S]),
            get_tcp:close(S);
        _ ->
            io:fwrite("Unknown protocol, Closing socket ~p~n", [S])
    end.

% The protocol Op contains the choice and the details in it.
handle_op(MsgID, ProtocolOp, Controls) ->
    io:fwrite("~p ~p ~p ~n", [MsgID, ProtocolOp, Controls]),
    Result = case ProtocolOp of
            % How do we handle bad encodings?
        _ -> 'ELDAPv3':encode('LDAPResult', {'LDAPResult', unwillingToPerform, <<""/utf8>>, <<"Operation not implemented"/utf8>>, asn1_NOVALUE})
    end,
    Result.
