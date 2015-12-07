
-module('eslapd').
-author('firstyear@redhat.com').

-compile(export_all).
-behaviour(application).
-export([start/0, start/2, stop/1]).
-include_lib("kernel/include/inet.hrl").
-include_lib("eldap/include/eldap.hrl").

% You need this for ?MODULE
% -include_lib("kernel/include/file.hrl")
-define(CRNL, "\r\n").

start() ->
    % This probably doesn't need to block anymore.
    _Pid = spawn(?MODULE, loop0, [self()]),
    receive {_, Reply} -> Reply
    end.

% How do I make this work properly as an application with supervisors?
start(normal, _Args) ->
    _ = spawn(?MODULE, loop0, [self()]).

stop(_State) ->
    ok.

loop0(Parent) ->
    % Set a timeout?
    case gen_tcp:listen(12345, [binary, {packet, asn1}, {buffer, 40}, {active, false}]) of
        {ok, LSock} ->
            loop(LSock);
        _ ->
            Parent ! error
    end.

loop(Listen) ->
    case gen_tcp:accept(Listen) of
        {ok, S} ->
            spawn(fun() -> do_recv(S) end),
            loop(Listen);
        _ ->
            loop(Listen)
    end.

do_recv(S) ->
    case gen_tcp:recv(S, 0) of
        {ok, ClientData} ->
            % Does this need a try catch?
            Decoded = 'ELDAPv3':decode('LDAPMessage', ClientData),
            handle_ldapmsg(S, Decoded),
            do_recv(S);
        _ ->
            gen_tcp:close(S)
    end.

handle_ldapmsg(S, LDAPMessage) ->
    case LDAPMessage of
        {ok, {'LDAPMessage', MsgID, ProtocolOp, Controls}} ->
            {ok, Result} = handle_op(MsgID, ProtocolOp, Controls),
            io:fwrite("~p ~n", [Result]),
            % This doesn't seem to actually send the data ...
            % Maybe there is a socket option I am missing
            gen_tcp:send(S, Result),
            gen_tcp:close(S);
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

%gen_tcp:send(S, io_lib:format("~p~n", [{date(), time()}])),
