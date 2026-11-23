################################################
import pygame
import sys, time, random
from pyswip import Prolog, Functor, Variable, Query
from metrics_tracker import MetricsTracker
import pathlib
from a_search import AStarNavegador 

current_path = pathlib.Path().resolve()
tracker = MetricsTracker()

# Permite passar o mapa por argumento (ex: python gmap.py mapa-dificil.pl)
nome_mapa_arg = sys.argv[1] if len(sys.argv) > 1 else "mapa-facil.pl"
if not nome_mapa_arg.endswith(".pl"):
    nome_mapa_arg += ".pl"
nome_mapa_limpo = pathlib.Path(nome_mapa_arg).stem

# --teste: roda rápido e fecha no fim (usado no run_testes.py)
modo_teste = '--teste' in sys.argv

pl_file = (current_path / '../prolog/agente.pl').resolve().as_posix()
mapa_file = (current_path / '../../mapas' / nome_mapa_arg).resolve().as_posix()

prolog = Prolog()
prolog.consult(pl_file)
prolog.consult(mapa_file)

navegador = AStarNavegador(prolog)
fila_acoes_a_estrela = []

elapsed_time = 0
auto_play_tempo = 0.3
auto_play = True # false para testar controlar manualmente
if modo_teste:
    auto_play_tempo = 0
MAX_ACOES = 1000 # pra não ficar em loop
show_map = False

scale = 50
size_x = 12
size_y = 12
width = size_x * scale  #Largura Janela
height = size_y * scale #Altura Janela

player_pos = (1,1,'norte')
posicao_anterior = (1, 1)
energia = 100
energia_anterior = 100
pontuacao = 0

mapa=[['','','','','','','','','','','',''],
      ['','','','','','','','','','','',''],
      ['','','','','','','','','','','',''],
      ['','','','','','','','','','','',''],
      ['','','','','','','','','','','',''],
      ['','','','','','','','','','','',''],
      ['','','','','','','','','','','',''],
      ['','','','','','','','','','','',''],
      ['','','','','','','','','','','',''],
      ['','','','','','','','','','','',''],
      ['','','','','','','','','','','',''],
      ['','','','','','','','','','','','']]

visitados = []
certezas = []
last_action = ""
ultimo_movimento = ""  # pra detectar teletransporte
ganhou = False
fim_exploracao = False
msg_ouro_ate = 0
ouros_pegos = []
seguras_nao_visitadas = set()  # contorno verde na tela

def decisao():
    acao = ""    
    acoes = list(prolog.query("executa_acao(X)"))
    if len(acoes) > 0:
        acao = acoes[0]['X']
    return acao

def exec_prolog(a):
    global last_action, ultimo_movimento
    if a != "":
        list(prolog.query(a))
    last_action = a
    ultimo_movimento = a

def consulta_casas(consulta):
    # casas (x, y) que respondem a consulta
    try:
        return {(int(r["X"]), int(r["Y"])) for r in prolog.query(consulta)}
    except Exception:
        return set()

