# Prolog_Reg-Exp_NFA
Prolog compilatore da Espressione Regolare ad Automa Non Deterministico (Progetto Universitario)

README relativo a re-nfa.pl

Il presente documento contiene una spiegazione dettagliata del funzionamento del compilatore da espressione regolare ad automa non deterministico.
Gli automi sono realizzati secondo un'implementazione che permette di riconoscere se la lista in input fa parte dell'inisieme dei risultati validi accettati della espressione regolare (ossia se è parte del linguaggio rappresentato dalla regexp).


== Implementazione ==

Segue una lista delle varie implementazioni delle mosse 'delta' ed 'epsilon' realizzate.
L'utilizzo di più implementazioni delle mosse di base è risultato utile per un rilevamento immediato di possibili casi di loop e per una efficace gestione della negazione degli automi.

- delta
Dallo stato q1 allo stato q2 rimuovendo un simbolo (carattere) dalla lista in input.
E' accettato quando il simbolo in input unifica con il simbolo del delta.
E' la mossa delta standard.

- delta_bar
Dallo stato q1 allo stato q2 rimuovendo un simbolo (carattere) dalla lista in input.
E' accettato quando il simbolo in input non unifica con il simbolo del delta.
E' la negazione della mossa standard. Utilizzata nella negazione del singolo simbolo.

- epsilon
Dallo stato q1 allo stato q2 senza rimuovere alcun simbolo (carattere) dalla lista in input.
E' sempre accettato.
E' la mossa epsilon standard.

- epsilon_bar
Dallo stato q1 allo stato q2 senza rimuovere alcun simbolo (carattere) dalla lista in input.
E' sempre accettato ed indica l'ingresso in un sottoautoma di negazione (bar).
E' il collegamento d'ingresso ad un automa negato.

- epsilon_acc
Dallo stato q1 allo stato q2 senza rimuovere alcun simbolo (carattere) dalla lista in input.
E' sempre accettato ed indica che la il sottoautoma di negazione non è stato verificato.
E' il collegamento alternativo di un automa negato.

- epsilon_pass
Dallo stato q1 allo stato q2 senza rimuovere alcun simbolo (carattere) dalla lista in input.
E' sempre accettato ed unifica l'indice di stato precedente con quello di stato attuale.
E' una mossa epsilon particolare che comunica al programma di non eseguire una mossa di epsilon_back. 

- epsilon_back
Dallo stato q1 allo stato q2 senza rimuovere alcun simbolo (carattere) dalla lista in input.
E' accettato solo quando l'indice di stato precedente non unifica con quello di stato attuale.
E' una mossa epsilon particolare che evita di entrare in un loop.



== Predicati pubblici ==

Descrizione dei predicati pubblici e dei relativi predicati privati:

- is_regexp/1
Analizza se la variabile in input contiene una espressione regolare, scomponendo l'input ove possibile attraverso il "built-in-predicate" '=..'.
Il riconoscimento avviene differenziando gli operatori validi delle regexp in due categorie, quelli che accettano in input un solo argomento, e quelli che ne accettano più d'uno. I predicati privati is_operator/1 e is_operator_n/1 svolgono questa funzione di selezione ed il predicato privato is_regexp_list/1 si occupa poi del riconoscimento nel caso in cui l'operatore possa avere più argomenti.
Unica menzione particolare va per l'operatore 'oneof', il quale accetta come input solo simboli (e non anche regular expressions), per identificare questi argomenti utilizza il predicato privato is_symbol_list/1.

