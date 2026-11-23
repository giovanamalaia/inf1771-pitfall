% inferencia.pl
% Guarda o que o agente já viu e descobre quais casas são seguras ou perigosas.

% --- Task 1.1: fatos que mudam durante o jogo ---
:- dynamic posicao_atual/2.
:- dynamic visitada/2.
:- dynamic segura/2.
:- dynamic possivel_poco/2.
:- dynamic poco_confirmado/2.
:- dynamic possivel_monstro/2.
:- dynamic possivel_teletransporte/2.
:- dynamic monstro_confirmado/2.
:- dynamic teletransporte_confirmado/2.
:- dynamic ouro_pego/2.
:- dynamic parede/2.
:- dynamic sentiu/3.   % sentiu(X,Y,Tipo): o que a casa visitada sentiu

% --- Funções de apoio ---

% assertz só se o fato ainda não existe
afirma(Fato) :- ( call(Fato) -> true ; assertz(Fato) ).

% valores que o Python pode mandar pra dizer "sentiu"
percebido(true).
percebido(sim).
percebido(1).

% vizinhas (cima, baixo, esquerda, direita) que estão no mapa e não são parede
adjacente_valida(X, Y, AX, Y) :- AX is X + 1, dentro_do_mapa(AX, Y), \+ parede(AX, Y).
adjacente_valida(X, Y, AX, Y) :- AX is X - 1, dentro_do_mapa(AX, Y), \+ parede(AX, Y).
adjacente_valida(X, Y, X, AY) :- AY is Y + 1, dentro_do_mapa(X, AY), \+ parede(X, AY).
adjacente_valida(X, Y, X, AY) :- AY is Y - 1, dentro_do_mapa(X, AY), \+ parede(X, AY).

dentro_do_mapa(X, Y) :- map_size(MX, MY), X >= 1, X =< MX, Y >= 1, Y =< MY.

adjacentes_validas(X, Y, Lista) :- findall((AX,AY), adjacente_valida(X, Y, AX, AY), Lista).

% anota uma parede e tira qualquer outra informação dessa casa
registra_parede(X, Y) :-
    afirma(parede(X, Y)),
    retractall(segura(X, Y)),
    retractall(possivel_poco(X, Y)),
    retractall(possivel_monstro(X, Y)).

% casa sobre a qual ainda não sabemos nada
desconhecida(X, Y) :-
    \+ visitada(X, Y),
    \+ segura(X, Y),
    \+ parede(X, Y),
    \+ poco_confirmado(X, Y),
    \+ monstro_confirmado(X, Y),
    \+ teletransporte_confirmado(X, Y).

% --- Task 1.2: atualizar o estado com o que o agente sentiu ---

% Usa a posicao_atual/2, então chame atualiza_posicao/2 antes.
atualiza_estado(Brisa, Passos, Palmas, Ouro, Cura) :-
    posicao_atual(X, Y),
    marca_visitada(X, Y, Brisa, Passos, Palmas, Ouro, Cura),
    adjacentes_validas(X, Y, Adj),
    ( \+ percebido(Brisa), \+ percebido(Passos)
    ->  forall(member((AX,AY), Adj), marca_segura(AX, AY))
    ;   marca_riscos(Adj, Brisa, Passos)
    ),
    marca_teletransportes(Adj, Palmas),
    desambigua,
    infere_pocos,
    infere_monstros,
    infere_teletransportes,
    propaga_seguranca.

% define onde o agente está
atualiza_posicao(X, Y) :-
    retractall(posicao_atual(_, _)),
    assertz(posicao_atual(X, Y)).

marca_visitada(X, Y, Brisa, Passos, Palmas, Ouro, Cura) :-
    afirma(visitada(X, Y)),
    retractall(possivel_teletransporte(X, Y)),
    retractall(sentiu(X, Y, _)),
    ( percebido(Brisa)  -> assertz(sentiu(X, Y, brisa))   ; true ),
    ( percebido(Passos) -> assertz(sentiu(X, Y, passos))  ; true ),
    ( percebido(Palmas) -> assertz(sentiu(X, Y, palmas))  ; true ),
    ( percebido(Ouro)   -> assertz(sentiu(X, Y, brilho))  ; true ),
    ( percebido(Cura)   -> assertz(sentiu(X, Y, reflexo)) ; true ),
    ( \+ monstro_confirmado(X, Y), \+ teletransporte_confirmado(X, Y)
    ->  marca_segura(X, Y)
    ;   true
    ).

% casa segura: apaga qualquer suspeita que tinha sobre ela (se não houver perigo confirmado)
marca_segura(X, Y) :-
    \+ parede(X, Y),
    \+ poco_confirmado(X, Y),
    \+ monstro_confirmado(X, Y),
    \+ teletransporte_confirmado(X, Y),
    retractall(possivel_poco(X, Y)),
    retractall(possivel_monstro(X, Y)),
    afirma(segura(X, Y)), !.
marca_segura(_, _).

% --- Task 1.3: marcar as casas suspeitas ---