def update_prolog():
    global player_pos, mapa, energia, pontuacao, visitados, show_map

    list(prolog.query("atualiza_obs, verifica_player"))

    x = Variable()
    y = Variable()
    visitado = Functor("visitado", 2)
    visitado_query = Query(visitado(x,y))
    visitados.clear()
    while visitado_query.nextSolution():
        visitados.append((x.value,y.value))
    visitado_query.closeQuery()

    x = Variable()
    y = Variable()
    certeza = Functor("certeza", 2)
    certeza_query = Query(certeza(x,y))
    certezas.clear()
    while certeza_query.nextSolution():
        certezas.append((x.value,y.value))
    certeza_query.closeQuery()
        
    if show_map:    
        seguras_nao_visitadas.clear()
        x = Variable()
        y = Variable()
        z = Variable()    
        tile = Functor("tile", 3)
        tile_query = Query(tile(x,y,z))
        while tile_query.nextSolution():
            mapa[y.get_value()-1][x.get_value()-1] = str(z.value)
        tile_query.closeQuery()

    else:

        y = 0
        for j in mapa:
            x = 0
            for i in j:
                mapa[y][x] = ''
                x  += 1
            y +=  1

        x = Variable()
        y = Variable()
        z = Variable()    
        # desenha o que o agente sabe (inferencia.pl)
        # colorido = confirmado, cinza = suspeita, verde = segura não visitada
        poco_c    = consulta_casas("poco_confirmado(X, Y)")
        monstro_c = consulta_casas("monstro_confirmado(X, Y)")
        tele_c    = consulta_casas("teletransporte_confirmado(X, Y)")
        confirmadas = poco_c | monstro_c | tele_c

        poco_p    = consulta_casas("possivel_poco(X, Y)") - confirmadas
        monstro_p = consulta_casas("possivel_monstro(X, Y)") - confirmadas
        tele_p    = consulta_casas("possivel_teletransporte(X, Y)") - confirmadas

        brilho  = consulta_casas("sentiu(X, Y, brilho)")
        reflexo = consulta_casas("sentiu(X, Y, reflexo)")

        visitadas_kb = consulta_casas("visitada(X, Y)")
        seguras_kb   = consulta_casas("segura(X, Y)")

        for casas, letra in [(poco_c, 'P'), (monstro_c, 'D'), (tele_c, 'T'),
                             (poco_p, 'P'), (monstro_p, 'D'), (tele_p, 'T'),
                             (brilho, 'O'), (reflexo, 'U')]:
            for (cx, cy) in casas:
                if 1 <= cx <= 12 and 1 <= cy <= 12:
                    mapa[cy-1][cx-1] += letra

        visitados.clear()
        visitados.extend(visitadas_kb)
        certezas.clear()
        certezas.extend(confirmadas | brilho | reflexo)
        seguras_nao_visitadas.clear()
        seguras_nao_visitadas.update(seguras_kb - visitadas_kb - confirmadas)

    x = Variable()
    y = Variable()
    z = Variable()

    posicao = Functor("posicao", 3)
    position_query = Query(posicao(x,y,z))
    position_query.nextSolution()
    player_pos = (x.value,y.value,str(z.value))
    position_query.closeQuery()

    x = Variable()
    energia_functor = Functor("energia", 1)
    energia_query = Query(energia_functor(x))
    energia_query.nextSolution()
    energia = x.value
    energia_query.closeQuery()

    x = Variable()
    pontuacao_functor = Functor("pontuacao", 1)
    pontuacao_query = Query(pontuacao_functor(x))
    pontuacao_query.nextSolution()
    pontuacao = x.value
    pontuacao_query.closeQuery()


