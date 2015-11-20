%%%% -*- Mode: Prolog -*-

%%%% re-nfa.pl --
%%%% A balanced RegExp to NFA compiler.

%%%% Author: Federico Spinardi
%%%% Student ID: 781077
%%%% Date: 30/11/2014
%%%% See: README.txt

%%%% ---------------------------------------------------------------------------


%============================================%
% is_regexp
%============================================%

%%	is_regexp(Regular Expression).
% Predicato pubblico. True se RE e' un'espressione regolare.
% Ausiliario a nfa_compile_re/2.
is_regexp(RE) :-
	atomic(RE).
is_regexp(RE) :-
	nonvar(RE),
	RE =.. [Funct, Arg],
	is_operator(Funct),
	is_regexp(Arg).
is_regexp(RE) :-
	nonvar(RE),
	RE =.. [Funct | Arg],
	is_operator_n(Funct),
	is_regexp_list(Arg).
is_regexp(RE) :-
	nonvar(RE),
	RE =.. [oneof, Arg],
	atomic(Arg).
is_regexp(RE) :-
	nonvar(RE),
	RE =.. [oneof | Args],
	is_symbol_list(Args).

%%	is_regexp_list(Regular Expressions List).
% Predicato privato, true se la lista contiene RegExp.
% Ausiliario a is_regexp/1.
is_regexp_list([]).
is_regexp_list([Arg | As]) :-
	atomic(Arg),
	is_regexp_list(As).
is_regexp_list([RE | As]) :-
	nonvar(RE),
	RE =.. [Funct, Arg],
	is_operator(Funct),
	is_regexp(Arg),
	is_regexp_list(As).
is_regexp_list([RE | As]) :-
	nonvar(RE),
	RE =.. [Funct | Args],
	is_operator_n(Funct),
	is_regexp_list(Args),
	is_regexp_list(As).
is_regexp_list([RE | As]) :-
	nonvar(RE),
	RE =.. [oneof | Args],
	is_symbol_list(Args),
	is_regexp_list(As).

%%	is_symbol_list(Symbols List).
% Predicato privato, true se la lista contiene soli elementi atomici.
% Ausiliario a is_regexp_list/1.
is_symbol_list([]).
is_symbol_list([S | Ss]) :-
	atomic(S),
	is_symbol_list(Ss).

%%	is_operator(Operator).
% Predicato Privato, true se Operator è un operatore valido.
% Ausiliario a is_regexp/1 e is_regexp_list/1.
is_operator(star). % One Argument
is_operator(plus). % One Argument
is_operator(bar). % One Argument
is_operator_n(alt). % N Arguments
is_operator_n(seq). % N Arguments



%============================================%
% nfa_compile_regexp
%============================================%

%%	nfa_compile_regexp(Autom ID, Regular Expression).
% Predicato pubblico. True se FA_Id e' un identificatore valido e RE e'
% una regexp.
nfa_compile_regexp(FA_Id, RE) :-
	catch(nfa_compile_re(FA_Id, RE), Err, nfa_error(Err)).

%%	nfa_compile_re(ID, RegExp).
% Predicato Privato, true se FA_Id e' un identificatore valido e RE e'
% una regexp.
% Ausiliario a nfa_compile_regexp/2.
nfa_compile_re(FA_Id, _RE) :-
	not(atomic(FA_Id)),
	throw(error_FA_Id_atom).
nfa_compile_re(FA_Id, _RE) :-
	initial(FA_Id, _),
	throw(error_FA_Id_used).
nfa_compile_re(_FA_Id, RE) :-
	not(is_regexp(RE)),
	throw(error_RE).
nfa_compile_re(FA_Id, RE) :-
	nfa_start(FA_Id),
	nfa_comp_re(FA_Id, RE, q0, QFinal, _Aux, normal),
	reset_gensym(q),
	nfa_end(FA_Id, QFinal).

%%	nfa_comp_re(ID, RegExp, Ultimo, Successivo, Ausiliario, Stato).
% Predicato Privato, true se RE e' una regexp, Ultimo è uno stato 'qn'
% valido, Ausiliario (quando usato) è anch'esso uno stato valido,
% Stato è una delle due costanti di tipo di stato valide.
% Successivo è una variabile libera (il risultato del predicato).
% Ausiliario a nfa_compile_re/2 ed a tutti i sottopredicati per la
% ricorsione.
nfa_comp_re(FA_Id, RE, Qlast, Qnext, _Aux, normal) :-
	atomic(RE),
	gensym(q, Qnext),
	nfa_delta(FA_Id, RE, Qlast, Qnext, normal).