marca_riscos(Adj, Brisa, Passos) :-
    forall(member((AX,AY), Adj),
           (   desconhecida(AX, AY)
           ->  ( percebido(Brisa)  -> afirma(possivel_poco(AX, AY))    ; true ),
               ( percebido(Passos) -> afirma(possivel_monstro(AX, AY)) ; true )
           ;   true )).

% --- Task 1.4: limpar as suspeitas que não se confirmam ---

% se uma vizinha visitada não sentiu brisa, aqui não tem poço
sem_poco(X, Y) :-
    adjacente_valida(X, Y, VX, VY),
    visitada(VX, VY),
    \+ sentiu(VX, VY, brisa).

% se uma vizinha visitada não ouviu passos, aqui não tem monstro
sem_monstro(X, Y) :-
    adjacente_valida(X, Y, VX, VY),
    visitada(VX, VY),
    \+ sentiu(VX, VY, passos).

% vizinha visitada sem palmas: aqui não tem teletransportador
sem_teletransporte(X, Y) :-
    adjacente_valida(X, Y, VX, VY),
    visitada(VX, VY),
    \+ sentiu(VX, VY, palmas).

% palmas: uma vizinha não visitada pode ser teletransportador
marca_teletransportes(Adj, Palmas) :-
    (   percebido(Palmas)
    ->  forall(( member((AX,AY), Adj), \+ visitada(AX, AY), \+ teletransporte_confirmado(AX, AY) ),
               afirma(possivel_teletransporte(AX, AY)))
    ;   true ).

% roda depois de cada atualiza_estado, revisando todas as casas suspeitas
desambigua :-
    findall((X,Y), ( possivel_poco(X, Y) ; possivel_monstro(X, Y) ), Suspeitas),
    forall(member((X,Y), Suspeitas), desambigua_casa(X, Y)),
    findall((X,Y), possivel_teletransporte(X, Y), Teletransportes),
    forall(member((X,Y), Teletransportes),
           ( sem_teletransporte(X, Y) -> retractall(possivel_teletransporte(X, Y)) ; true )).

desambigua_casa(X, Y) :-
    ( possivel_poco(X, Y),    sem_poco(X, Y)    -> retractall(possivel_poco(X, Y))    ; true ),
    ( possivel_monstro(X, Y), sem_monstro(X, Y) -> retractall(possivel_monstro(X, Y)) ; true ),
    (   \+ possivel_poco(X, Y),
        \+ possivel_monstro(X, Y),
        \+ monstro_confirmado(X, Y),
        \+ teletransporte_confirmado(X, Y)
    ->  afirma(segura(X, Y))
    ;   true ).

% --- Task 1.4: confirmar poço ---
% brisa e só uma vizinha pode ter poço -> o poço é ela
pode_ter_poco(X, Y) :-
    \+ visitada(X, Y),
    \+ segura(X, Y),
    \+ parede(X, Y),
    \+ monstro_confirmado(X, Y),
    \+ teletransporte_confirmado(X, Y),
    \+ sem_poco(X, Y).

infere_pocos :-
    forall(( visitada(X, Y),
             sentiu(X, Y, brisa),
             findall((AX,AY), ( adjacente_valida(X, Y, AX, AY), pode_ter_poco(AX, AY) ), [(PX,PY)]) ),
           confirma_poco(PX, PY)).

% se é poço, não é monstro nem teletransporte
confirma_poco(X, Y) :-
    afirma(poco_confirmado(X, Y)),
    afirma(possivel_poco(X, Y)),
    retractall(possivel_monstro(X, Y)),
    retractall(possivel_teletransporte(X, Y)).

% --- mesma coisa pra monstro (passos) e teletransporte (palmas) ---
% o que já foi confirmado continua contando, pra não confirmar outra casa errado

pode_ter_monstro(X, Y) :- monstro_confirmado(X, Y), !.
pode_ter_monstro(X, Y) :-
    \+ visitada(X, Y),          % passou ali sem dano
    \+ segura(X, Y),
    \+ parede(X, Y),
    \+ poco_confirmado(X, Y),
    \+ teletransporte_confirmado(X, Y),
    \+ sem_monstro(X, Y).

infere_monstros :-
    forall(( visitada(X, Y),
             sentiu(X, Y, passos),
             findall((AX,AY), ( adjacente_valida(X, Y, AX, AY), pode_ter_monstro(AX, AY) ), [(MX,MY)]) ),
           confirma_monstro(MX, MY)).

confirma_monstro(X, Y) :-
    afirma(monstro_confirmado(X, Y)),
    retractall(segura(X, Y)),
    retractall(possivel_poco(X, Y)),
    retractall(possivel_teletransporte(X, Y)).

% aqui não usa segura/2, porque segura não descarta teletransporte
pode_ter_teletransporte(X, Y) :- teletransporte_confirmado(X, Y), !.
pode_ter_teletransporte(X, Y) :-
    \+ visitada(X, Y),          % não dá pra ficar parado num T
    \+ parede(X, Y),
    \+ poco_confirmado(X, Y),
    \+ monstro_confirmado(X, Y),
    \+ sem_teletransporte(X, Y).

