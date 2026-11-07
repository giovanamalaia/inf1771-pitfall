% inferencia.pl
% Guarda o que o agente já viu e descobre quais casas são seguras ou perigosas.

% --- Task 1.1: fatos que mudam durante o jogo ---
:- dynamic posicao_atual/2.
:- dynamic visitada/2.
:- dynamic segura/2.
:- dynamic possivel_poco/2.
:- dynamic possivel_monstro/2.
:- dynamic parede/2.
:- dynamic sentiu/3.   % sentiu(X,Y,brisa) ou sentiu(X,Y,passos): o que a casa visitada sentiu

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
    \+ visitada(X, Y), \+ segura(X, Y), \+ parede(X, Y).

% --- Task 1.2: atualizar o estado com o que o agente sentiu ---

% Usa a posicao_atual/2, então chame atualiza_posicao/2 antes.
atualiza_estado(Brisa, Passos, _Palmas, _Ouro, _Cura) :-
    posicao_atual(X, Y),
    marca_visitada(X, Y, Brisa, Passos),
    adjacentes_validas(X, Y, Adj),
    ( \+ percebido(Brisa), \+ percebido(Passos)
    ->  forall(member((AX,AY), Adj), marca_segura(AX, AY))
    ;   marca_riscos(Adj, Brisa, Passos)
    ),
    desambigua.

% define onde o agente está
atualiza_posicao(X, Y) :-
    retractall(posicao_atual(_, _)),
    assertz(posicao_atual(X, Y)).

marca_visitada(X, Y, Brisa, Passos) :-
    afirma(visitada(X, Y)),
    marca_segura(X, Y),
    retractall(sentiu(X, Y, _)),
    ( percebido(Brisa)  -> assertz(sentiu(X, Y, brisa))  ; true ),
    ( percebido(Passos) -> assertz(sentiu(X, Y, passos)) ; true ).

% casa segura: apaga qualquer suspeita que tinha sobre ela
marca_segura(X, Y) :-
    \+ parede(X, Y),
    retractall(possivel_poco(X, Y)),
    retractall(possivel_monstro(X, Y)),
    afirma(segura(X, Y)).

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

% roda depois de cada atualiza_estado, revisando todas as casas suspeitas
desambigua :-
    findall((X,Y), ( possivel_poco(X, Y) ; possivel_monstro(X, Y) ), Suspeitas),
    forall(member((X,Y), Suspeitas), desambigua_casa(X, Y)).

desambigua_casa(X, Y) :-
    ( possivel_poco(X, Y),    sem_poco(X, Y)    -> retractall(possivel_poco(X, Y))    ; true ),
    ( possivel_monstro(X, Y), sem_monstro(X, Y) -> retractall(possivel_monstro(X, Y)) ; true ),
    (   \+ possivel_poco(X, Y), \+ possivel_monstro(X, Y)
    ->  afirma(segura(X, Y))
    ;   true ).

% --- Task 1.5: teletransporte ---

% só muda a posição; o mapa que o agente já construiu continua igual
teletransporta(NX, NY) :-
    retractall(posicao_atual(_, _)),
    assertz(posicao_atual(NX, NY)).