nfa_comp_re(FA_Id, RE, Qlast, Qnext, Aux, bar) :-
	atomic(RE),
	gensym(q, Qnext),
	nfa_delta(FA_Id, RE, Qlast, Aux, bar),
	nfa_delta(FA_Id, _, Qlast, Aux, epsilon_pass),
	nfa_delta(FA_Id, _, Aux, Qlast, epsilon_back),
	nfa_delta(FA_Id, _, Qnext, Aux, normal),
	nfa_delta(FA_Id, _, Aux, Qnext, normal).
nfa_comp_re(FA_Id, RE, Qlast, Qnext, Aux, State) :-
	RE =.. [seq | Arg],
	nfa_comp_re_seq(FA_Id, Arg, Qlast, Qnext, Aux, State).
nfa_comp_re(FA_Id, RE, Qlast, Qnext, Aux, State) :-
	RE =.. [star, Arg],
	nfa_comp_re_star(FA_Id, Arg, Qlast, Qnext, Aux, State).
nfa_comp_re(FA_Id, RE, Qlast, Qnext, Aux, State) :-
	RE =.. [plus, Arg],
	nfa_comp_re_plus(FA_Id, Arg, Qlast, Qnext, Aux, State).
nfa_comp_re(FA_Id, RE, Qlast, Qnext, Aux, State) :-
	RE =.. [bar, Arg],
	nfa_comp_re_bar(FA_Id, Arg, Qlast, Qnext, Aux, State).
nfa_comp_re(FA_Id, RE, Qlast, Qnext, Aux, State) :-
	RE =.. [alt | Arg],
	nfa_comp_re_alt(FA_Id, Arg, Qlast, Qnext, Aux, State).
nfa_comp_re(FA_Id, RE, Qlast, Qnext, Aux, State) :-
	RE =.. [oneof | Arg],
	nfa_comp_re_alt(FA_Id, Arg, Qlast, Qnext, Aux, State).


%%	nfa_comp_re_star(ID, Argomento, Ultimo, Succ., Ausil., Stato).
% Predicato Privato, true se Argomento è un operando valido
% (Espressione Regolare) per l'operatore 'star', Ultimo è uno stato 'qn'
% valido, Ausiliario (quando usato) è anch'esso uno stato valido, Stato
% è una delle due costanti di tipo di stato valide. Successivo è una
% variabile libera (il risultato del predicato).
% Ausiliario a nfa_comp_re/2 e nfa_comp_re_plus/6.
% Compone la chiusura di Kleene 'star' su una RegExp.
nfa_comp_re_star(FA_Id, Arg, Qlast, Qnext, Aux, normal) :-
	gensym(q, Qinitial),
	gensym(q, Qnext),
	nfa_delta(FA_Id, _, Qlast, Qinitial, epsilon),
	nfa_comp_re(FA_Id, Arg, Qinitial, Qfinal, Aux, normal),
	nfa_delta(FA_Id, _, Qfinal, Qnext, epsilon),
	nfa_delta(FA_Id, _, Qfinal, Qinitial, epsilon_back),
	nfa_delta(FA_Id, _, Qinitial, Qnext, epsilon_pass).
nfa_comp_re_star(FA_Id, Arg, Qlast, Qdead, Aux, bar) :-
	gensym(q, Qinitial),
	gensym(q, Qfinal),
	nfa_delta(FA_Id, _, Qlast, Qinitial, epsilon_bar),
	nfa_comp_re_star(FA_Id, Arg, Qinitial, Qdead, Aux, normal),
	nfa_end(FA_Id, Qdead),
	nfa_delta(FA_Id, _, Qlast, Qfinal, epsilon_acc),
	nfa_delta(FA_Id, _, Qfinal, Aux, epsilon),
	nfa_delta(FA_Id, _, Aux, Qfinal, normal).


