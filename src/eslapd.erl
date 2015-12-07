
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
            MyPid = self(),
            Msg = 'ELDAPv3':decode('LDAPMessage', ClientData),
            io:fwrite("~p ~p~n", [MyPid, Msg]),
            gen_tcp:send(S, ClientData),
            do_recv(S);
        _ -> 
            gen_tcp:close(S)
    end.

%gen_tcp:send(S, io_lib:format("~p~n", [{date(), time()}])),