- nfa_compile_regexp/2
Compone l'automa inserendo nella base di dati Prolog i predicati relativi allo stato iniziale, a tutte le mosse possibili ed agli stati terminali.
La composizione dell'automa avviene creando per ogni operatore l'automa corrispondente e quando un operatore è argomento di un altro operatore, l'automa del primo sarà interno all'automa del secondo.
Segue la descrizione della realizzazione dell'automa di ogni operatore e della gestione dei casi particolari:

	- nfa_comp_re/6
	Si occupa di tre casi: 
	1) Crea l'automa del simbolo:
		Semplicemente crea un normale delta dallo stato attuale ad uno successivo appena generato.
	2) Crea l'automa della negazione del simbolo: 
		A) Inserendo la mossa 'delta_bar' su quel simbolo.
		B) Inserendo la mossa epsilon_pass per accettare l'insieme vuoto come risultato ed evitare loop se innestato in uno 'star'.
		C) Inserendo la mossa epsilon_back per poter tornare al termine del delta_bar (evitando loop).
		D) Inserendo un ciclo di due delta normali che accettano qualsiasi carattere '_' per leggere altri infiniti caratteri.
	3) Nel caso in cui l'argomento passatogli non sia atomico richiama il predicato corrispondente.

	- nfa_comp_re_bar/6
	Realizza l'implementazione della negazione degli automi portando lo stato successivo in uno stato senza uscite.
	Utilizza la variabile dello stato Ausiliario come nuovo stato teerminale del sottoautoma negato.
	Modifica la variabile di Stato da 'normal' a 'bar' per far operare tutti i sottopredicadi di nfa_regexp_compile/2 in negazione.
	Se bar viene implementato all'interno di un automa già negato, allora opererà inversamente, riportando i sottopredicati a 'normal'.

	- nfa_comp_re_seq/6
	Realizza l'automa del seq e del seq negato.
	1) Automa seq:
		A) Inserisce una mossa epsilon iniziale.
		B) Inserisce il delta della mossa del primo elemento della sequenza rilanciando nfa_comp_re/6.
		C) Se vi sono più elementi rilancia una seconda volta nfa_comp_re_seq/6 con i restanti elementi.
	2) Automa seq negato:
		A) Inserisce una epsilon_bar che porta all'ingresso di un sottoautoma negato.
		B) Richiama se stesso senza negazione creando un sottoautoma seq normale collegato allo stato terminale dell'epsilon_bar.
		C) Inserisce uno stato terminale per la negazione dell'automa.
		D) Inserisce una epsilon_acc che parte dallo stato iniziale di epsilon_bar ma sarà letta solo se l'automa negato fallisce.
		E) Inserisce un epsilon normale che collega il termine di epsilon_acc con l'uscita ausiliaria, utilizzata dalla op. bar.
		F) Inserisce delta che accetta qualsiasi carattere '_' per accettare qualsiasi cosa oltre all'automa negato (in loop).	

	- nfa_comp_re_star/6
	Realizza l'automa dello star o dello star negato.
	1) Automa star:
		A) Inserisce una mossa epsilon iniziale.
		B) Inserisce la mossa delta normale.
		C) Inserisce la mossa epsilon finale.
		D) Inserisce una epsilon_back per tornare indietro e rileggere nuovamente il delta normale.
		E) Inserisce una epsilon_pass per realizzare il caso in cui si legga la stringa vuota.
	2) Automa star negato:
		A) Inserisce una epsilon_bar che porta all'ingresso di un sottoautoma negato.
		B) Richiama se stesso senza negazione creando un sottoautoma star normale collegato allo stato terminale dell'epsilon_bar.
		C) Inserisce uno stato terminale per la negazione dell'automa.
		D) Inserisce una epsilon_acc che parte dallo stato iniziale di epsilon_bar ma sarà letta solo se l'automa negato fallisce.
		E) Inserisce un epsilon normale che collega il termine di epsilon_acc con l'uscita ausiliaria, utilizzata dalla op. bar.
		F) Inserisce delta che accetta qualsiasi carattere '_' per accettare qualsiasi cosa oltre all'automa negato (in loop).

	- nfa_comp_re_plus/6
	Essendo l'operazione plus nientemeno che la concatenazione dell'automa del suo operando con lo star dello stesso operando:
	1) Il plus sarà esattamente l'automa di una seq con due argomenti:
		A) Il primo è l'automa dell'argomento stesso.
		B) Il secondo è l'automa dello star dell'argomento stesso.
	2) Il plus negato è semplicemente la negazione della medesima seq di due argomenti.

	- nfa_comp_re_alt/6
	Realizza l'automa dell'alt o dell'alt negato.
	1) Automa alt:
		A) Inserisce una mossa epsilon iniziale.
		B) Inserisce il delta della mossa del primo elemento delle alternative rilanciando nfa_comp_re/6.
		C) Inserisce una mossa epsilon finale dallo stato conclusivo ad uno stato finale generato.
		D) Se vi sono più alternative lancia nfa_comp_re_alt_next/6 con i restanti elementi passando lo stato iniziale e finale.
	2) Automa alt negato:
		A) Inserisce una epsilon_bar che porta all'ingresso di un sottoautoma negato.
		B) Richiama se stesso senza negazione creando un sottoautoma alt normale collegato allo stato terminale dell'epsilon_bar.
		C) Inserisce uno stato terminale per la negazione dell'automa.
		D) Inserisce una epsilon_acc che parte dallo stato iniziale di epsilon_bar ma sarà letta solo se l'automa negato fallisce.
		E) Inserisce un epsilon normale che collega il termine di epsilon_acc con l'uscita ausiliaria, utilizzata dalla op. bar.
		F) Inserisce delta che accetta qualsiasi carattere '_' per accettare qualsiasi cosa oltre all'automa negato (in loop).	
			