%%	nfa_comp_re_plus(ID, Argomento, Ultimo, Succ., Ausil., Stato).
% Predicato Privato, true se Argomento è un operando valido
% (Espressione Regolare) per l'operatore 'plus', Ultimo è uno stato 'qn'
% valido, Ausiliario (quando usato) è anch'esso uno stato valido, Stato
% è una delle due costanti di tipo di stato valide. Successivo è una
% variabile libera (il risultato del predicato).
% Ausiliario a nfa_comp_re/2.
% Compone la chiusura di Kleene 'plus' su una RegExp.
nfa_comp_re_plus(FA_Id, Arg, Qlast, Qnext, Aux, normal) :-
	nfa_comp_re_seq(FA_Id, [Arg | [star(Arg)]], Qlast, Qnext, Aux, normal).
nfa_comp_re_plus(FA_Id, Arg, Qlast, Qnext, Aux, bar) :-
	nfa_comp_re_seq(FA_Id, [Arg | [star(Arg)]], Qlast, Qnext, Aux, bar).


%%	nfa_comp_re_seq(ID, Args. List, Ultimo, Succ., Ausil., Stato).
% Predicato Privato, true se la Arguments List contiene Espressioni
% Regolari valide, Ultimo è uno stato 'qn' valido,
% Ausiliario (quando usato) è anch'esso uno stato valido, Stato è una
% delle due costanti di tipo di stato valide. Successivo è una variabile
% libera (il risultato del predicato).
% Ausiliario a nfa_comp_re/2 e nfa_comp_re_plus/6.
% Compone il ramo dell'automa dell'operatore 'seq'.
nfa_comp_re_seq(FA_Id, [Arg | []], Qlast, Qnext, Aux, normal) :-
	gensym(q, Qnew),
	nfa_delta(FA_Id, _, Qlast, Qnew, epsilon),
	nfa_comp_re(FA_Id, Arg, Qnew, Qnext, Aux, normal).
nfa_comp_re_seq(FA_Id, [Arg | As], Qlast, Qnext, Aux, normal) :-
	gensym(q, Qnew),
	nfa_delta(FA_Id, _, Qlast, Qnew, epsilon),
	nfa_comp_re(FA_Id, Arg, Qnew, Qmid, Aux, normal),
	nfa_comp_re_seq(FA_Id, As, Qmid, Qnext, Aux, normal).
nfa_comp_re_seq(FA_Id, Arg, Qlast, Qdead, Aux, bar) :-
	gensym(q, Qinitial),
	gensym(q, Qfinal),
	nfa_delta(FA_Id, _, Qlast, Qinitial, epsilon_bar),
	nfa_comp_re_seq(FA_Id, Arg, Qinitial, Qdead, Aux, normal),
	nfa_end(FA_Id, Qdead),
	nfa_delta(FA_Id, _, Qlast, Qfinal, epsilon_acc),
	nfa_delta(FA_Id, _, Qfinal, Aux, epsilon),
	nfa_delta(FA_Id, _, Aux, Qfinal, normal).


%%	nfa_comp_re_bar(ID, Argomento, Ultimo, Succ., Ausil., Stato).
% Predicato Privato, true se Argomento è un operando valido
% (Espressione Regolare) per l'operatore 'bar', Ultimo è uno stato
% 'qn' valido, Ausiliario (quando usato) è anch'esso uno stato valido,
% Stato è una delle due costanti di tipo di stato valide. Successivo è
% una variabile libera (il risultato del predicato).
% Ausiliario a nfa_comp_re/2.
% Crea o rimuove lo stato di negazione dall'automa.
nfa_comp_re_bar(FA_Id, Arg, Qlast, Qnext, _Aux, normal) :-
	gensym(q, Qnext),
	nfa_comp_re(FA_Id, Arg, Qlast, _Qdead, Qnext, bar).
nfa_comp_re_bar(FA_Id, Arg, Qlast, Qnext, Aux, bar) :-
	nfa_comp_re(FA_Id, Arg, Qlast, Qnext, Aux, normal),
	nfa_delta(FA_Id, _RE, Qnext, Aux, epsilon).


%%	nfa_comp_re_alt(ID, Argomento, Ultimo, Succ., Ausil., Stato).
% Predicato Privato, true se la Arguments List contiene Espressioni
% Regolari valide, Ultimo è uno stato 'qn' valido,
% Ausiliario (quando usato) è anch'esso uno stato valido, Stato è una
% delle due costanti di tipo di stato valide. Successivo è una variabile
% libera (il risultato del predicato).
% Ausiliario a nfa_comp_re/2.
% Crea i rami dell'automa dell'operatore 'alt'.
nfa_comp_re_alt(FA_Id, [Arg | []], Qlast, Qnext, Aux, normal) :-
	gensym(q, Qinitial),
	nfa_delta(FA_Id, _, Qlast, Qinitial, epsilon),
	nfa_comp_re(FA_Id, Arg, Qinitial, Qfinal, Aux, normal),
	gensym(q, Qnext),
	nfa_delta(FA_Id, _, Qfinal, Qnext, epsilon).
