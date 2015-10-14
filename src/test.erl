%% @author Nora
%% @doc @todo Add description to test.


-module(test).

%% ====================================================================
%% API functions
%% ====================================================================
-export([startest/0]).

startest() -> 
	GmsType = gms3,
	%%initialize first node and leader
	
Result = worker:start(1,GmsType,105,6000).
	%%Result1 = worker:start(2,GmsType,305,Result,6000),
	%%Result2 = worker:start(3,GmsType,205,Result,6000),
	%%Result3 = worker:start(4,GmsType,390,Result,6000),
	%%Result4 = worker:start(5,GmsType,90,Result,6000),
	%%Result5 = worker:start(6,GmsType,90,Result,6000),
	%%NodeList=[Result,Result1,Result2,Result3,Result4,Result5],
	%%io:format("Ap processes are:  ~w~n", [NodeList]),
	%%worker:start(7,GmsType,123,Result,6000).

%% ====================================================================
%% Internal functions
%% ====================================================================


