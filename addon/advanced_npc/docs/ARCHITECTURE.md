# Arquitetura

## Divisão de responsabilidades

`advanced_npc_navigation` é o provedor de topologia e rotas. Não conhece classes de zumbi, jogadores elegíveis ou regras do ZPN. `advanced_npc` cria entidades e consome suas rotas. Plugins de tipo registram perfis e animações em `plugin_precache()`. A bridge decide quais jogadores pertencem à mesma facção; regras de dano, recompensas e modos podem usar os forwards públicos.

A entidade base é `info_target`, com classname próprio `anpc_actor`. `rg_create_entity(..., false)` evita inserir um classname depois renomeado na hash table de entidades do ReGameDLL. A identificação combina marcador privado, slot e serial. Um NPC não ocupa uma vaga de jogador.

O grafo e os retângulos de piso do `ANPC_NAV 4` são carregados uma vez por mapa. Coordenadas de nós, áreas e spawns representam os **pés**, em unidades GoldSrc. Posição central da entidade é calculada de acordo com o hull em pé ou agachado. `navigation_areas.inc` mantém os retângulos no índice espacial do provedor.

`advanced_npc_mapper` é um consumidor/editor separado. Usa de um a oito fake clients temporários, comandos de jogador e hooks ReAPI para explorar e observar saltos reais. Cada scout tem estado de sensores, movimento e busca próprio, escolhido pelo escalonador; callbacks de entidades identificam diretamente seu scout sem trocar o contexto de outro comando. Grafo, cobertura, journal, sementes e orçamento por frame são compartilhados. Reservas de âncoras distribuem fronteiras e são liberadas em todos os caminhos de interrupção. O BSP fornece limites para amostragem; hulls e piso propõem trajetos, e o movimento valida conexões. A memória `ANPC_SCAN 2` preserva a árvore de descoberta; sensores e cobertura são reconstruídos ao retomar. O core ZPN permanece independente.

As partes internas são `mapper_world.inc` (geometria/episódios/provas), `mapper_coverage.inc` (blocos e tentativas interiores redundantes), `mapper_exploration.inc` (sensores e direções), `mapper_frontiers.inc` (seleção por custo), `mapper_motion.inc` (fake clients e provas físicas), `mapper_storage.inc` (memória/checkpoints) e `mapper_team.inc` (reservas, distribuição, desvio, ciclo de vida e conclusão da equipe), nas includes externas configuradas pelo projeto.

`ground.inc` reúne consultas de apoio e passagem usadas pelo mapper, provedor de navegação e recuperação de rampas do núcleo. Projeta o hull real no piso e acompanha o terreno em intervalos proporcionais a `sv_stepsize`, sem exigir que uma rampa inteira caiba na altura de um degrau. Passagens por cristas consultam a folga vertical disponível nas extremidades. O mapper divide essas consultas entre frames; o provedor conserva um teste rápido de corredor para pisos planos e rampas uniformes. As consultas não gravam conexões nem deslocam entidades.

A cobertura é uma tabela espacial de quadrados alinhados em 256/128/64/32 unidades, com spans de altura independentes e subdivisão dos quatro filhos. Testes de piso estático e faixas de hull sobrepostas classificam interiores planares, inclusive rampas uniformes; volumes sensíveis e geometrias irregulares conservam a análise por nós. Blocos aprovados são enviados ao provedor como retângulos persistentes. A união aceita apenas bordas com a mesma extensão transversal, altura/postura compatíveis e a mesma célula espacial, preservando a forma retangular. Máscaras de exploração continuam fora do journal. Os callbacks de obstáculo usados pelo mapper invalidam cobertura e áreas; a reconstrução é incremental.

Após esgotar a exploração, `navigation_portals.inc` compacta amostras comuns internas, preserva conexões que saem da área e cria portais nas bordas com planos contínuos. Associação área/âncoras é reconstruída ao carregar; amostras do journal são remapeadas somente na gravação final. Checkpoints incompletos mantêm os IDs de exploração. A retomada revalida os planos das áreas por etapas, sem exigir nós internos. O núcleo aceita nascer e perseguir dentro de uma área isolada mesmo sem nós.

