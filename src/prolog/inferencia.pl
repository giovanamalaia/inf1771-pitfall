% inferencia.pl
% Guarda o que o agente já viu e descobre quais casas são seguras ou perigosas.

% --- Task 1.1: fatos que mudam durante o jogo ---
:- dynamic posicao_atual/2.
:- dynamic visitada/2.
:- dynamic segura/2.
:- dynamic possivel_poco/2.
:- dynamic possivel_monstro/2.
:- dynamic possivel_teletransporte/2.
:- dynamic ouro_pego/2.   % ouros já coletados (o mapa tem 3)
:- dynamic parede/2.
:- dynamic sentiu/3.   % sentiu(X,Y,P): P = brisa | passos | palmas | brilho | reflexo (o que a casa visitada sentiu)

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
    propaga_seguranca.

% define onde o agente está
atualiza_posicao(X, Y) :-
    retractall(posicao_atual(_, _)),
    assertz(posicao_atual(X, Y)).

marca_visitada(X, Y, Brisa, Passos, Palmas, Ouro, Cura) :-
    afirma(visitada(X, Y)),
    marca_segura(X, Y),
    retractall(possivel_teletransporte(X, Y)),   % se fosse teletransportador, não estaríamos aqui
    retractall(sentiu(X, Y, _)),
    ( percebido(Brisa)  -> assertz(sentiu(X, Y, brisa))   ; true ),
    ( percebido(Passos) -> assertz(sentiu(X, Y, passos))  ; true ),
    ( percebido(Palmas) -> assertz(sentiu(X, Y, palmas))  ; true ),
    ( percebido(Ouro)   -> assertz(sentiu(X, Y, brilho))  ; true ),
    ( percebido(Cura)   -> assertz(sentiu(X, Y, reflexo)) ; true ).

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

% se uma vizinha visitada não ouviu palmas, aqui não tem teletransportador
sem_teletransporte(X, Y) :-
    adjacente_valida(X, Y, VX, VY),
    visitada(VX, VY),
    \+ sentiu(VX, VY, palmas).

% palmas: algum vizinho ainda não visitado é teletransportador (não é fatal, mas é um risco)
marca_teletransportes(Adj, Palmas) :-
    (   percebido(Palmas)
    ->  forall(( member((AX,AY), Adj), \+ visitada(AX, AY) ),
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
    (   \+ possivel_poco(X, Y), \+ possivel_monstro(X, Y)
    ->  afirma(segura(X, Y))
    ;   true ).

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

% --- Task 1.6: avaliação de risco e escolha do próximo destino ---
%
% Perigo de cada tipo (o que o agente sente quando está ao lado dele):
%   poco -> brisa (morte, -1000) | monstro -> passos (perde energia, sem perder pontos)
%   teletransporte -> palmas (vai pra uma casa aleatória, pode ser um poço)

perigo(poco,           possivel_poco,           brisa).
perigo(monstro,        possivel_monstro,        passos).
perigo(teletransporte, possivel_teletransporte, palmas).

% Peso de cada perigo no custo esperado.
peso(poco, 1000).
peso(teletransporte, 50).      % ~8% de cair em poço depois do sorteio
% O motor aplica o dano do monstro a CADA ação enquanto o agente está na casa (inclusive virar),
% e o dano vai de 25 a 80: sair da casa custa pelo menos 2 ou 3 hits, então é quase sempre fatal.
% Quanto menos energia, pior.
peso(monstro, W) :- energia(E), ( E > 80 -> W = 500 ; E > 50 -> W = 700 ; W = 900 ).

% O mapa tem 3 ouros: depois de pegar todos não vale mais explorar nem arriscar.
total_ouros(3).
ouro_restante(R) :-
    aggregate_all(count, ouro_pego(_, _), N),
    total_ouros(T),
    R is T - N.

% Quantas casas ainda são candidatas a esconder o perigo que a casa visitada (VX,VY) sentiu
numero_candidatas(VX, VY, Flag, K) :-
    aggregate_all(count, ( adjacente_valida(VX, VY, AX, AY), call(Flag, AX, AY) ), K).

% Cada visitada que sentiu o perigo "culpa" igualmente as K candidatas (prob. 1/K).
% Várias visitadas apontando pra mesma casa aumentam o risco: 1 - prod(1 - 1/K).
risco(Tipo, X, Y, Risco) :-
    perigo(Tipo, Flag, Sensacao),
    call(Flag, X, Y),
    !,
    findall(P, ( adjacente_valida(X, Y, VX, VY),
                 visitada(VX, VY),
                 sentiu(VX, VY, Sensacao),
                 numero_candidatas(VX, VY, Flag, K),
                 P is 1 / K ), Ps),
    (   Ps == []
    ->  Risco = 1.0
    ;   foldl([P, A0, A]>>(A is A0 * (1 - P)), Ps, 1.0, Prod),
        Risco is 1 - Prod ).
risco(_, _, _, 0.0).

% custo esperado de entrar na casa
custo_casa(X, Y, Custo) :-
    findall(C, ( perigo(Tipo, _, _), risco(Tipo, X, Y, R), peso(Tipo, W), C is R * W ), Cs),
    sum_list(Cs, Custo).

% casa conhecida como segura e ainda não visitada
segura_inexplorada(X, Y) :-
    segura(X, Y),
    \+ visitada(X, Y),
    \+ parede(X, Y),
    \+ possivel_poco(X, Y),
    \+ possivel_monstro(X, Y).

% casa de fronteira: suspeita de poço ou monstro, ainda não visitada
fronteira(X, Y) :-
    ( possivel_poco(X, Y) ; possivel_monstro(X, Y) ),
    \+ visitada(X, Y),
    \+ parede(X, Y).

% Candidatos de exploração, em ordem de preferência (por backtracking):
%   1) casas seguras inexploradas (menor risco de teletransporte, depois mais perto)
%   2) só se não houver nenhuma segura: chute calculado = fronteira de menor custo esperado
% Tipo = seguro | chute. O Python tenta rota até cada um; o A* só anda por casas seguras/visitadas.
destino_exploracao(X, Y, Tipo) :-
    ouro_restante(R), R > 0,
    posicao_atual(PX, PY),
    (   Tipo = seguro, Fonte = segura_inexplorada
    ;   Tipo = chute,  Fonte = fronteira ),
    findall(Custo-Dist-CX-CY,
            ( call(Fonte, CX, CY),
              custo_casa(CX, CY, Custo),
              Dist is abs(CX - PX) + abs(CY - PY) ),
            Candidatas),
    msort(Candidatas, Ordenadas),
    member(_-_-X-Y, Ordenadas).