def load():
    global sys_font, clock, img_wall, img_grass, img_start, img_finish, img_path
    global img_gold,img_health, img_pit, img_bat, img_enemy1, img_enemy2,img_floor
    global bw_img_gold,bw_img_health, bw_img_pit, bw_img_bat, bw_img_enemy1, bw_img_enemy2,bw_img_floor
    global img_player_up, img_player_down, img_player_left, img_player_right, img_tomb

    sys_font = pygame.font.Font(pygame.font.get_default_font(), 20)
    clock = pygame.time.Clock() 

    img_wall = pygame.image.load('wall.jpg')
    img_wall_size = (width/size_x, height/size_y)
    img_wall = pygame.transform.scale(img_wall, img_wall_size)

    img_player_up = pygame.image.load('player_up.png')
    img_player_up_size = (width/size_x, height/size_y)
    img_player_up = pygame.transform.scale(img_player_up, img_player_up_size)

    img_player_down = pygame.image.load('player_down.png')
    img_player_down_size = (width/size_x, height/size_y)
    img_player_down = pygame.transform.scale(img_player_down, img_player_down_size)

    img_player_left = pygame.image.load('player_left.png')
    img_player_left_size = (width/size_x, height/size_y)
    img_player_left = pygame.transform.scale(img_player_left, img_player_left_size)

    img_player_right = pygame.image.load('player_right.png')
    img_player_right_size = (width/size_x, height/size_y)
    img_player_right = pygame.transform.scale(img_player_right, img_player_right_size)

    img_tomb = pygame.image.load('tombstone.png')
    img_tomb_size = (width/size_x, height/size_y)
    img_tomb = pygame.transform.scale(img_tomb, img_tomb_size)

    img_grass = pygame.image.load('grass.jpg')
    img_grass_size = (width/size_x, height/size_y)
    img_grass = pygame.transform.scale(img_grass, img_grass_size)

    img_floor = pygame.image.load('floor.png')
    img_floor_size = (width/size_x, height/size_y)
    img_floor = pygame.transform.scale(img_floor, img_floor_size)

    img_gold = pygame.image.load('gold.png')
    img_gold_size = (width/size_x, height/size_y)
    img_gold = pygame.transform.scale(img_gold, img_gold_size)

    img_pit = pygame.image.load('pit.png')
    img_pit_size = (width/size_x, height/size_y)
    img_pit = pygame.transform.scale(img_pit, img_pit_size)

    img_enemy1 = pygame.image.load('enemy1.png')
    img_enemy1_size = (width/size_x, height/size_y)
    img_enemy1 = pygame.transform.scale(img_enemy1, img_enemy1_size)

    img_enemy2 = pygame.image.load('enemy2.png')
    img_enemy2_size = (width/size_x, height/size_y)
    img_enemy2 = pygame.transform.scale(img_enemy2, img_enemy2_size)

    img_bat = pygame.image.load('bat.png')
    img_bat_size = (width/size_x, height/size_y)
    img_bat = pygame.transform.scale(img_bat, img_bat_size)

    img_health = pygame.image.load('health.png')
    img_health_size = (width/size_x, height/size_y)
    img_health = pygame.transform.scale(img_health, img_health_size)    
    
    bw_img_floor = pygame.image.load('bw_floor.png')
    bw_img_floor_size = (width/size_x, height/size_y)
    bw_img_floor = pygame.transform.scale(bw_img_floor, bw_img_floor_size)

    bw_img_gold = pygame.image.load('bw_gold.png')
    bw_img_gold_size = (width/size_x, height/size_y)
    bw_img_gold = pygame.transform.scale(bw_img_gold, bw_img_gold_size)

    bw_img_pit = pygame.image.load('bw_pit.png')
    bw_img_pit_size = (width/size_x, height/size_y)
    bw_img_pit = pygame.transform.scale(bw_img_pit, bw_img_pit_size)

    bw_img_enemy1 = pygame.image.load('bw_enemy1.png')
    bw_img_enemy1_size = (width/size_x, height/size_y)
    bw_img_enemy1 = pygame.transform.scale(bw_img_enemy1, bw_img_enemy1_size)

    bw_img_enemy2 = pygame.image.load('bw_enemy2.png')
    bw_img_enemy2_size = (width/size_x, height/size_y)
    bw_img_enemy2 = pygame.transform.scale(bw_img_enemy2, bw_img_enemy2_size)

    bw_img_bat = pygame.image.load('bw_bat.png')
    bw_img_bat_size = (width/size_x, height/size_y)
    bw_img_bat = pygame.transform.scale(bw_img_bat, bw_img_bat_size)

    bw_img_health = pygame.image.load('bw_health.png')
    bw_img_health_size = (width/size_x, height/size_y)
    bw_img_health = pygame.transform.scale(bw_img_health, bw_img_health_size)  


def get_sensores():
    global player_pos
    px, py = player_pos[0], player_pos[1]

    brisa, passos, palmas, brilho, reflexo = 0, 0, 0, 0, 0

    res_local = list(prolog.query(f"tile({px}, {py}, Z)"))
    if res_local:
        tile_atual = str(res_local[0]['Z'])
        if tile_atual == 'O': brilho = 1
        if tile_atual == 'U': reflexo = 1

    adjacentes = [(px, py+1), (px, py-1), (px+1, py), (px-1, py)]
    for ax, ay in adjacentes:
        if 1 <= ax <= 12 and 1 <= ay <= 12:
            res_adj = list(prolog.query(f"tile({ax}, {ay}, Z)"))
            if res_adj:
                tile_adj = str(res_adj[0]['Z'])
                if tile_adj == 'P': brisa = 1
                if tile_adj in ['D', 'd']: passos = 1
                if tile_adj == 'T': palmas = 1

    return brisa, passos, palmas, brilho, reflexo


