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

% 2. Se sente Reflexo (Poção de Cura na sala) e energia < 100, pega
decidir_acao(pegar) :-
    posicao_atual(X, Y),
    sentiu(X, Y, reflexo),
    energia(E),
    E < 100, !.


/* -------------------------------------------------------------------------
   TASK 2.2: EXPLORAÇÃO IMEDIATA SEGURA (PRIORIDADE ALTA)
   ------------------------------------------------------------------------- */

% Entre as casas adjacentes seguras e inexploradas, escolhe a de menor custo:
% giros necessários (cada um custa 1 ponto e, em casa de monstro, 1 hit) + risco de teletransporte.
% Casas com suspeita de teletransportador ficam para o 'explorar' (que as deixa por último).
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

% Se não há casa segura adjacente a explorar, delega a navegação de longo alcance ao A*
% ('explorar'). O Python pergunta ao Prolog o destino via destino_exploracao/3, que devolve
% as casas seguras e, se não restar nenhuma, o chute calculado (casa suspeita de menor
% risco esperado, ver Task 1.6 em inferencia.pl).
decidir_acao(explorar) :-
    \+ tem_adjacente_segura_inexplorada, !.

/* =========================================================================
   HELPER PREDICATES (REGRAS AUXILIARES DE NAVEGAÇÃO E GEOMETRIA)
   ========================================================================= */

% Suporta tanto visitada/2 quanto visitado/2 para evitar incompatibilidades
eh_visitada(X, Y) :- visitada(X, Y), !.
eh_visitada(X, Y) :- visitado(X, Y).

% Casa adjacente segura, inexplorada e sem suspeita de poço/monstro/teletransportador
candidata_imediata(VX, VY) :-
    segura(VX, VY),
    \+ eh_visitada(VX, VY),
    \+ possivel_poco(VX, VY),
    \+ possivel_monstro(VX, VY),
    \+ possivel_teletransporte(VX, VY),
    \+ parede(VX, VY).

% Verifica se há alguma adjacente que seja segura E inexplorada
tem_adjacente_segura_inexplorada :-
    ouro_restante(R), R > 0,
    posicao_atual(PX, PY),
    adjacente_valida(PX, PY, VX, VY, _),
    candidata_imediata(VX, VY).

% Número de giros (0, 1 ou 2) para ir de uma direção a outra
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