infere_teletransportes :-
    forall(( visitada(X, Y),
             sentiu(X, Y, palmas),
             findall((AX,AY), ( adjacente_valida(X, Y, AX, AY), pode_ter_teletransporte(AX, AY) ), [(TX,TY)]) ),
           confirma_teletransporte(TX, TY)).

confirma_teletransporte(X, Y) :-
    afirma(teletransporte_confirmado(X, Y)),
    retractall(segura(X, Y)),
    retractall(possivel_poco(X, Y)),
    retractall(possivel_monstro(X, Y)),
    retractall(possivel_teletransporte(X, Y)).

% Propaga segurança adicional para fechar lacunas no conhecimento do A*
propaga_seguranca :-
    findall((X, Y), (visitada(X, Y), \+ sentiu(X, Y, brisa), \+ sentiu(X, Y, passos)), VisitadasLivres),
    forall(member((X, Y), VisitadasLivres),
           (
               adjacentes_validas(X, Y, Adj),
               forall(member((AX, AY), Adj),
                      (
                          desconhecida(AX, AY) -> marca_segura(AX, AY)
                      ;   true
                      )
               )
           )).

% --- Task 1.5: teletransporte ---

% só muda a posição; o mapa que o agente já construiu continua igual
teletransporta(NX, NY) :-
    retractall(posicao_atual(_, _)),
    assertz(posicao_atual(NX, NY)).

% quando cai em um teletransportador em (TX, TY) e acorda em (NX, NY)
% a casa T não conta como visitada (não sentiu nada lá, senão as vizinhas viravam seguras)
registra_teletransporte(TX, TY, NX, NY) :-
    retractall(visitada(TX, TY)),
    retractall(sentiu(TX, TY, _)),
    afirma(teletransporte_confirmado(TX, TY)),
    retractall(segura(TX, TY)),
    retractall(possivel_teletransporte(TX, TY)),
    teletransporta(NX, NY).

% quando entra em (X, Y) e sofre dano de inimigo
registra_monstro(X, Y) :-
    afirma(monstro_confirmado(X, Y)),
    retractall(segura(X, Y)),
    retractall(possivel_monstro(X, Y)).

% --- Risco ---

% depois dos 3 ouros não precisa mais explorar
ouro_restante(R) :-
    aggregate_all(count, ouro_pego(_, _), N),
    R is 3 - N.

% quem sentiu o perigo divide a culpa entre as K casas suspeitas ao redor: chance 1/K
chance(X, Y, Sentido, Suspeita, P) :-
    adjacente_valida(X, Y, VX, VY),
    visitada(VX, VY),
    sentiu(VX, VY, Sentido),
    aggregate_all(count, ( adjacente_valida(VX, VY, AX, AY), call(Suspeita, AX, AY) ), K),
    K > 0,
    P is 1 / K.

risco(Suspeita, Sentido, X, Y, R) :-
    call(Suspeita, X, Y), !,
    findall(P, chance(X, Y, Sentido, Suspeita, P), Ps),
    max_list([0|Ps], R).
risco(_, _, _, _, 0).

% monstro dá dano a cada ação na casa, então pesa mais com pouca energia
peso_monstro(500) :- energia(E), E > 80, !.
peso_monstro(700) :- energia(E), E > 50, !.
peso_monstro(900).

custo_casa(X, Y, Custo) :-
    risco(possivel_poco, brisa, X, Y, RPoco),
    risco(possivel_monstro, passos, X, Y, RMonstro),
    risco(possivel_teletransporte, palmas, X, Y, RTele),
    peso_monstro(WMonstro),
    Custo is RPoco * 1000 + RMonstro * WMonstro + RTele * 50.

segura_inexplorada(X, Y) :-
    segura(X, Y),
    \+ visitada(X, Y),
    \+ parede(X, Y),
    \+ possivel_poco(X, Y),
    \+ possivel_monstro(X, Y),
    \+ teletransporte_confirmado(X, Y),
    \+ monstro_confirmado(X, Y).

fronteira(X, Y) :-
    ( possivel_poco(X, Y) ; possivel_monstro(X, Y) ),
    \+ visitada(X, Y),
    \+ parede(X, Y),
    \+ poco_confirmado(X, Y),
    \+ teletransporte_confirmado(X, Y),
    \+ monstro_confirmado(X, Y).

% ordena por risco e, no empate, pela distância
ordenadas(Fonte, Casas) :-
    posicao_atual(PX, PY),
    findall(Custo-Dist-X-Y,
            ( call(Fonte, X, Y),
              custo_casa(X, Y, Custo),
              Dist is abs(X - PX) + abs(Y - PY) ),
            Lista),
    msort(Lista, Casas).

% primeiro as casas seguras, depois o chute de menor risco
destino_exploracao(X, Y, seguro) :-
    ouro_restante(R), R > 0,
    ordenadas(segura_inexplorada, Casas),
    member(_-_-X-Y, Casas).
destino_exploracao(X, Y, chute) :-
    ouro_restante(R), R > 0,
    ordenadas(fronteira, Casas),
    member(_-_-X-Y, Casas).
    