# O Prolog escolhe os destinos; o A* só calcula a rota
def buscar_destino_exploracao(px, py):
    candidatos = [(r["X"], r["Y"], str(r["Tipo"])) for r in prolog.query("destino_exploracao(X, Y, Tipo)")]

    # primeiro as seguras sem risco de teletransporte, depois as outras
    arriscadas = consulta_casas("possivel_teletransporte(X, Y)")
    seguros = [(x, y) for x, y, tipo in candidatos if tipo == "seguro"]
    for grupo in ([c for c in seguros if c not in arriscadas],
                  [c for c in seguros if c in arriscadas]):
        melhor = None
        for x, y in grupo:
            rota = navegador.calcular_rota((px, py), (x, y), player_pos[2])
            if rota is None:
                continue
            custo = len(navegador.converter_rota_em_acoes((px, py), rota, player_pos[2]))
            if melhor is None or custo < melhor[2]:
                melhor = ((x, y), rota, custo)
        if melhor:
            print(f"[A*] Rota segura até {melhor[0]} ({melhor[2]} ações)")
            return melhor[1]

    # sem casa segura alcançável: chute calculado
    for x, y, tipo in candidatos:
        if tipo != "chute":
            continue
        rota = navegador.calcular_rota((px, py), (x, y), player_pos[2], arriscar=True)
        if rota:
            print(f"[A*] Sem casas seguras alcançáveis. Chute calculado: {(x, y)}")
            return rota

    print("[A*] Nenhuma casa a explorar.")
    return None


def sincronizar_eventos_turno(px, py):
    global posicao_anterior, energia_anterior, fila_acoes_a_estrela, ultimo_movimento

    # 1. teletransporte: andou e não está na casa da frente -> a da frente é T
    dx_dir = {'norte': (0, 1), 'sul': (0, -1), 'leste': (1, 0), 'oeste': (-1, 0)}
    casa_tele = None
    if ultimo_movimento == 'andar' and player_pos[2] in dx_dir:
        dx, dy = dx_dir[player_pos[2]]
        cx, cy = posicao_anterior[0] + dx, posicao_anterior[1] + dy
        if 1 <= cx <= 12 and 1 <= cy <= 12 and (px, py) != (cx, cy):
            casa_tele = (cx, cy)
    ultimo_movimento = ""

    if casa_tele is not None:
        tx, ty = casa_tele
        list(prolog.query(f"registra_teletransporte({tx}, {ty}, {px}, {py})"))
        fila_acoes_a_estrela.clear()
        print(f"[TELETRANSPORTE] Ativado em {(tx, ty)} -> acordou em {(px, py)}")

    # 2. Detecta se tomou dano ao entrar na casa atual (monstro vivo confirmado)
    if energia < energia_anterior and player_pos[2] != 'morto':
        list(prolog.query(f"registra_monstro({px}, {py})"))
        fila_acoes_a_estrela.clear()
        print(f"[DANO] Inimigo confirmado em {(px, py)}! Energia: {energia}")

    posicao_anterior = (px, py)
    energia_anterior = energia


def update(dt, screen):
    global elapsed_time, fila_acoes_a_estrela, ganhou, fim_exploracao, msg_ouro_ate
    elapsed_time += dt
    if (elapsed_time / 1000) > auto_play_tempo:
        
        if auto_play and player_pos[2] != 'morto' and not ganhou and not fim_exploracao:
            px, py = player_pos[0], player_pos[1]

            # limite de ações
            if tracker.acoes_executadas >= MAX_ACOES:
                print(f"\n[Fim] Limite de {MAX_ACOES} ações atingido.")
                fim_exploracao = True
                tracker.exportar_relatorio(nome_mapa_limpo)
                elapsed_time = 0
                return
            
            sincronizar_eventos_turno(px, py)
            list(prolog.query(f"atualiza_posicao({px}, {py})"))
            
            brisa, passos, palmas, brilho, reflexo = get_sensores()
            
            t_brisa = 'true' if brisa else 'false'
            t_passos = 'true' if passos else 'false'
            t_palmas = 'true' if palmas else 'false'
            t_brilho = 'true' if brilho else 'false'
            t_reflexo = 'true' if reflexo else 'false'
            
            comando = f"atualiza_estado({t_brisa}, {t_passos}, {t_palmas}, {t_brilho}, {t_reflexo})"
            list(prolog.query(comando))
            
            # 1. A*: Consome ações se houver rota pendente
            if fila_acoes_a_estrela:
                acao = fila_acoes_a_estrela.pop(0)
                tracker.registrar_acao(acao)
                exec_prolog(acao)
                update_prolog()
                tracker.atualizar_status(pontuacao, player_pos[2])
                
                if player_pos[2] == 'morto' or energia <= 0:
                    print("\n[Fim de Jogo] O agente morreu ou esgotou a energia.")
                    tracker.exportar_relatorio(nome_mapa_limpo)
                elapsed_time = 0
                return 

            # 2. Pede a Decisão para o Prolog
            acao = decisao()
            print(f"Ação vinda do Prolog: {acao}")
            
            # 3. Tratamento das Ações
            if acao == 'explorar':
                rota = buscar_destino_exploracao(px, py)
                if rota:
                    fila_acoes_a_estrela = navegador.converter_rota_em_acoes((px, py), rota, player_pos[2])
                    # já anda nesse turno (parado em casa de monstro ele leva dano de novo e trava)
                    if fila_acoes_a_estrela:
                        primeira = fila_acoes_a_estrela.pop(0)
                        tracker.registrar_acao(primeira)
                        exec_prolog(primeira)
                else:
                    print("\n[Fim de Exploração] Nenhuma casa segura ou alcançável restante.")
                    fim_exploracao = True
                    tracker.exportar_relatorio(nome_mapa_limpo)
            elif acao: 
                tracker.registrar_acao(acao)
                if acao == 'pegar' and brilho == 1:
                    tracker.registrar_ouro()
                    ouros_pegos.append((px, py))
                    msg_ouro_ate = pygame.time.get_ticks() + 2000
                    print(f"[OURO] Pegou ouro em {(px, py)}! ({len(ouros_pegos)}/3)")
                exec_prolog(acao)
            
            update_prolog()
            tracker.atualizar_status(pontuacao, player_pos[2])
            
            # Vitória
            if not ganhou and list(prolog.query("ouro_restante(0)")):
                ganhou = True
                print(f"\n[GANHOU!] Os 3 ouros foram coletados. Pontuação final: {pontuacao}")
                tracker.exportar_relatorio(nome_mapa_limpo)

            # Exporta métricas se o agente morreu
            if player_pos[2] == 'morto' or energia <= 0:
                print("\n[Fim de Jogo] O agente morreu ou esgotou a energia.")
                tracker.exportar_relatorio(nome_mapa_limpo)
       
        elapsed_time = 0
        
    
