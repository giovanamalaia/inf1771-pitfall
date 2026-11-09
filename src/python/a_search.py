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
        
        # Pega as casas já visitadas
        for res in self.prolog.query("visitada(X, Y)"):
            casas.add((res["X"], res["Y"]))
            
        # Pega as casas inferidas como seguras 
        for res in self.prolog.query("segura(X, Y)"):
            casas.add((res["X"], res["Y"]))
            
        return casas

    def heuristica(self, a, b):
        """Calcula a Distância de Manhattan entre dois pontos."""
        return abs(a[0] - b[0]) + abs(a[1] - b[1])

    def reconstruir_caminho(self, came_from, atual):
        """Monta a lista final de coordenadas do destino até à origem."""
        caminho = [atual]
        while atual in came_from:
            atual = came_from[atual]
            caminho.append(atual)
        caminho.reverse()
        
        # Retornamos a partir do índice 1 para excluir a casa onde o agente já está
        return caminho[1:]

    def converter_rota_em_acoes(self, origem, rota, direcao_atual):
        """
        Traduz coordenadas em comandos mecânicos.
        Ex: de (1,1) para (2,1) virado para o 'norte', devolve ['virar_direita', 'andar'].
        """
        comandos = []
        bussola = ['norte', 'leste', 'sul', 'oeste']
        dir_atual = direcao_atual
        x_atual, y_atual = origem
        
        for x_dest, y_dest in rota:
            # Determina para que ponto cardeal o agente precisa de ir
            if x_dest > x_atual: dir_desejada = 'leste'
            elif x_dest < x_atual: dir_desejada = 'oeste'
            elif y_dest > y_atual: dir_desejada = 'norte'
            elif y_dest < y_atual: dir_desejada = 'sul'
            
            # Calcula a diferença de índices na bússola
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
            x_atual, y_atual = x_dest
            
        return comandos

    def calcular_rota(self, origem, destino):
        """
        Executa o algoritmo A* padrão.
        Retorna uma lista de tuplas (ex: [(1,2), (2,2), (2,3)]) ou None se não houver rota.
        """
        casas_validas = self.obter_casas_permitidas()
        
        if destino not in casas_validas:
            print(f"[A*] Destino {destino} não é comprovadamente seguro.")
            return None

        open_set = []
        heapq.heappush(open_set, (0, origem))
        
        came_from = {}
        
        # g_score guarda o custo do caminho da origem até o nó atual
        g_score = {origem: 0}
        
        # f_score = g_score + heuristica (custo estimado até o destino)
        f_score = {origem: self.heuristica(origem, destino)}
        
        while open_set:
            _, atual = heapq.heappop(open_set)
            
            if atual == destino:
                return self.reconstruir_caminho(came_from, atual)
                
            x, y = atual
            # o agente só se move em formato de cruz 
            vizinhos = [(x, y+1), (x, y-1), (x-1, y), (x+1, y)]
            
            for vizinho in vizinhos:
                # O A* SÓ PODE OLHAR para a casa se o Prolog permitida
                if vizinho in casas_validas:
                    tentativa_g = g_score[atual] + 1
                    
                    if vizinho not in g_score or tentativa_g < g_score[vizinho]:
                        came_from[vizinho] = atual
                        g_score[vizinho] = tentativa_g
                        f_score[vizinho] = tentativa_g + self.heuristica(vizinho, destino)
                        
                        heapq.heappush(open_set, (f_score[vizinho], vizinho))
                        
        return None # caminho seguro não encontrado