nfa_comp_re_alt(FA_Id, Arg, Qlast, Qdead, Aux, bar) :-
	gensym(q, Qinitial),
	gensym(q, Qfinal),
	nfa_delta(FA_Id, _, Qlast, Qinitial, epsilon_bar),
	nfa_comp_re_alt(FA_Id, Arg, Qinitial, Qdead, Aux, normal),
	nfa_end(FA_Id, Qdead),
	nfa_delta(FA_Id, _, Qlast, Qfinal, epsilon_acc),
	nfa_delta(FA_Id, _, Qfinal, Aux, epsilon),
	nfa_delta(FA_Id, _, Aux, Qfinal, normal).
nfa_comp_re_alt(FA_Id, [Arg | As], Qlast, Qnext, Aux, normal) :-
	gensym(q, Qinitial),
	nfa_delta(FA_Id, _, Qlast, Qinitial, epsilon),
	nfa_comp_re(FA_Id, Arg, Qinitial, Qfinal, Aux, normal),
	gensym(q, Qnext),
	nfa_delta(FA_Id, _, Qfinal, Qnext, epsilon),
	nfa_comp_re_alt_next(FA_Id, As, Qlast, Qnext, Aux, normal).

%%	nfa_comp_re_alt_n(ID, Args. List, Ultimo, Succ., Ausil., Stato).
% Predicato Privato, true se la Arguments List contiene Espressioni
% Regolari, Ultimo è uno stato 'qn' valido, Ausiliario (quando usato) è
% anch'esso uno stato valido, Stato è una delle due costanti di tipo di
% stato valide. Successivo è una variabile libera (il risultato del
% predicato).
% Ausiliario a nfa_comp_re_alt/6.
% Compone i rami dell'automa dal secondo all'ultimo di 'alt'.
nfa_comp_re_alt_next(FA_Id, [Arg | []], Qlast, Qnext, Aux, normal) :-
	gensym(q, Qinitial),
	nfa_delta(FA_Id, _, Qlast, Qinitial, epsilon),
	nfa_comp_re(FA_Id, Arg, Qinitial, Qfinal, Aux, normal),
	nfa_delta(FA_Id, _, Qfinal, Qnext, epsilon).
nfa_comp_re_alt_next(FA_Id, [Arg | As], Qlast, Qnext, Aux, normal) :-
	gensym(q, Qinitial),
	nfa_delta(FA_Id, _, Qlast, Qinitial, epsilon),
	nfa_comp_re(FA_Id, Arg, Qinitial, Qfinal, Aux, normal),
	nfa_delta(FA_Id, _, Qfinal, Qnext, epsilon),
	nfa_comp_re_alt_next(FA_Id, As, Qlast, Qnext, Aux, normal).


%%	nfa_start(Autom ID).
% Predicato privato, crea lo stato iniziale dell'automa.
% Ausiliario a nfa_compile_re/2
nfa_start(FA_Id):-
	assertz(initial(FA_Id, q0)).