O mapper dispensa âncoras periódicas dentro da cobertura plana. Fora dela, usa o espaçamento completo, limitado a doze passadas de prova do piso, e evita um ponto periódico imediatamente antes de uma chegada próxima quando o segmento cabe na prova limitada. Ao sair para piso desconhecido ou não planar, preserva a última posição alcançada ainda no interior; cristas e movimentos especiais mantêm pontos precisos. Âncoras comuns próximas podem ser reutilizadas até `0,75 × espaçamento`, com provas de hull e apoio; saídas/chegadas precisas só reutilizam posições a menos de quatro unidades. A consulta oferece oito candidatos próximos; o mapper testa até quatro, validando o alinhamento real e a ligação desde a origem. Ao reutilizar uma posição distante, o explorador termina fisicamente nela antes da próxima análise. Esse alinhamento fixa a âncora, conserva o prazo original e compartilha a tolerância de conclusão (12 unidades XY e 12 de altura). Rotas conhecidas e alinhamentos dispensam amostras terrestres intermediárias. O mapper também pode encurtar até oito waypoints apoiados em cobertura contínua, preservando postura e transições precisas ou especiais.

A seleção usa Dijkstra com heap e stamps de geração sobre as arestas direcionadas já comprovadas e a caminhada implícita nas áreas certificadas. A enumeração espacial incremental permanece disponível durante a edição, antes de construir as listas finais de associação. O cursor conserva a expansão em andamento entre frames; mudanças de cobertura invalidam uma conclusão sem candidatos quando necessário. O custo pondera distância e movimentos, e a utilidade considera direções pendentes e visitas. Uma fronteira alcançável precede a manutenção de ligações inversas. Caminhada inteiramente em cobertura estática plana pode receber a inversa pela simetria da prova após a ida real; os outros movimentos exigem retorno físico. O limite inferior da pontuação encerra cedo buscas com um vencedor garantido pelo modelo de custo. O A* do provedor segue responsável pela rota efetiva.

Durante o scan, uma sessão de edição exclusiva bloqueia outros escritores e a criação de NPCs. Revisões e invalidações são publicadas no início/final da sessão, em vez de a cada ponto. Fronteiras, buscas A* e registros de checkpoint são processados por etapas. O forward de frame e os hooks de movimento/toque do explorador ficam ativos apenas durante a sessão. Consulte `AUTOMAPPER.md` para memória, prova de passagem e limites de custo.

O comando `watch 1 [scout]` usa uma câmera invisível e não sólida por scout observado, compartilhada entre seus observadores, nos olhos e com seus ângulos completos. Um hook de `AddToFullPack` oculta apenas o corpo selecionado para cada administrador. Câmeras sem observadores são liberadas. `RH_SV_AllowPhysent` exclui somente scouts válidos entre si da física de jogador, impedindo bloqueios e apoio sobre parceiros; o desvio lateral exige piso e hull validados e não altera saltos/escadas. A direção do modelo continua sendo atualizada pela física, com `fixangle` liberado antes de `RunPlayerMove`.

O desenho opcional `blocks` consulta apenas blocos abertos próximos, usando beams do sprite já precacheado. Não cria entidades nem traces, e distribui as atualizações entre os administradores que o habilitam.

## Percepção e escolha de alvo

- Uma amostra de jogadores vivos é compartilhada durante 0,2 s, incluindo posição dos pés e velocidade.
- Cada tipo define seu intervalo de percepção; o zumbi inicial usa 0,3 s.
- O filtro público considera facção, rodada e políticas de plugins. O núcleo valida conexão, vida e `userid`.
- Distância, preferência pelo alvo atual e agressor recente entram na pontuação. A preferência pelo alvo atual reduz trocas constantes.
- Um shortlist limita traces de visão e consultas de destino. Em percepção local ele alterna candidatos para cobrir todos os jogadores ao longo das consultas. Pontos de destino são compartilhados entre NPCs do mesmo tipo e atualizados por tempo, deslocamento ou revisão do grafo.
- `ANPC_GLOBAL_HUNT` habilita rastreamento global pelo grafo. Em percepção local, uma posição vista é mantida pelo tempo de memória; dano recebido funciona como estímulo de agressor.
- Destinos sem rota são temporariamente rejeitados, permitindo tentar outro jogador em vez de insistir continuamente no mesmo destino.

No trecho final, uma pequena antecipação do movimento do alvo é aceita somente após testar hull e apoio. Em um retângulo certificado, o apoio estático pode ser reutilizado e a perseguição direta alcança seu interior inteiro. O resultado fica em cache por 0,15 s; `WalkMove` ainda aplica colisão em cada deslocamento.

## Planejamento

