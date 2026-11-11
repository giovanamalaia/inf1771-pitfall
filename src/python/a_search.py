import heapq

class AStarNavegador:
    def __init__(self, prolog_instance):
        self.prolog = prolog_instance

    def obter_casas_permitidas(self):
        """
        Consulta a base de conhecimento para montar o grafo.
        Só permite andar onde já foi visitado ou é estritamente seguro.
        """
        casas = set()
        
        # Pega as casas já visitadas (suporta visitada/2 e visitado/2)
        try:
            for res in self.prolog.query("visitada(X, Y)"):
                casas.add((int(res["X"]), int(res["Y"])))
        except Exception:
            pass

        try:
            for res in self.prolog.query("visitado(X, Y)"):
                casas.add((int(res["X"]), int(res["Y"])))
        except Exception:
            pass
            
        # Pega as casas inferidas como seguras 
        try:
            for res in self.prolog.query("segura(X, Y)"):
                casas.add((int(res["X"]), int(res["Y"])))
        except Exception:
            pass
            
        return casas

    def heuristica(self, a, b):
        """Calcula a Distância de Manhattan entre dois pontos."""
        return abs(a[0] - b[0]) + abs(a[1] - b[1])

    def reconstruir_caminho(self, came_from, atual):
        """Monta a lista final de coordenadas do destino até a origem."""
        caminho = [atual]
        while atual in came_from:
            atual = came_from[atual]
            caminho.append(atual)
        caminho.reverse()
        
        # Retorna a partir do índice 1 para excluir a casa onde o agente já está
        return caminho[1:]

    def converter_rota_em_acoes(self, origem, rota, direcao_atual):
        """
        Traduz coordenadas em comandos mecânicos.
        Ex: de (1,1) para (2,1) virado para o 'norte', devolve ['virar_direita', 'andar'].
        """
        if not rota:
            return []

        comandos = []
        bussola = ['norte', 'leste', 'sul', 'oeste']
        dir_atual = str(direcao_atual)
        x_atual, y_atual = int(origem[0]), int(origem[1])
        
        for no in rota:
            # Extração segura das coordenadas do nó
            if isinstance(no, (list, tuple)) and len(no) >= 2:
                x_dest, y_dest = int(no[0]), int(no[1])
            elif hasattr(no, 'x') and hasattr(no, 'y'):
                x_dest, y_dest = int(no.x), int(no.y)
            elif hasattr(no, 'posicao'):
                x_dest, y_dest = int(no.posicao[0]), int(no.posicao[1])
            else:
                continue

            # Se for a mesma posição onde já estamos, pula
            if x_dest == x_atual and y_dest == y_atual:
                continue

            # Determina para qual ponto cardeal o agente precisa ir
            if x_dest > x_atual:
                dir_desejada = 'leste'
            elif x_dest < x_atual:
                dir_desejada = 'oeste'
            elif y_dest > y_atual:
                dir_desejada = 'norte'
            elif y_dest < y_atual:
                dir_desejada = 'sul'
            else:
                continue
            
            # Calcula a diferença de índices na bússola
            if dir_atual in bussola and dir_desejada in bussola:
                idx_atual = bussola.index(dir_atual)
                idx_desejada = bussola.index(dir_desejada)
                diff = (idx_desejada - idx_atual) % 4
                
                # Aplica os giros necessários
                if diff == 1:
                    comandos.append('virar_direita')
                elif diff == 2:
                    comandos.extend(['virar_direita', 'virar_direita'])
                elif diff == 3:
                    comandos.append('virar_esquerda')
            
            comandos.append('andar')
            
            # Atualiza o estado simulado para a próxima iteração
            dir_atual = dir_desejada
            x_atual, y_atual = x_dest, y_dest
            
        return comandos

    def calcular_rota(self, origem, destino):
        """
        Executa o algoritmo A* padrão sobre as casas permitidas pelo Prolog.
        Retorna uma lista de tuplas (ex: [(1,2), (2,2), (2,3)]) ou None se não houver rota.
        """
        casas_validas = self.obter_casas_permitidas()
        
        # Garante a própria origem nas casas válidas
        casas_validas.add((int(origem[0]), int(origem[1])))
        dest_tupla = (int(destino[0]), int(destino[1]))
        
        if dest_tupla not in casas_validas:
            print(f"[A*] Destino {dest_tupla} não é comprovadamente seguro.")
            return None

        origem_tupla = (int(origem[0]), int(origem[1]))
        open_set = []
        heapq.heappush(open_set, (0, origem_tupla))
        
        came_from = {}
        g_score = {origem_tupla: 0}
        f_score = {origem_tupla: self.heuristica(origem_tupla, dest_tupla)}
        
        while open_set:
            _, atual = heapq.heappop(open_set)
            
            if atual == dest_tupla:
                return self.reconstruir_caminho(came_from, atual)
                
            x, y = atual
            vizinhos = [(x, y+1), (x, y-1), (x-1, y), (x+1, y)]
            
            for vizinho in vizinhos:
                if vizinho in casas_validas:
                    tentativa_g = g_score[atual] + 1
                    
                    if vizinho not in g_score or tentativa_g < g_score[vizinho]:
                        came_from[vizinho] = atual
                        g_score[vizinho] = tentativa_g
                        f_score[vizinho] = tentativa_g + self.heuristica(vizinho, dest_tupla)
                        heapq.heappush(open_set, (f_score[vizinho], vizinho))
                        
        return None