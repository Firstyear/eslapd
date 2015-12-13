
-module('eslapd_serv').
-author('firstyear@redhat.com').
-behaviour(gen_server).

-record(state, {socket, next, msgid}).

-export([start_link/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, code_change/3, terminate/2]).
-export([handle_ldapmsg/1]).

% -include_lib("eldap/include/eldap.hrl").
-include("ELDAPv3.hrl").
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
    {noreply, S#state{socket=AcceptSocket, next=listen, msgid=1}}.

%handle_cast(action, S = #state{socket=Socket})->
%    % Do something
%    send(Socket, Data)
%    {noreply, S#state{next=listen}}

handle_info(?SOCK(Data), S = #state{next=listen,socket=Socket}) ->
    io:fwrite("~p ~n", [Data]),
    {Status, Response} = handle_ldapmsg(Data),
    gen_tcp:send(Socket, Response),
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

% This needs a total rethink ...

handle_ldapmsg(ClientData) ->
    LDAPMessage = 'ELDAPv3':decode('LDAPMessage', ClientData),
    case LDAPMessage of
        {ok, Request} ->
            Resp = handle_op(
                Request#'LDAPMessage'.messageID,
                Request#'LDAPMessage'.protocolOp,
                Request#'LDAPMessage'.controls
            ),
            % Put the result into an ldap message
            io:fwrite("~p ~n", [Resp]),
            Message = #'LDAPMessage'{   messageID = Request#'LDAPMessage'.messageID,
                                        protocolOp = Resp},
            % Better way to handle this?
            {ok, WrappedResult} = 'ELDAPv3':encode('LDAPMessage', Message),
            % This doesn't seem to actually send the data ...
            % Maybe there is a socket option I am missing
            {ok, WrappedResult};
            % gen_tcp:shutdown(S);
        _ ->
            io:fwrite("Unknown protocol, Closing socket ~n"),
            {error, "Invalid ASN"}
    end.


% The protocol Op contains the choice and the details in it.
% Check the MSGID
handle_op(MsgID, ProtocolOp, Controls) ->
    io:fwrite("~p ~p ~p ~n", [MsgID, ProtocolOp, Controls]),
    case ProtocolOp of
        {bindRequest, _} ->   {bindResponse, #'BindResponse' {
                    resultCode = unwillingToPerform,
                    matchedDN = <<""/utf8>>,
                    diagnosticMessage = <<"Operation not implemented"/utf8>>}};
        _ -> {unwillingToPerform, <<""/utf8>>, <<"Operation not implemented"/utf8>>}
    end.