A* usa heap binário com atualização de prioridade, custo geométrico e penalidades para agachar, subir escada e saltar. A heurística é distância euclidiana; os custos das arestas são pelo menos essa distância, preservando sua admissibilidade e consistência.

Há quatro buscas simultâneas. Um orçamento global de operações é dividido em round robin a cada `FM_StartFrame`. Os outros pedidos aguardam em uma fila circular. Stamps de geração evitam zerar milhares de células a cada busca. O forward de frame fica registrado somente enquanto existem pedidos pendentes.

Cada ator tem um handle de rota com geração e proprietário. Cancelamento elimina buscas em andamento. A rota completa é reconstruída em um `Array`; nenhum limite menor que o tamanho do grafo corta silenciosamente um caminho longo. Alterações do editor incrementam a revisão e invalidam rotas.

O seguidor pode olhar até oito âncoras adiante e dispensar pontos comuns intermediários ao longo de cobertura contínua de retângulos, após testar o hull até o destino escolhido. Interrompe essa simplificação diante de salto/queda, escada, ponto de raio 8 ou mudança de postura. A* também enumera WALK implícito entre âncoras da mesma área. Portais nas bordas compartilhadas conectam regiões geométricas adjacentes; saltos, quedas e escadas continuam explícitos. Cada operação processa um vizinho ou uma parte limitada da enumeração, evitando expandir uma área densa inteira no mesmo frame.

Uma aresta fisicamente bloqueada pode ficar indisponível por três segundos. Colisões temporárias com jogadores e outros NPCs não bloqueiam a topologia compartilhada. Alterações do mundo são verificadas durante o movimento; o algoritmo de busca não varre todas as entidades e todos os obstáculos a cada expansão.

## Movimento

`EngFunc_WalkMove` executa cada passo terrestre com colisão e step height do motor. Gravidade e movimento no ar usam `MOVETYPE_STEP` e velocidade física. O núcleo não substitui a origem para avançar uma rota.

Quando um deslocamento direto falha, o núcleo tenta completá-lo em até oito partes menores no mesmo Think, antes de usar desvios laterais. A soma dessas partes não ultrapassa a distância solicitada por `velocidade × dt`. Isso evita que uma passada longa comece dentro da rampa no teste vertical de `SV_movestep`.

`SV_CheckBottom` também exige apoio no centro e nos quatro cantos dentro de `sv_stepsize`; uma rampa diagonal válida para jogadores pode falhar nessa exigência. Após falha de `WalkMove`, o núcleo só relaxa essa verificação para uma passada curta com apoio estático inclinado e passagem do hull comprovados. `FL_PARTIALGROUND` fica restrita à chamada de `WalkMove`, com limpeza da flag acrescentada pelo núcleo e validação de entidade/serial nos callbacks. A colisão do motor permanece ativa. Pisos planos, ausência de apoio, paredes e inclinações recusadas não recebem essa correção.

Uma ligação marcada como queda pode ser percorrida andando quando `anpc_nav_walkable` encontra apoio contínuo até o destino. Isso evita saltos desnecessários em descidas de rampas onde o scout perdeu contato com o chão por alguns comandos. Quedas sem essa passagem e ligações de salto continuam usando o movimento aéreo.

Agachar no chão modifica o hull e desloca o centro exatamente 18 unidades, preservando os pés. No salto, o núcleo também pode encolher o hull mantendo o centro, elevando os pés em 18 unidades como no jogador; a trajetória precisa passar no teste de colisão. A postura da decolagem vem da âncora de saída, evitando agachar antes do salto apenas porque a chegada é baixa. Levantar após pousar exige espaço para o hull inteiro.

Saltos usam a gravidade atual do servidor, a gravidade do perfil, destino, velocidade horizontal máxima e limite de lançamento vertical. Velocidades aprendidas servem como referência de tempo; se esse arco falha, o núcleo tenta a solução com o limite vertical do perfil. Quando necessário e permitido, tenta agachamento no ar. Uma sequência de traces com intervalos limitados por tempo/distância verifica o arco; a aproximação à âncora anterior a um salto/queda exige até quatro unidades de precisão. Arcos recusados são consultados no máximo a cada 0,2 s, preservando a recuperação por falta de progresso. Uma ligação de descida usa um pequeno salto físico, com limite de velocidade e colisão também verificados.

Escadas precisam de nós marcados e de uma `func_ladder` real na região. O movimento remove gravidade apenas enquanto há contato com essa região, mantém colisão do hull e devolve a entidade à física terrestre ao sair. A marcação de um nó, isoladamente, não permite voar até qualquer altura.

