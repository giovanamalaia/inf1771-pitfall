import csv
import os

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

    def exportar_relatorio(self, nome_mapa="mapa_padrao"):
        """
        Imprime o relatório e salva os dados no CSV para o vídeo final.
        (Task 3.4 e 3.5: salvar ao fim de cada mapa)
        """
        if not self.jogo_encerrado:
            self.jogo_encerrado = True
            
            print("\n" + "="*30)
            print(f" RELATÓRIO: {nome_mapa.upper()}")
            print("="*30)
            print(f"Ouro Coletado:   {self.ouro_coletado}")
            print(f"Ações Executadas: {self.acoes_executadas}")
            print(f"Pontuação Final:  {self.pontuacao_final}")
            print(f"Sobreviveu:       {'Sim' if self.sobreviveu else 'Não'}")
            print("="*30 + "\n")
            
            arquivo_csv = "relatorio_metricas.csv"
            cabecalho = not os.path.exists(arquivo_csv)
            
            with open(arquivo_csv, mode='a', newline='', encoding='utf-8') as file:
                writer = csv.writer(file)
                if cabecalho:
                    writer.writerow(["Mapa", "Ouro", "Acoes", "Pontuacao", "Sobreviveu"])
                
                writer.writerow([
                    nome_mapa, 
                    self.ouro_coletado, 
                    self.acoes_executadas, 
                    self.pontuacao_final, 
                    "Sim" if self.sobreviveu else "Não"
                ])