def key_pressed(event):
    
    global show_map
    if event.type == pygame.KEYDOWN:
        
        if not auto_play and player_pos[2] != 'morto':
            if event.key == pygame.K_LEFT: 
                exec_prolog("virar_esquerda")
                update_prolog()

            elif event.key == pygame.K_RIGHT: 
                exec_prolog("virar_direita")
                update_prolog()

            elif event.key == pygame.K_UP: 
                exec_prolog("andar")
                update_prolog()

            if event.key == pygame.K_SPACE:
                exec_prolog("pegar")
                update_prolog()
    
        if event.key == pygame.K_m:
            show_map = not show_map
            update_prolog()


def draw_screen(screen):
    
    screen.fill((0,0,0))
 
    y = 0
    for j in mapa:
        x = 0
        for i in j:

            if (x+1,12-y) in visitados:
                screen.blit(img_floor, (x * img_floor.get_width(), y * img_floor.get_height()))
            else:
                screen.blit(bw_img_floor, (x * bw_img_floor.get_width(), y * bw_img_floor.get_height()))

            if (x+1,12-y) in seguras_nao_visitadas:
                pygame.draw.rect(screen, (0,200,0), (x * img_floor.get_width(), y * img_floor.get_height(), img_floor.get_width(), img_floor.get_height()), 3)

            if mapa[11-y][x].find('P') > -1:
                if (x+1,12-y) in certezas:
                    screen.blit(img_pit, (x * img_pit.get_width(), y * img_pit.get_height()))                            
                else:
                    screen.blit(bw_img_pit, (x * bw_img_pit.get_width(), y * bw_img_pit.get_height()))                            

            if mapa[11-y][x].find('T') > -1:
                if (x+1,12-y) in certezas:
                    screen.blit(img_bat, (x * img_bat.get_width(), y * img_bat.get_height()))
                else:
                    screen.blit(bw_img_bat, (x * bw_img_bat.get_width(), y * bw_img_bat.get_height()))

            if mapa[11-y][x].find('D') > -1:
                if (x+1,12-y) in certezas:
                    screen.blit(img_enemy1, (x * img_enemy1.get_width(), y * img_enemy1.get_height()))                                               
                else:
                    screen.blit(bw_img_enemy1, (x * bw_img_enemy1.get_width(), y * bw_img_enemy1.get_height()))                                               
                            
            if mapa[11-y][x].find('d') > -1:
                if (x+1,12-y) in certezas:
                    screen.blit(img_enemy2, (x * img_enemy2.get_width(), y * img_enemy2.get_height()))                                               
                else:
                    screen.blit(bw_img_enemy2, (x * bw_img_enemy2.get_width(), y * bw_img_enemy2.get_height()))                                               

            if mapa[11-y][x].find('U') > -1:
                if (x+1,12-y) in certezas:
                    screen.blit(img_health, (x * img_health.get_width(), y * img_health.get_height()))                               
                else:
                    screen.blit(bw_img_health, (x * bw_img_health.get_width(), y * bw_img_health.get_height()))                               

            if (x+1,12-y) in ouros_pegos:
                screen.blit(img_gold, (x * img_gold.get_width(), y * img_gold.get_height()))
            elif mapa[11-y][x].find('O') > -1:
                if (x+1,12-y) in certezas:
                    screen.blit(img_gold, (x * img_gold.get_width(), y * img_gold.get_height()))                
                else:
                    screen.blit(bw_img_gold, (x * bw_img_gold.get_width(), y * bw_img_gold.get_height()))                
            
            if x == player_pos[0] - 1  and  y == 12 - player_pos[1]:
                if player_pos[2] == 'norte':
                    screen.blit(img_player_up, (x * img_player_up.get_width(), y * img_player_up.get_height()))                                               
                elif player_pos[2] == 'sul':
                    screen.blit(img_player_down, (x * img_player_down.get_width(), y * img_player_down.get_height()))                                               
                elif player_pos[2] == 'leste':
                    screen.blit(img_player_right, (x * img_player_right.get_width(), y * img_player_right.get_height()))                                               
                elif player_pos[2] == 'oeste':
                    screen.blit(img_player_left, (x * img_player_left.get_width(), y * img_player_left.get_height()))                                                                                                           
                else:
                    screen.blit(img_tomb, (x * img_tomb.get_width(), y * img_tomb.get_height()))                                                                                                           
            x  += 1
        y +=  1

    t = sys_font.render("Pontuação: " + str(pontuacao), False, (255,255,255))
    screen.blit(t, t.get_rect(top = height + 5, left=40))

    t = sys_font.render(last_action, False, (255,255,255))
    screen.blit(t, t.get_rect(top = height + 5, left=width/2-40))
    
    if pygame.time.get_ticks() < msg_ouro_ate and not ganhou:
        t = sys_font.render("Pegou ouro! +495  (" + str(len(ouros_pegos)) + "/3)", False, (255,215,0))
        fundo = t.get_rect(center=(width/2, 30)).inflate(30, 16)
        pygame.draw.rect(screen, (0,0,0), fundo)
        pygame.draw.rect(screen, (255,215,0), fundo, 2)
        screen.blit(t, t.get_rect(center=(width/2, 30)))

    if ganhou:
        t = sys_font.render("GANHOU! Pontuação final: " + str(pontuacao), False, (255,215,0))
        fundo = t.get_rect(center=(width/2, height/2)).inflate(30, 20)
        pygame.draw.rect(screen, (0,0,0), fundo)
        pygame.draw.rect(screen, (255,215,0), fundo, 2)
        screen.blit(t, t.get_rect(center=(width/2, height/2)))
    elif fim_exploracao:
        t = sys_font.render("FIM DA EXPLORAÇÃO! Pontuação: " + str(pontuacao), False, (255,215,0))
        fundo = t.get_rect(center=(width/2, height/2)).inflate(30, 20)
        pygame.draw.rect(screen, (0,0,0), fundo)
        pygame.draw.rect(screen, (255,215,0), fundo, 2)
        screen.blit(t, t.get_rect(center=(width/2, height/2)))

    t = sys_font.render("Energia: " + str(energia), False, (255,255,255))
    screen.blit(t, t.get_rect(top = height + 5, left=width-140))

def main_loop(screen):  
    global clock
    running = True
    
    while running:
        for e in pygame.event.get(): 
            if e.type == pygame.QUIT:
                running = False
                break
            
            key_pressed(e)
            
        dt = clock.tick()
        
        update(dt, screen)
        
        draw_screen(screen)

        pygame.display.update() 

        # no modo teste fecha quando acaba
        if modo_teste and (ganhou or fim_exploracao or player_pos[2] == 'morto' or energia <= 0):
            running = False

update_prolog()

pygame.init()
pygame.display.set_caption(f'INF1771 Trabalho 2 - Agente Lógico ({nome_mapa_limpo})')
screen = pygame.display.set_mode((width, height+30))
load()

main_loop(screen)
pygame.quit()