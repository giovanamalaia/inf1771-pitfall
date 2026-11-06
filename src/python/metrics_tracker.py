class MetricsTracker:
    def __init__(self):
        self.acoes_executadas = 0
        self.ouro_coletado = 0
        self.pontuacao_final = 0
        self.sobreviveu = True
        self.jogo_encerrado = False

    def registrar_acao(self, acao):
        """Soma 1 ao contador de ações sempre que o agente toma uma decisão válida."""
        if acao in ['andar', 'virar_direita', 'virar_esquerda', 'pegar']:
            self.acoes_executadas += 1

    def registrar_ouro(self):
        """Chamado apenas quando a ação 'pegar' é executada com sucesso em cima de um ouro."""
        self.ouro_coletado += 1

    def atualizar_status(self, pontuacao_atual, estado_jogador):
        """Verifica a cada turno se o jogador morreu e atualiza o saldo de pontos."""
        self.pontuacao_final = pontuacao_atual
        if estado_jogador == 'morto':
            self.sobreviveu = False
            self.encerrar_jogo()

    def encerrar_jogo(self):
        """Imprime o relatório final apenas uma vez quando o jogo acaba."""
        if not self.jogo_encerrado:
            self.jogo_encerrado = True
            print("\n" + "="*30)
            print(" RELATÓRIO DE DESEMPENHO ")
            print("="*30)
            print(f"Ouro Coletado:   {self.ouro_coletado} de 3")
            print(f"Ações Executadas: {self.acoes_executadas}")
            print(f"Pontuação Final:  {self.pontuacao_final}")
            print(f"Sobreviveu:       {'Sim' if self.sobreviveu else 'Não (Caiu em poço)'}")
            print("="*30 + "\n")