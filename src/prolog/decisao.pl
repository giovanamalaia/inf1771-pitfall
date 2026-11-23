/* =========================================================================
   TASK 2: ÁRVORE DE DECISÃO HIERÁRQUICA
   ========================================================================= */

% Predicado principal de decisão chamado a cada turno pelo Python
executa_acao(Acao) :-
    decidir_acao(Acao), !.

% Fallback de segurança: Se nenhuma regra reativa casar, aciona a exploração/A*
% (NUNCA forçar 'andar' aqui para não cair em poços por engano)
executa_acao(explorar).


/* -------------------------------------------------------------------------
   TASK 2.1: AÇÕES DE REAÇÃO RÁPIDA (PRIORIDADE MÁXIMA)
   ------------------------------------------------------------------------- */

% 1. Se sente Brilho (Ouro na sala atual), a ação obrigatoriamente é pegar
decidir_acao(pegar) :-
    posicao_atual(X, Y),
    sentiu(X, Y, brilho),
    afirma(ouro_pego(X, Y)), !.

% 2. Se sente Reflexo (Poção de Cura na sala) e energia <= 50, pega para aproveitar os +50 completos
decidir_acao(pegar) :-
    posicao_atual(X, Y),
    sentiu(X, Y, reflexo),
    energia(E),
    E =< 50, !.


/* -------------------------------------------------------------------------
   TASK 2.2: EXPLORAÇÃO IMEDIATA SEGURA (PRIORIDADE ALTA)
   ------------------------------------------------------------------------- */

% Entre as adjacentes seguras e inexploradas, vai na de menor custo (giros + risco)
decidir_acao(Acao) :-
    posicao_atual(PX, PY),
    posicao(PX, PY, DirAtual),
    findall(Custo-DirDesejada,
            ( adjacente_valida(PX, PY, VX, VY, DirDesejada),
              candidata_imediata(VX, VY),
              giros(DirAtual, DirDesejada, Giros),
              custo_casa(VX, VY, Risco),
              Custo is Giros + Risco ),
            Opcoes),
    Opcoes \== [],
    msort(Opcoes, [_-DirEscolhida|_]),
    gera_acao_movimento(DirAtual, DirEscolhida, Acao), !.


/* -------------------------------------------------------------------------
   TASK 2.3: FUGA DE BECO SEM SAÍDA (PRIORIDADE MÉDIA)
   ------------------------------------------------------------------------- */

% Sem adjacente segura a explorar: o A* leva até o destino de destino_exploracao/3
decidir_acao(explorar) :-
    \+ tem_adjacente_segura_inexplorada, !.

/* =========================================================================
   HELPER PREDICATES (REGRAS AUXILIARES DE NAVEGAÇÃO E GEOMETRIA)
   ========================================================================= */

% Suporta tanto visitada/2 quanto visitado/2 para evitar incompatibilidades
eh_visitada(X, Y) :- visitada(X, Y), !.
eh_visitada(X, Y) :- visitado(X, Y).

% Possível teletransportador não entra aqui: só vamos até ele pelo A* (explorar)
% quando não existir nenhuma outra casa segura sem risco para explorar.
candidata_imediata(VX, VY) :-
    segura(VX, VY),
    \+ eh_visitada(VX, VY),
    \+ possivel_teletransporte(VX, VY),
    \+ possivel_poco(VX, VY),
    \+ possivel_monstro(VX, VY),
    \+ teletransporte_confirmado(VX, VY),
    \+ monstro_confirmado(VX, VY),
    \+ parede(VX, VY).

% Verifica se há alguma adjacente que seja segura E inexplorada
tem_adjacente_segura_inexplorada :-
    ouro_restante(R), R > 0,
    posicao_atual(PX, PY),
    adjacente_valida(PX, PY, VX, VY, _),
    candidata_imediata(VX, VY).

giros(D, D, 0) :- !.
giros(D1, D2, 2) :- oposta(D1, D2), !.
giros(_, _, 1).
oposta(norte, sul). oposta(sul, norte). oposta(leste, oeste). oposta(oeste, leste).

% Mapeia as 4 direções cardinais em relação à posição atual e respeita limites do mapa
adjacente_valida(PX, PY, PX, VY, norte) :- 
    map_size(_, MAX_Y), PY < MAX_Y, VY is PY + 1.
adjacente_valida(PX, PY, PX, VY, sul)   :- 
    PY > 1, VY is PY - 1.
adjacente_valida(PX, PY, VX, PY, leste) :- 
    map_size(MAX_X, _), PX < MAX_X, VX is PX + 1.
adjacente_valida(PX, PY, VX, PY, oeste) :- 
    PX > 1, VX is PX - 1.

% Traduz a direção atual e a desejada na ação exata de rotação ou avanço
gera_acao_movimento(Dir, Dir, andar) :- !.
gera_acao_movimento(norte, leste, virar_direita) :- !.
gera_acao_movimento(leste, sul, virar_direita) :- !.
gera_acao_movimento(sul, oeste, virar_direita) :- !.
gera_acao_movimento(oeste, norte, virar_direita) :- !.
gera_acao_movimento(norte, oeste, virar_esquerda) :- !.
gera_acao_movimento(oeste, sul, virar_esquerda) :- !.
gera_acao_movimento(sul, leste, virar_esquerda) :- !.
gera_acao_movimento(leste, norte, virar_esquerda) :- !.
% Turnaround: Se precisa ir para a direção oposta, vira para a direita primeiro
gera_acao_movimento(_, _, virar_direita).