- nfa_recognize/2
Controlla che l'input sia una lista ed esegue il predicato accept/2. Quest'ultimo ricerca, per l'identificatore dell'automa dato in input, lo stato iniziale (initial/2), eseguendo poi il predicato accept/5 che, al suo interno ricercherà una mossa (delta, epsilon o derivati), che parte dallo stato iniziale e che soddisfi il primo input nella lista input, rilanciando poi ricorsivamente accept/5 fino ad esaurire la lista in input e soddisfare il predicato final/2.
Il predicato accept/5 ha come quarto e quinto argomento due variabili (Ultima Posizione e Attuale Posizione) utilizzate per evitare i casi di loop che si verificherebbero negli automi con epsilon mosse cicliche.
Vengono inizializzate in accept/2 con i valori 0 ed 1, assegnando poi il valore di Attuale Posizione ad Ultima Posizione ed incrementando di 1 quest'ultima ogni volta che si effettua una mossa delta o delta_bar. Quando viene eseguita una mossa epsilon normale non vengono modificate, ma quando viene eseguita una mossa epsilon_pass Attuale Posizione unifica il suo valore con Ultima Posizione.
In caso di epsilon_back accept viene eseguito solo se le due variabili non unificano. Dopo la verifica di non unificazione anche la epsilon_back unifica le due variabili.
In caso di epsilon_bar invece viene prima eseguito il predicato not(accept/5) per l'implementazione del bar, se è true viene poi eseguita la epsilon_acc e continua la ricorsione rilanciando accept/5.
 

- nfa_clear/0
Ripulisce la base dati prolog da tutte le implementazioni di automi.

- nfa_clear/1
Ripulisce la base dati prolog dall'implementazione dell'automa il cui identificatore unifica con l'identificatore dato in input.

- nfa_list/0
Lista tutte le implementazioni di automi presenti nella base dati prolog.

- nfa_list/1
Lista l'implementazione dell'automa il cui identificatore unifica con l'identificatore dato in input.



== Gestione eccezioni ==

La gestione delle eccezione avviene attraverso i predicati catch/3 e throw/1.
Quando viene lanciato (throw) un errore esso viene poi inviato al predicato nfa_error/1, il quale seleziona il messaggio da passare ad nfa_exception/1, che attraverso il built-in-predicate print_message_lines/3 stabilisce il tipo di errore e manda in output il messaggio.
Si è scelto di utilizzare la tipologia di warning rispetto a quella di error perchè error è un tipo di risultato diverso da true e false, mentre in questo caso l'errore restituisce comunque un risultato false al goal inserito dall'utente. Quindi un semplice warning pare più appropriato.

== Note ==

In fase di stesura del codice, per individuare più velocemente le liste con un solo elemento si è scelta la notazione [Arg | []] rispetto alla più logica [Arg].
Atomic([]) è true per il prolog, quindi si considera [] accettata da is regexp_list. Ovviamente in caso di compilazione il simbolo []...