%%	nfa_end(Autom ID, Stato Finale).
% Predicato privato, crea uno stato finale dell'automa.
% Ausiliario a nfa_compile_re/2, ed a tutti i sottopredicati che
% necessitano di uno stato finale di non accettazione (in un ramo di
% negazione dell'automa).
nfa_end(FA_Id, QFinal) :-
	assertz(final(FA_Id, QFinal)).

%%	nfa_delta(ID, RegExp, Iniziale, Finale, Tipo).
% Predicato privato, crea una mossa dallo stato Iniziale allo stato
% Finale. Tipo definisce il tipo di mossa che verrà inserita nella base
% di dati Prolog.
% Ausiliario a tutti i predicati che in fase di compilazione dell'automa
% creano delle mosse.
nfa_delta(FA_Id, RE, QA, QZ, normal) :-
	assertz(delta(FA_Id, QA, RE, QZ)).
nfa_delta(FA_Id, RE, QA, QZ, bar) :-
	assertz(delta_bar(FA_Id, QA, X, QZ, RE) :- X \== RE).
nfa_delta(FA_Id, _RE, QA, QZ, epsilon) :-
	assertz(epsilon(FA_Id, QA, QZ)).
nfa_delta(FA_Id, _RE, QA, QZ, epsilon_acc) :-
	assertz(epsilon_acc(FA_Id, QA, QZ)).
nfa_delta(FA_Id, _RE, QA, QZ, epsilon_bar) :-
	assertz(epsilon_bar(FA_Id, QA, QZ)).
nfa_delta(FA_Id, _RE, QA, QZ, epsilon_pass) :-
	assertz(epsilon_pass(FA_Id, QA, QZ)).
nfa_delta(FA_Id, _RE, QA, QZ, epsilon_back) :-
	assertz(epsilon_back(FA_Id, QA, QZ)).



%============================================%
% nfa_recognize
%============================================%

% Rende dinamici i predicati creati dagli asserts.
:- dynamic
	initial/2,
	final/2,
	delta/4,
	delta_bar/5,
	epsilon/3,
	epsilon_acc/3,
	epsilon_bar/3,
	epsilon_pass/3,
	epsilon_back/3.

%%	nfa_recognize(Autom ID, Inputs List).
% Predicato pubblico, true se Inputs List è una lista di simboli validi
% per l'automa identificato da FA_Id, ed al termine della computazione
% l'automa si trova in uno stato di accettazione.
nfa_recognize(FA_Id, Input) :-
	catch(nfa_recog(FA_Id, Input), Err, nfa_error(Err)).

%%	nfa_recog(Autom ID, Inputs List).
% Predicato privato, true se Inputs List è una lista di simboli validi
% per l'automa identificato da FA_Id, ed al termine della computazione
% l'automa si trova in uno stato di accettazione.
% Ausiliario a nfa_recognize/2.
nfa_recog(FA_Id, Input) :-
	is_list(Input),
	accept(FA_Id, Input).
nfa_recog(_FA_Id, Input) :-
	not(is_list(Input)),
	throw(error_Input_list).

%%	accept(Autom ID, Inputs List).
% Predicato privato, true se esiste uno stato iniziale per l'automa
% identificato da FA_Id, ed al termine della computazione l'automa si
% trova in uno stato di accettazione.
% Ausiliario a nfa_recog/2.
accept(FA_Id, _Xs) :-
	not(initial(FA_Id, _Q)),
	throw(error_FA_Id_unknown).
accept(FA_Id, Xs) :-
	initial(FA_Id, Q),
	accept(FA_Id, Xs, Q, 0, 1).

%%	accept(ID, Inputs, Stato Attuale, Ultima Pos., Attuale Pos.).
% Predicato privato. True se, partendo dallo Stato Attuale, l'automa
% identificato da FA_Id al termine della computazione si trova in uno
% stato di accettazione.
% Gli argomeni Ultima Posizione e Attuale Posizione, sono degli
% indicatori del numero di mosse effettuate rispetto alla lista in
% input. Servono ad evitare casi di loop nelle chiusure di Kleene
% innestate.
% Ausiliario ad accept/2.
accept(FA_Id, [], Q, _, _) :-
	final(FA_Id, Q).
accept(FA_Id, [X | Xs], Q, _OldPos, Pos) :-
	atomic(X),
	delta(FA_Id, Q, X, NewQ),
	NewPos is Pos + 1,
	accept(FA_Id, Xs, NewQ, Pos, NewPos).
accept(FA_Id, [X | Xs], Q, _OldPos, Pos) :-
	atomic(X),
	delta_bar(FA_Id, Q, X, NewQ, _RE),
	NewPos is Pos + 1,
	accept(FA_Id, Xs, NewQ, Pos, NewPos).
accept(_FA_Id, [X | _Xs], _Q, _, _) :-
	not(atomic(X)),
	throw(error_Input_value).
accept(FA_Id, ERs, Q, OldPos, Pos) :-
	epsilon(FA_Id, Q, NextQ),
	accept(FA_Id, ERs, NextQ, OldPos, Pos).
accept(FA_Id, ERs, Q, OldPos, Pos) :-
	epsilon_bar(FA_Id, Q, NextQ),
	not(accept(FA_Id, ERs, NextQ, OldPos, Pos)),
	epsilon_acc(FA_Id, Q, NewQ),
	accept(FA_Id, ERs, NewQ, OldPos, Pos).
accept(FA_Id, ERs, Q, _OldPos, Pos) :-
	epsilon_pass(FA_Id, Q, NextQ),
	accept(FA_Id, ERs, NextQ, Pos, Pos).
accept(FA_Id, ERs, Q, OldPos, Pos) :-
	epsilon_back(FA_Id, Q, NextQ),
	OldPos \== Pos,
	accept(FA_Id, ERs, NextQ, Pos, Pos).



%============================================%
% nfa_clear / nfa_list
%============================================%

%%	nfa_clear.
% Predicato pubblico. Ripulisce il database prolog da ogni
% implementazione di automa.
nfa_clear :-
	retractall(initial(_, _)),
	retractall(final(_, _)),
	retractall(delta(_, _, _, _)),
	retractall(delta_bar(_, _, _, _, _)),
	retractall(epsilon(_, _, _)),
	retractall(epsilon_acc(_, _, _)),
	retractall(epsilon_bar(_, _, _)),
	retractall(epsilon_pass(_, _, _)),
	retractall(epsilon_back(_, _, _)).

%%	nfa_clear(Autom ID).
% Predicato pubblico. Ripulisce il database dall'implementazione
% dell'automa riconosciuto dall'identificatore Autom ID.
nfa_clear_nfa(FA_Id) :-
	retractall(initial(FA_Id, _)),
	retractall(final(FA_Id, _)),
	retractall(delta(FA_Id, _, _, _)),
	retractall(delta_bar(FA_Id, _, _, _, _)),
	retractall(epsilon(FA_Id, _, _)),
	retractall(epsilon_acc(FA_Id, _, _)),
	retractall(epsilon_bar(FA_Id, _, _)),
	retractall(epsilon_pass(FA_Id, _, _)),
	retractall(epsilon_back(FA_Id, _, _)).


%%	nfa_list.
% Predicato pubblico. Lista tutte le iplementazioni di automi presenti
% nel database Prolog.
nfa_list :-
	listing(initial),
	listing(final),
	listing(delta),
	listing(delta_bar),
	listing(epsilon),
	listing(epsilon_acc),
	listing(epsilon_bar),
	listing(epsilon_pass),
	listing(epsilon_back).

%%	nfa_list(Atuom ID).
% Predicato pubblico. Lista l'implementazione dell'automa identificato
% da Autom ID presente nella base di dati Prolog.
nfa_list(FA_Id) :-
	listing(initial(FA_Id, _)),
	listing(final(FA_Id, _)),
	listing(delta(FA_Id, _, _, _)),
	listing(delta_bar(FA_Id, _, _, _, _)),
	listing(epsilon(FA_Id, _, _)),
	listing(epsilon_bar(FA_Id, _, _)),
	listing(epsilon_acc(FA_Id, _, _)),
	listing(epsilon_pass(FA_Id, _, _)),
	listing(epsilon_back(FA_Id, _, _)).


%============================================%
% Exception Handler
%============================================%

%%	nfa_error(Nome Errore).
% Predicato privato. Seleziona il messaggio di warning da
% mandare in output in base al Nome Errore ricevuto.
% Ausiliario al built-in-predicate catch/3.
nfa_error(error_FA_Id_atom) :-
	nfa_exception('Identificatore non ammissibile.'),
	fail.
nfa_error(error_FA_Id_used) :-
	nfa_exception('Identificatore in uso.'),
	fail.
nfa_error(error_FA_Id_unknown) :-
	nfa_exception('Automa non presente nella base di dati.'),
	fail.
nfa_error(error_RE) :-
	nfa_exception('Espressione regolare errata.'),
	fail.
nfa_error(error_Input_list) :-
	nfa_exception('Input non valido, deve essere una lista.'),
	fail.
nfa_error(error_Input_value) :-
	nfa_exception('Input non valido, valore non ammissibile.'),
	fail.

%%	nfa_exception(Messaggio Errore).
% Predicato privato. Riceve un Messaggio Errore e lo manda in
% output come NFA-Warning.
% Ausiliario a nfa_error/1.
nfa_exception(Err) :-
	print_message_lines(
	    current_output,
	    '',
	    [begin(warning, _), prefix('~NNFA-Warning: '), '~w'-[Err]]
	).


%%%% end of file -- re-nfa.pl --























