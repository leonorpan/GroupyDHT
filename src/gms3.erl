%% @author Nora
%% @doc @todo Add description to gms3.


-module(gms3).

%% ====================================================================
%% API functions
%% ====================================================================
-export([start/1, start/2]).

-define(timeout,5000).
-define(arghh,1000).

%%start first - leader node
start(Id) ->
	Rnd = random:uniform(1000),
	Self = self(),
	{ok, spawn_link(fun()-> init(Id,Rnd, Self) end)}.

init(Id,Rnd, Master) ->
	random:seed(Rnd, Rnd, Rnd),
	leader(Id, Master,1, [], [Master]).

%%start new slave node
start(Id, Grp) ->
	Rnd = random:uniform(1000),
	Self = self(),
	{ok, spawn_link(fun()-> init(Id, Grp,Rnd, Self) end)}.


init(Id, Grp, Rnd,Master) ->
	random:seed(Rnd, Rnd, Rnd),
	Self = self(),
	%%apply to join
	Grp ! {join, Master, Self},
	%%received invitation
	receive
		{view,N, [Leader|Slaves], Group} ->
			Master ! {view, Group},
			erlang:monitor(process, Leader),
			%%now i am a slave
			slave(Id, Master, Leader,N,none, Slaves, Group)
	after ?timeout ->
			Master ! {error,"no reply from leader!"}
	end.


slave(Id, Master, Leader,N,Last, Slaves, Group) ->
	%%receive messages from master, pass them to the leader
	%%receive messages from leader, pass them to the master
	receive
		%%request from master to multicast a message ,should forward to the leader
		{mcast, Msg} ->
			io:format("gms ~w: received {mcast, ~w} in state ~w~n", [Id, Msg, N]),
			Leader ! {mcast, Msg},
			slave(Id, Master, Leader,N,Last, Slaves, Group);
		%%request from master to allow a new node to the group, forward to leader
		{join, Wrk, Peer} ->
			io:format("gms ~w: forward join from ~w to leader~n", [Id, Peer]),
			Leader ! {join, Wrk, Peer},
			slave(Id, Master, Leader,N,Last, Slaves, Group);
		%%drop message when it is old
		{msg,I,_} when I<N ->
			io:format("Message dropped because ~w is smaller than ~w~n", [I,N]),
			slave(Id,Master,Leader,N,Last,Slaves,Group);
		%%multicasted message from the leadder, forward to master
		{msg,I, Msg} ->
			io:format("gms ~w: deliver msg ~w in state ~w~n", [Id, Msg, I]),
			Message={msg,I, Msg},
			Master ! Msg,
			slave(Id, Master, Leader,I,Message, Slaves, Group);
		{view,I, [Leader|Slaves2], Group2} when I<N-> 
			View ={view,I, [Leader|Slaves2], Group2},
			io:format("View dropped because ~w: is smaller than ~w View : ~w~n", [I, N,View]),
			slave(Id, Master, Leader,N,View, Slaves2, Group2);
		%%multicasted view from leader, forward to master process
		{view,I, [Leader|Slaves2], Group2}->
			Message1 ={view,I, [Leader|Slaves2], Group2},
			io:format("gms ~w: received view ~w ~w~n", [Id, N, Message1]),
			Master ! {view, Group2},
			slave(Id, Master, Leader,I,Message1, Slaves2, Group2);
		{'DOWN',_Ref,process,Leader,_Reason} ->
			io:format("received down message! ~w is down! ~n", [Leader]),
			election(Id,Master,N,Last,Slaves,Group);
		stop ->
			ok;
		Error ->
			io:format("gms ~w: slave, strange message received ~w~n", [Id, Error])
	end.

%%elect new leader
election(Id, Master,N,Last, Slaves, [_|Group]) ->
	Self = self(),
	case Slaves of
		[Self|Rest] ->
			bcast(Id, {view,N, Slaves, Group}, Rest),
			bcast(Id,Last,Rest),
			Master ! {view, Group},
			io:format("new leader elected!! and it is worker: ~w~n", [Id]),
			leader(Id, Master,N+1 ,Rest, Group);
		[Leader|Rest] ->
			erlang:monitor(process, Leader),
			slave(Id, Master,Leader,N+1,Last,  Rest, Group)
	end.


leader(Id, Master,N, Slaves, Group) ->
	Stamp = N+1,
	receive
		%% message from master or peer node, has to be multicasted to all peers and Msg to the master
		{mcast, Msg} ->
			io:format("gms ~w: received {mcast, ~w} in state ~w~n", [Id, Msg, Stamp]),
			bcast(Id, {msg,Stamp, Msg}, Slaves),
			Master ! Msg,
			leader(Id, Master,Stamp, Slaves, Group);
		%%message from a peer or master that requests to join the group
		%%Wrk = process identifier of the application layer
		%%Peer = process identifier of group process
		{join, Wrk, Peer} ->
			io:format("gms ~w: forward join from ~w to master~n", [Id, Peer]),
			Slaves2 = lists:append(Slaves, [Peer]),
			Group2 = lists:append(Group, [Wrk]),	
			bcast(Id, {view,Stamp, [self()|Slaves2], Group2}, Slaves2),
			Master ! {view, Group2},
			io:format("inside the leader loop: Wrk ~w & Peer ~w~n",[Wrk,Peer]),
			leader(Id, Master,Stamp, Slaves2, Group2);
		stop ->
			ok;
		Error ->
			io:format("gms ~w: leader, strange message ~w~n", [Id, Error])
	end.



bcast(Id, Msg, Nodes) ->
	lists:foreach(fun(Node) -> Node ! Msg end, Nodes).

crash(Id) ->
	case random:uniform(?arghh) of 
		?arghh ->	
			io:format("leader ~w: crashed~n", [Id]),
			exit(no_luck);
		_->
			ok
	end.

%% ====================================================================
%% Internal functions
%% ====================================================================








