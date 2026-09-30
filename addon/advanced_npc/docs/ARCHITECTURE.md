# Arquitetura

## Divisão de responsabilidades

`advanced_npc_navigation` é o provedor de topologia e rotas. Não conhece classes de zumbi, jogadores elegíveis ou regras do ZPN. `advanced_npc` cria entidades e consome suas rotas. Plugins de tipo registram perfis e animações em `plugin_precache()`. A bridge decide quais jogadores pertencem à mesma facção; regras de dano, recompensas e modos podem usar os forwards públicos.

A entidade base é `info_target`, com classname próprio `anpc_actor`. `rg_create_entity(..., false)` evita inserir um classname depois renomeado na hash table de entidades do ReGameDLL. A identificação combina marcador privado, slot e serial. Um NPC não ocupa uma vaga de jogador.

O grafo é carregado uma vez por mapa. Coordenadas de nós e spawns representam os **pés**, em unidades GoldSrc. Posição central da entidade é calculada de acordo com o hull em pé ou agachado.

`advanced_npc_mapper` é um consumidor/editor separado. Usa um fake client temporário, comandos de jogador e hooks ReAPI para explorar e observar saltos reais. O BSP fornece limites para amostragem; hulls e piso propõem trajetos, e o movimento valida conexões. A exploração usa leituras de alcance, tangentes de paredes altas, prioridade por espaço desconhecido, percursos terrestres longos e verificação adiada do retorno pela árvore de descoberta. A memória `ANPC_SCAN 2` preserva essa árvore; sensores são reconstruídos ao retomar. O core ZPN permanece independente. As partes internas são `mapper_world.inc`, `mapper_exploration.inc`, `mapper_motion.inc` e `mapper_storage.inc`, nas includes externas configuradas pelo projeto.

Durante o scan, uma sessão de edição exclusiva bloqueia outros escritores e a criação de NPCs. Revisões e invalidações são publicadas no início/final da sessão, em vez de a cada ponto. Fronteiras, buscas A* e registros de checkpoint são processados por etapas. O forward de frame e os hooks de movimento/toque do explorador ficam ativos apenas durante a sessão. Consulte `AUTOMAPPER.md` para memória, prova de passagem e limites de custo.

## Percepção e escolha de alvo

- Uma amostra de jogadores vivos é compartilhada durante 0,2 s, incluindo posição dos pés e velocidade.
- Cada tipo define seu intervalo de percepção; o zumbi inicial usa 0,3 s.
- O filtro público considera facção, rodada e políticas de plugins. O núcleo valida conexão, vida e `userid`.
- Distância, preferência pelo alvo atual e agressor recente entram na pontuação. A preferência pelo alvo atual reduz trocas constantes.
- Um shortlist limita traces de visão e consultas de destino. Em percepção local ele alterna candidatos para cobrir todos os jogadores ao longo das consultas. Pontos de destino são compartilhados entre NPCs do mesmo tipo e atualizados por tempo, deslocamento ou revisão do grafo.
- `ANPC_GLOBAL_HUNT` habilita rastreamento global pelo grafo. Em percepção local, uma posição vista é mantida pelo tempo de memória; dano recebido funciona como estímulo de agressor.
- Destinos sem rota são temporariamente rejeitados, permitindo tentar outro jogador em vez de insistir continuamente no mesmo destino.

No trecho final, uma pequena antecipação do movimento do alvo é aceita somente após testar o hull e amostrar o chão. O resultado fica em cache por 0,15 s; `WalkMove` ainda aplica colisão em cada deslocamento.

## Planejamento

A* usa heap binário com atualização de prioridade, custo geométrico e penalidades para agachar, subir escada e saltar. A heurística é distância euclidiana; os custos das arestas são pelo menos essa distância, preservando sua admissibilidade e consistência.

Há quatro buscas simultâneas. Um orçamento global de expansões é dividido em round robin a cada `FM_StartFrame`. Os outros pedidos aguardam em uma fila circular. Stamps de geração evitam zerar milhares de células a cada busca. O forward de frame fica registrado somente enquanto existem pedidos pendentes.

Cada ator tem um handle de rota com geração e proprietário. Cancelamento elimina buscas em andamento. A rota completa é reconstruída em um `Array`; nenhum limite menor que o tamanho do grafo corta silenciosamente um caminho longo. Alterações do editor incrementam a revisão e invalidam rotas.

Uma aresta fisicamente bloqueada pode ficar indisponível por três segundos. Colisões temporárias com jogadores e outros NPCs não bloqueiam a topologia compartilhada. Alterações do mundo são verificadas durante o movimento; o algoritmo de busca não varre todas as entidades e todos os obstáculos a cada expansão.

## Movimento

`EngFunc_WalkMove` executa cada passo terrestre com colisão e step height do motor. Gravidade e movimento no ar usam `MOVETYPE_STEP` e velocidade física. O núcleo não substitui a origem para avançar uma rota.

Agachar modifica o hull e desloca o centro exatamente 18 unidades, preservando a posição dos pés. Levantar exige espaço para o hull inteiro. Isso mantém colisão e modelo na altura correta.

Saltos usam a gravidade atual do servidor, a gravidade do perfil, destino, velocidade horizontal máxima e limite de lançamento vertical. Velocidades aprendidas no YaPB servem como referência de tempo; não são aplicadas cegamente. Uma sequência de traces de hull verifica o arco antes do lançamento. Uma ligação de descida usa um pequeno salto físico, com limite de velocidade e colisão também verificados.

Escadas precisam de nós marcados e de uma `func_ladder` real na região. O movimento remove gravidade apenas enquanto há contato com essa região, mantém colisão do hull e devolve a entidade à física terrestre ao sair. A marcação de um nó, isoladamente, não permite voar até qualquer altura.

Ao encontrar um obstáculo, o NPC pode atacar um `func_breakable` vulnerável ou usar uma porta comum sem `targetname`, respeitando `SF_DOOR_NOMONSTERS`. A abertura recebe uma espera limitada de 2,5 s por encontro; repetições de `Use` não renovam essa espera continuamente. Portas controladas por ações de mapa precisam de rotas e travessias que representem essa ação. A execução original de `Use`/`TakeDamage` mantém os callbacks do mapa.

Recuperação usa passos laterais com colisão, análise de progresso em direção ao waypoint, bloqueio temporário e replanejamento. Após tentativas repetidas, o alvo é rejeitado por um intervalo. Deslocamento lateral sem aproximação não conta sozinho como progresso.

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
| Saídas por nó | 8, direcionadas |
| Buscas simultâneas | 4 |
| Expansões por frame | 192 no total, configuráveis entre 16 e 1.024 |
| Think ativo | 0,05 s; inativo 0,2 s; corpo 0,1 s |
| Replanejamento | Intervalo mínimo configurado, padrão 0,75 s |
| Acessibilidade de âncora | Até 8 candidatos próximos, obtidos por índice espacial |

Arrays fixos de grafo e busca usam aproximadamente 1,5 MiB; rotas dinâmicas crescem conforme seus comprimentos, até cerca de 0,5 MiB se todos os 32 caminhos tiverem 4.096 nós. O heap/stack Pawn e os edicts somam custos adicionais. O orçamento por expansões controla trabalho algorítmico e não equivale a uma garantia de milissegundos em qualquer máquina.

O sistema precisa de medição no servidor real para ajustar quantidade de NPCs e frequência de Think. O custo de colisão depende do BSP, das entidades sólidas e das rotas escolhidas.
