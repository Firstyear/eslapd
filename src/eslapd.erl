
-module('eslapd').
-author('firstyear@redhat.com').

-export([start_link/0, start_socket/0]).
-export([init/1]).
-behaviour(supervisor).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) -> 
    {ok, LSock} = gen_tcp:listen(12345, [
            binary,
            inet6,
            {packet, asn1},
            {buffer, 40},
            {active, once},
            {nodelay, true},
            {reuseaddr, true},
            {ipv6_v6only, true}
        ]),
    spawn_link(fun empty_listeners/0),
    {ok, {{ simple_one_for_one, 60, 3600},
         [{socket,
          {eslapd_serv, start_link, [LSock]},
          temporary, 1000, worker, [eslapd_serv]}
        ]}}.

start_socket() ->
    io:fwrite("Launching new acceptor ...~n"),
    supervisor:start_child(?MODULE, []).

empty_listeners() ->
    [start_socket() || _ <- lists:seq(1,20)],
    ok.
