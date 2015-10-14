%% @author Nora
%% @doc @todo Add description to gms2a.


-module(gms2a).

%% ====================================================================
%% API functions
%% ====================================================================
-export([start/1, start/2]).
-define(timeout,5000).

%%start first - leader node
start(Id) ->
	Self = self(),
	{ok, spawn_link(fun()-> init(Id, Self) end)}.

init(Id, Master) ->
	leader(Id, Master, [], [Master]).

%%start new slave node
start(Id, Grp) ->
	Self = self(),
	{ok, spawn_link(fun()-> init(Id, Grp, Self) end)}.


init(Id, Grp, Master) ->
	Self = self(),
	%%apply to join
	Grp ! {join, Master, Self},
	%%received invitation
	receive
		{view, [Leader|Slaves], Group} ->
			Master ! {view, Group},
			erlang:monitor(process, Leader),
			%%now i am a slave
			slave(Id, Master, Leader, Slaves, Group)
	after ?timeout ->
			Master ! {error,"no reply from leader!"}
	end.


slave(Id, Master, Leader, Slaves, Group) ->
	%%receive messages from master, pass the to the leader
	%%receive messages from leader, pass them to the master
	receive
		%%request from master to multicast a message ,should forward to the leader
		{mcast, Msg} ->
			%%io:format("gms ~w: received {mcast, ~w} in state ~w~n", [Id, Msg, N]),
			Leader ! {mcast, Msg},
			slave(Id, Master, Leader, Slaves, Group);
		%%request from master to allow a new nodeto the group, forward to leader
		{join, Wrk, Peer} ->
			%%io:format("gms ~w: forward join from ~w to leader~n", [Id, Peer]),
			Leader ! {join, Wrk, Peer},
			slave(Id, Master, Leader, Slaves, Group);
		%%multicasted message from the leadder, forward to master
		{msg, Msg} ->
			%%io:format("gms ~w: deliver msg ~w in state ~w~n", [Id, Msg, N]),
			Master ! Msg,
			slave(Id, Master, Leader, Slaves, Group);
		%%multicasted view from leader, forward to master process
		{view, [Leader|Slaves2], Group2} ->
			%%io:format("gms ~w: received view ~w ~w~n", [Id, N, View]),
			Master ! {view, Group2},
			slave(Id, Master, Leader, Slaves2, Group2);
		{'DOWN',_Ref,process,Leader,_Reason} ->
			io:format("received down message! ~w is down! ~n", [Leader]),
			election(Id,Master,Slaves,Group);
		stop ->
			ok;
		Error ->
			io:format("gms ~w: slave, strange message received ~w~n", [Id, Error])
	end.

%%elect new leader
election(Id, Master, Slaves, [_|Group]) ->
	Self = self(),
	case Slaves of
		[Self|Rest] ->
			bcast(Id, {view, Slaves, Group}, Rest),
			Master ! {view, Group},
			io:format("new leader elected!! and it is worker: ~w~n", [Id]),
			leader(Id, Master, Rest, Group);
		[Leader|Rest] ->
			erlang:monitor(process, Leader),
			slave(Id, Master, Leader, Rest, Group)
	end.


leader(Id, Master, Slaves, Group) ->
	receive
		%% message from master or peer node, has to be multicasted to all peers and Msg to the master
		{mcast, Msg} ->
			%%io:format("gms ~w: received {mcast, ~w} in state ~w~n", [Id, Msg, N]),
			bcast(Id, {msg, Msg}, Slaves),
			Master ! Msg,
			leader(Id, Master, Slaves, Group);
		%%message from a peer or master that requests to join the group
		%%Wrk = process identifier of the application layer
		%%Peer = process identifier of group process
		{join, Wrk, Peer} ->
			%%io:format("gms ~w: forward join from ~w to master~n", [Id, Peer]),
			Slaves2 = lists:append(Slaves, [Peer]),
			Group2 = lists:append(Group, [Wrk]),
			bcast(Id, {view, [self()|Slaves2], Group2}, Slaves2),
			Master ! {view, Group2},
			leader(Id, Master, Slaves2, Group2);
		stop ->
			ok;
		Error ->
			io:format("gms ~w: leader, strange message ~w~n", [Id, Error])
	end.



bcast(_Id, Msg, Nodes) ->
	lists:foreach(fun(Node) -> Node ! Msg end, Nodes).


%% ====================================================================
%% Internal functions
%% ====================================================================