Ao encontrar um obstáculo, o NPC pode atacar um `func_breakable` vulnerável ou usar uma porta comum sem `targetname`, respeitando `SF_DOOR_NOMONSTERS`. A abertura recebe uma espera limitada de 2,5 s por encontro; repetições de `Use` não renovam essa espera continuamente. Portas controladas por ações de mapa precisam de rotas e travessias que representem essa ação. A execução original de `Use`/`TakeDamage` mantém os callbacks do mapa.

Recuperação usa passos laterais com colisão, análise de progresso em direção ao waypoint, bloqueio temporário e replanejamento. Após tentativas repetidas, o alvo é rejeitado por um intervalo. Deslocamento lateral sem aproximação não conta sozinho como progresso. Uma janela adicional de posição detecta permanência dentro de 16 unidades após 1,8 segundo acumulado de tentativas de movimento; trocas de waypoint e replanejamento não reiniciam essa janela. Esperas sem comandos não somam todo o tempo ocioso: o incremento é limitado a 0,2 segundo por consulta de progresso. Limpar o alvo reinicia o estado físico da janela.

## Combate e ciclo de vida

Estados: `IDLE`, `HUNT`, `ATTACK`, `RECOVER`, `DEAD`.

O ataque guarda o jogador e seu `userid`, aguarda a preparação e repete filtros, alcance e trace no impacto. A bridge impede atingir alguém que se tornou zumbi durante a preparação. A chamada de dano usa `ExecuteHamB(Ham_TakeDamage)`, mantendo o fluxo de dano de jogador do ReGameDLL e os hooks de outros plugins.

No NPC, o `TraceAttack` original conserva `AddMultiDamage`, tiros múltiplos e penetração; o hook ajusta dano de cabeça. `BloodColor` devolve o sangue do perfil. O núcleo controla `TakeDamage` porque `CBaseEntity::Killed` removeria imediatamente a entidade base, impedindo a animação de morte e o ciclo de vida do NPC.

Remoção pública é diferida. Morte torna a entidade invulnerável e não sólida, cancela a rota e exibe a animação antes de liberar o slot. O restart da rodada remove os NPCs anteriores. A liberação externa de um edict também devolve a rota e o slot.

## Custos e limites

| Recurso | Limite/padrão |
| --- | --- |
| Slots de NPC | Máximo 32; cvar inicial 24, incluindo corpos ainda existentes |
| Tipos | 16 |
| Nós | 4.096 por mapa |
| Áreas planas | 4.096 por mapa; lados de 32 a 256 unidades |
| Saídas por nó | Dinâmicas, direcionadas, sem destinos duplicados; no máximo outros nós existentes |
| Buscas simultâneas | 4 |
| Expansões por frame | 192 no total, configuráveis entre 16 e 1.024 |
| Think ativo | 0,05 s; inativo 0,2 s; corpo 0,1 s |
| Replanejamento | Intervalo mínimo configurado, padrão 0,75 s |
| Acessibilidade de âncora | Até 8 candidatos próximos, obtidos por índice espacial |

Origem, flags e índices dos nós/áreas, heaps, stamps e custos permanecem arrays densos com limites explícitos. As sete células de cada aresta física ficam em um `Array:` criado por nó conforme necessário, substituindo 0,875 MiB de tabelas estáticas por handles, registros e reservas proporcionais ao grafo. Reset, desligamento e compactação final liberam ou transferem esses handles sem duplicar a propriedade. Rotas dinâmicas crescem conforme seus comprimentos, até cerca de 0,5 MiB de registros se todos os 32 caminhos tiverem 4.096 nós. O heap/stack Pawn e os edicts somam custos adicionais. O orçamento por expansões controla trabalho algorítmico e não equivale a uma garantia de milissegundos em qualquer máquina.

O mapper usa arrays dinâmicas para blocos (19 células), sementes (6), escadas (7) e volumes sensíveis (8), lendo/escrevendo registros inteiros quando possível. Os índices espaciais continuam densos. `Array:` reduz reservas arbitrárias e permite crescer; cada acesso passa por uma native e não garante maior velocidade que um array Pawn direto. Consulte [a revisão de estruturas e técnicas](SCAN_REVIEW.md).

O sistema precisa de medição no servidor real para ajustar quantidade de NPCs e frequência de Think. O custo de colisão depende do BSP, das entidades sólidas e das rotas escolhidas.
