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
    sentiu(X, Y, brilho), !.

% 2. Se sente Reflexo (Poção de Cura na sala) e energia < 100, pega
decidir_acao(pegar) :-
    posicao_atual(X, Y),
    sentiu(X, Y, reflexo),
    energia(E),
    E < 100, !.


/* -------------------------------------------------------------------------
   TASK 2.2: EXPLORAÇÃO IMEDIATA SEGURA (PRIORIDADE ALTA)
   ------------------------------------------------------------------------- */

% Se existir uma casa adjacente estritamente segura e ainda não visitada,
% decide como virar ou andar até ela.
decidir_acao(Acao) :-
    posicao_atual(PX, PY),
    posicao(PX, PY, DirAtual),
    adjacente_valida(PX, PY, VX, VY, DirDesejada),
    segura(VX, VY),
    \+ eh_visitada(VX, VY),
    \+ possivel_poco(VX, VY),     % Trava de segurança: impede entrar se houver suspeita de poço
    \+ possivel_monstro(VX, VY),  % Prefere não entrar se houver suspeita de monstro
    gera_acao_movimento(DirAtual, DirDesejada, Acao), !.


/* -------------------------------------------------------------------------
   TASK 2.3: FUGA DE BECO SEM SAÍDA (PRIORIDADE MÉDIA)
   ------------------------------------------------------------------------- */

% Se todas as casas seguras adjacentes já foram visitadas, delega a 
% navegação de longo alcance para o A* do Python retornando 'explorar'.
decidir_acao(explorar) :-
    \+ tem_adjacente_segura_inexplorada, !.

/* -------------------------------------------------------------------------
   TASK 2.4: GESTÃO DE RISCO EXTREMO / CHUTE CALCULADO (PRIORIDADE BAIXA)
   ------------------------------------------------------------------------- */

% Se está ilhado (sem casas seguras inexploradas), prefere arriscar
% entrar numa casa com possivel_monstro (dano de energia) para não morrer em poço.
decidir_acao(Acao) :-
    \+ tem_adjacente_segura_inexplorada,
    posicao_atual(PX, PY),
    posicao(PX, PY, DirAtual),
    adjacente_valida(PX, PY, VX, VY, DirDesejada),
    \+ eh_visitada(VX, VY),
    possivel_monstro(VX, VY),
    \+ possivel_poco(VX, VY),     % NUNCA arrisca poço (-1000 pts / morte)
    \+ parede(VX, VY),
    gera_acao_movimento(DirAtual, DirDesejada, Acao), !.

/* =========================================================================
   HELPER PREDICATES (REGRAS AUXILIARES DE NAVEGAÇÃO E GEOMETRIA)
   ========================================================================= */

% Suporta tanto visitada/2 quanto visitado/2 para evitar incompatibilidades
eh_visitada(X, Y) :- visitada(X, Y), !.
eh_visitada(X, Y) :- visitado(X, Y).

% Verifica se há alguma adjacente que seja segura E inexplorada
tem_adjacente_segura_inexplorada :-
    posicao_atual(PX, PY),
    adjacente_valida(PX, PY, VX, VY, _),
    segura(VX, VY),
    \+ eh_visitada(VX, VY),
    \+ possivel_poco(VX, VY).

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