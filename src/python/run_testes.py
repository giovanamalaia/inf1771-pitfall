# Task 3.5 - roda cada mapa N vezes e gera o resumo
# uso: python3 run_testes.py 10
import csv
import os
import pathlib
import subprocess
import sys

PASTA = pathlib.Path(__file__).resolve().parent
MAPAS = ["mapa-facil.pl", "mapa-medio.pl", "mapa-dificil.pl"]
N = int(sys.argv[1]) if len(sys.argv) > 1 else 10
TEMPO_MAXIMO = 300  # segundos por rodada

CSV_RODADAS = PASTA / "resultados_testes.csv"
CSV_RESUMO = PASTA / "resumo_testes.csv"


def rodar_testes():
    # começa um arquivo novo a cada bateria
    with open(CSV_RODADAS, "w", newline="", encoding="utf-8") as f:
        csv.writer(f).writerow(["Mapa", "Ouro", "Acoes", "Pontuacao", "Sobreviveu"])

    env = dict(os.environ,
               RELATORIO_CSV=str(CSV_RODADAS),
               SDL_VIDEODRIVER="dummy",   # roda sem abrir janela
               SDL_AUDIODRIVER="dummy")

    for mapa in MAPAS:
        for i in range(1, N + 1):
            print(f"[{mapa}] rodada {i}/{N}...", flush=True)
            try:
                subprocess.run([sys.executable, "gmap.py", mapa, "--teste"],
                               cwd=PASTA, env=env, stdout=subprocess.DEVNULL,
                               timeout=TEMPO_MAXIMO, check=False)
            except subprocess.TimeoutExpired:
                print("  tempo esgotado, rodada ignorada", flush=True)


def resumir():
    with open(CSV_RODADAS, newline="", encoding="utf-8") as f:
        linhas = list(csv.DictReader(f))

    resumo = []
    for mapa in MAPAS:
        nome = pathlib.Path(mapa).stem
        rod = [l for l in linhas if l["Mapa"] == nome]
        if not rod:
            continue
        n = len(rod)
        resumo.append({
            "Mapa": nome,
            "Rodadas": n,
            "Ouro medio": round(sum(int(l["Ouro"]) for l in rod) / n, 2),
            "Acoes medias": round(sum(int(l["Acoes"]) for l in rod) / n, 1),
            "Pontuacao media": round(sum(int(l["Pontuacao"]) for l in rod) / n, 1),
            "Sobrevivencia (%)": round(100 * sum(l["Sobreviveu"] == "Sim" for l in rod) / n, 1),
        })

    if not resumo:
        print("Nenhuma rodada registrada. Confira se o gmap.py roda sozinho.")
        return

    with open(CSV_RESUMO, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(resumo[0].keys()))
        w.writeheader()
        w.writerows(resumo)

    print("\n" + "=" * 78)
    print(f"{'Mapa':<14}{'Rodadas':>8}{'Ouro':>8}{'Acoes':>10}{'Pontuacao':>12}{'Sobreviveu':>14}")
    print("-" * 78)
    for r in resumo:
        print(f"{r['Mapa']:<14}{r['Rodadas']:>8}{r['Ouro medio']:>8}{r['Acoes medias']:>10}"
              f"{r['Pontuacao media']:>12}{str(r['Sobrevivencia (%)']) + '%':>14}")
    print("=" * 78)
    print(f"Rodadas: {CSV_RODADAS.name} | Resumo: {CSV_RESUMO.name}")


if __name__ == "__main__":
    rodar_testes()
    resumir()
