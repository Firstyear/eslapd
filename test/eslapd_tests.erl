
-module('eslapd_tests').
-author('firstyear@redhat.com').

-include_lib("eunit/include/eunit.hrl").
-include("ELDAPv3.hrl").

% This will hopefully become an implementation able to test rfc4511 compliance.

ldap_bind_proto_test() ->
    Response = eslapd_serv:handle_op(3, {bindRequest, []}, []),
    ?debugFmt("~p~n", [Response]),
    ?assert(true).

ldap_bind_test() ->
    {ok, Request} = 'ELDAPv3':encode('LDAPMessage',
        #'LDAPMessage'{
            messageID = 1,
            protocolOp = {bindRequest,
                #'BindRequest'{
                    version = 3,
                    name = <<""/utf8>>,
                    authentication = {simple, <<""/utf8>>}
                }
            }
        }
    ),
    Response = eslapd_serv:handle_ldapmsg(Request),
    ?debugFmt("~p~n", [Response]),
    ?assert(true).

