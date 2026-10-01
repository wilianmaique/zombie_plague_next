# Revisão do scan, movimento e armazenamento — 1.5

Esta revisão retira amostras redundantes dos interiores certificados, usa posições reais e múltiplas entradas/saídas para perseguição, conserva movimento durante o planejamento e verifica os desvios entre NPCs. Mantém as correções anteriores de alinhamento, cobertura e estruturas esparsas descritas abaixo. Compilação e execução no HLDS permanecem manuais, conforme as instruções do projeto.

A imagem desta solicitação mostra 551 amostras e `areas 8/85`: oito áreas desenhadas de 85 existentes. Beams comuns dentro dos retângulos eram redundantes para representar o chão livre. A causa da perseguição interrompida foi investigada nas fontes; a imagem sozinha não confirma o comportamento físico de uma porta ou de um NPC.

## Compactação em checkpoints e âncoras nas bordas

O finalizador anterior protegia pontos comuns de raio 8 e ambos os extremos de toda conexão que saísse de uma área. Esses extremos podiam continuar no interior; a compactação ainda só ocorria ao esgotar o scan. Ocultar pontos no debug não resolvia o grafo salvo.

Agora cada checkpoint, `save`, `stop` e conclusão congela toda a equipe antes de compactar. A conexão WALK interna é representada pela área. Uma conexão WALK entre regiões conserva a direção e passa a usar a interseção do trajeto com as bordas, com Z calculado pelo plano de apoio. Retira também raio 8 comum e portais absorvidos pela união de retângulos. Portais compartilhados exigem borda de pelo menos 16 unidades e apoio contínuo; contato por quina não conecta regiões.

Há exceções necessárias: saltos/quedas mantêm decolagem, chegada e referência de velocidade; escadas mantêm contatos reais; uma transição sem saída planar não recebe um portal interior inventado. Nós desabilitados também são conservados. Em um scan incompleto, fronteiras ainda úteis e posições necessárias à retomada têm proteção explícita; essa proteção termina junto com a exploração. Retângulos descrevem caminhada livre, sem representar sozinhos essas ações ou trabalho desconhecido.

O mapper remapeia journal, antecessores, nós atuais e proprietários de blocos com os scouts congelados. Cancela rotas/reservas, invalida caches de cobertura/inacessibilidade e reinicia seleções a partir dos IDs novos. O caso sem nós tem uma inicialização única, evitando repetir a limpeza do cursor. Novas âncoras de borda podem receber exploração pendente. Se uma reserva conservadora de substitutos ultrapassa a capacidade, preserva o grafo original completo: esse caso é informado, sem apagar uma travessia já provada.

O debug omite beams WALK totalmente cobertos desde que a área é certificada. A retirada real dos pontos ocorre na próxima gravação congelada; o padrão de checkpoint é 60 segundos. Assim, o desenho e os dados usados pela exploração têm funções distintas e o journal permanece consistente.

## Perseguição entre posições e execução até o alvo

A seleção antiga podia usar uma única âncora próxima desconectada, ignorar outra entrada útil e rejeitar o jogador ao acabar a lista de nós. Requisições também apagavam o caminho anterior. Um destino móvel podia provocar paradas durante buscas e manter um salto sempre atrás de outro pedido pendente.

`anpc_nav_request_to` valida até oito âncoras de cada extremo, examinando até dezesseis candidatos da área/índice espacial a até 512 unidades. Prova origem→âncora e âncora→destino, respeitando agachamento, apoio e escada real. A fase divide até quatro candidatos por frame entre as buscas. A* começa em todas as origens aceitas, inclui os conectores e só termina quando a fila não pode melhorar o custo completo. A garantia de menor custo vale para esse grafo e candidatos validados, sem prometer o menor trajeto geométrico de todo o mapa.

O caminho publicado continua legível durante a substituição pendente. Mudança de área ou deslocamento de pelo menos 48 unidades agenda outra busca pelo intervalo configurado; um pedido em andamento não é cancelado a cada movimento. `path_revision` identifica a publicação atômica. O seguidor tenta se conectar a pontos WALK adiante a partir dos pés atuais, sem dispensar uma decolagem ou escada. Cada resultado recém-publicado recebe movimento antes de outro pedido, evitando adiar uma ação aérea indefinidamente.

Chegar à última âncora percorre o conector até o jogador após nova prova de hull/apoio, inclusive quando ele fica a mais de 192 unidades em um grafo espaçado. Uma porta fechada recebe tratamento do obstáculo e espera limitada, seguido de renovação da rota. O alvo não é rejeitado apenas por terminar o caminho. A mesma escada admite aproximação final com volume comum e hull livre. Durante um pulo do jogador, a perseguição conserva seu último apoio; ao pousar atualiza o destino, e escadas conservam a altura real.

## Desvio entre NPCs e obstáculos reais

O núcleo examina NPCs à frente na mesma faixa de altura, antecipa sua posição por 0,15 s e mantém o lado de desvio por 0,4 s. Passadas laterais/recuos exigem chão, hull incluindo atores e `WalkMove`; não há deslocamento de navegação por alteração da origem. Em passagem estreita, o serial maior cede por 0,15 s e essa espera interrompe também o fallback de agachamento/desvio. Atalhos pela área mantêm a postura necessária; uma passagem baixa pode ser tentada agachada pelo perfil permitido.

Colisões de jogadores/NPCs não bloqueiam a topologia para os demais. Bloqueios do mundo reconhecem também `FM_NULLENT` (-1), permitindo recuperação e indisponibilidade temporária da aresta correta. Saltos mantêm aproximação precisa, solução de arco, gravidade e colisão já existentes; iniciar nova ação aérea ou entrada em escada aguarda a publicação da substituição.

## Etapa 1: alinhamento e falta de progresso

### Achados

- A conclusão do movimento aceitava até 12 unidades em XY e 12 de altura. O alinhamento usava distância 3D de 12: uma posição podia ser aceita como chegada e imediatamente solicitar outro alinhamento.
- Durante alinhamento, a gravação periódica ainda podia reutilizar/criar outra âncora e substituir `gCurrent`. A rotina de início do movimento renovava o prazo, permitindo repetir esse ciclo sem resolver a tentativa original.
- No NPC do jogo, a janela de aproximação ao destino podia reiniciar quando o alvo/waypoint mudava, escondendo uma posição fisicamente imóvel.

### Aplicado

`scan_reached` unifica a regra de parada, sucesso e alinhamento. `gAligning` identifica essa fase; seu destino é fixado em `gGoalNode`, e ela não cria amostras intermediárias. O prazo pertence à tentativa original; um alinhamento inicial de semente recebe seu próprio prazo de três segundos. Ao terminar, usa o ID pretendido e segue o trabalho; ao falhar, executa a recuperação existente, com tentativas limitadas e sem inventar ligações pelo reposicionamento.

No core, uma janela de posição conserva a origem física entre mudanças de rota. Se não houve deslocamento de pelo menos 16 unidades após 1,8 segundo acumulado de tentativas, aciona a recuperação existente. Cada consulta soma no máximo 0,2 segundo, para que uma longa espera por busca/ataque não conte integralmente como movimento frustrado. Limpar o alvo reinicia essa janela. A janela de aproximação ao waypoint continua ativa para reconhecer desvios que não ajudam a alcançar o destino.

Isso remove os ciclos lógicos identificados, mas não comprova que toda imobilidade possível do motor ou de plugins externos foi eliminada.

## Etapa 2: usar a cobertura durante a exploração

### Achados

O projeto já certificava retângulos de piso e dispensava amostras no interior, mas a seleção de fronteiras percorria apenas arestas físicas explícitas. A caminhada implícita nas áreas dependia das associações construídas ao finalizar. Assim, cobertura suficiente para dispensar pontos ainda podia parecer desconectada para o explorador.

Viagens sobre rotas conhecidas voltavam a executar gravação periódica. Além disso, buscar somente a âncora mais próxima fazia um ponto atrás de uma parede esconder outros candidatos acessíveis, aumentando a criação de pontos novos.

### Aplicado

- O provedor enumera arestas físicas e vizinhos da mesma área durante a edição. Usa os buckets espaciais por etapas; as listas finais de associação continuam atendendo o grafo pronto.
- O Dijkstra do mapper consome esse mesmo contrato, conserva o cursor e executa até oito operações de enumeração por etapa. Uma expansão densa não percorre toda a sala em uma chamada.
- O fim de uma busca sem candidatos é reavaliado quando a cobertura mudou. Novos certificados, sua invalidação e alterações de flags atualizam também a geração do histórico de inacessibilidade: uma fronteira antes sem rota pode voltar a ser considerada sem criar nós. Descobertas dos parceiros não reiniciam a busca continuamente.
- Viagens em rota conhecida não criam amostras terrestres periódicas. As verificações de contato, salto, queda e perigo continuam sendo atendidas.
- O mapper pode dispensar até oito waypoints intermediários quando há apoio certificado contínuo e passagem do hull. Interrompe o atalho em escadas, links especiais, mudança de postura, ponto preciso ou portal.
- A nova consulta `anpc_nav_near_candidates` entrega até oito candidatos geométricos ordenados. O mapper faz até quatro provas físicas, verificando o trajeto da posição realmente alcançada até a âncora e a ligação que será armazenada desde a origem.

### Densidade e limites da simplificação

Não se aumentou o espaçamento indiscriminadamente: isso esconderia saídas estreitas e mudanças de piso. Mantêm-se blocos adaptativos de 256/128/64/32, camadas de altura independentes, piso estático e faixas de hull. Paredes, buracos, triggers, portas, escadas e piso irregular continuam exigindo provas locais.

A sessão de edição cancela buscas anteriores e mantém a enumeração espacial desde o início, inclusive com grafo carregado. Ao voltar às associações finais, cancela os pedidos da sessão. Assim, um cursor pendente não muda de interpretação entre lista de associação e buckets após a primeira área acrescentada.

Enquanto os scouts trabalham, amostras existentes conservam IDs. A compactação descrita acima ocorre nos checkpoints com a equipe congelada, remapeando os estados antes de retomar. A área continua utilizável imediatamente durante a exploração; fronteiras pendentes mantêm seus pontos até serem resolvidas.

Pontos próximos podem ser necessários em decolagens, chegadas, cristas, mudança de postura, escadas ou lados distintos de um obstáculo. Proximidade visual não autoriza unir esses pontos.

## Etapa 3: escolher `Array:` por padrão de acesso

| Dados | Estrutura atual | Razão |
| --- | --- | --- |
| Blocos de cobertura | `Array:gBlock`, registro de 19 células | Cresce conforme as subdivisões; elimina a tabela reservada de 32.768 registros |
| Sementes | `Array:gSeeds`, registro de 6 células | Elimina 512 entradas como teto; hash espacial faz deduplicação local |
| Escadas do mapper | `Array:gLadder`, registro de 7 células | Guarda as entidades reais sem truncar em 128 |
| Volumes sensíveis | `Array:gVolumes`, registro de 8 células | Elimina o teto de 256 que podia desativar toda a classificação |
| Arestas físicas | `Array:gNodeLinks[node]`, registro de 7 células | Sem a restrição de oito saídas; criado sob demanda, sem duplicar destinos |
| Rotas | `Array:` existente | Comprimento varia por pedido; continua limitado pelo grafo |
| Posições/flags/índice de nós e áreas | Arrays Pawn densos | IDs estáveis, acesso frequente e direto |
| Heaps, custos, pais e stamps de A*/Dijkstra | Arrays Pawn densos | Atualizações frequentes por ID; passar cada acesso por native acrescentaria custo |
| Estados de atores, tipos, scouts e rotas abertas | Arrays Pawn densos | Limites pequenos ligados ao motor e ao escalonador |
| Heads dos índices espaciais | Arrays Pawn densos | Tamanho da hash, sem reservar um registro completo por entrada possível |

Registros são transferidos com `ArrayGetArray`/`ArraySetArray`; `ArrayGetCell`/`ArraySetCell` atendem campos isolados. `ArrayCreate` recebe o tamanho exato do registro e uma reserva inicial pequena; itens só passam a existir após push. Reset e desligamento liberam os handles apropriados; compactação transfere a propriedade das listas e remapeia seus destinos. O índice de sementes é reconstruído ao ler o journal.

A análise dos oito setores de uma âncora reutiliza um único registro do bloco, em vez de repetir a busca e a cópia para cada direção. A projeção de cantos no desenho também usa o registro já lido.

Com células de quatro bytes, a tabela anterior de blocos reservava **2,375 MiB** e as tabelas anteriores de arestas, **0,875 MiB**. Foram substituídas por registros alocados conforme necessidade, reservas e metadados das arrays. Os handles das arestas e o novo índice de sementes também ocupam memória. Esses valores são cálculos das declarações, não medição de memória/FPS no HLDS; um grafo muito denso pode consumir mais memória dinâmica que antes.

Permanecem 4.096 nós, 4.096 áreas, oito scouts, quatro buscas A* e os limites de atores/tipos. Uma lista de arestas únicas pode ter no máximo outros nós existentes como destinos. Memória disponível continua sendo um limite real. Fazer também o grafo inteiro crescer exigiria redesenhar heaps, stamps, filas, remapeamento e índices por job, além de estabelecer novos orçamentos. A conversão parcial para `Array:` sem esse trabalho produziria limites ocultos ou acesso mais caro; não foi feita.

## Etapa 4: armazenamento e JSON

`.nav` é a extensão de um **formato textual próprio**, não uma indicação de armazenamento binário. O grafo é carregado por mapa; não se lê o arquivo a cada passo do NPC. Durante o jogo, custo principal depende de busca, consultas espaciais e colisão, não da extensão usada em disco.

O AMXX oferece [json_parse](https://www.amxmodx.org/api/json/json_parse), que lê texto/arquivo e retorna um handle a liberar. Usar a API de árvore exigiria parse e acesso a objetos/campos, além da estrutura do grafo usada pelo planejador. **Não há benchmark que justifique declarar JSON mais rápido.** A decisão é manter leitura por registros e escrita incremental do mapper. JSON continua útil para o relatório externo do importador e o resumo do verificador.

A revisão usa somente `ANPC_NAV 4`:

```text
ANPC_NAV 4 "nome_do_mapa" tamanho_do_bsp md5_do_bsp
N id x y z raio flags
A id min_x min_y max_x max_y z_em_min_xy normal_x normal_y normal_z flags
E origem destino flags vx vy vz
END quantidade_de_nos quantidade_de_areas quantidade_de_arestas
```

O rodapé obrigatório rejeita truncamento tanto dentro de uma linha quanto entre registros completos. As contagens precisam corresponder ao conteúdo. Registros depois do rodapé são recusados; comentários e linhas vazias continuam permitidos. Cada escrita e o flush são conferidos antes do commit do temporário com backup. O gravador do provedor preserva seis decimais de coordenadas, planos e velocidades.

O importador YaPB produz o mesmo formato. `check_nav_file.py` permite validação estrutural independente, com conferência opcional do nome/tamanho/MD5 do BSP. Arquivos anteriores precisam ser gerados novamente ou reimportados; não foi acrescentada compatibilidade com formatos antigos. A política do journal é `boundary-regions-team-3`; sua estrutura permanece `ANPC_SCAN 2`.

## Técnicas avaliadas

| Técnica | Decisão nesta revisão |
| --- | --- |
| Cobertura adaptativa com camadas de altura | Mantida; aproveita os traces do motor e concentra detalhe onde necessário |
| Fronteiras pontuadas por utilidade e custo direcionado | Mantida e conectada às áreas disponíveis durante o scan |
| Conectividade implícita por área convexa | Aplicada durante edição, sem materializar todas as arestas da sala |
| Simplificação de rota com apoio e hull | Aplicada também ao mapper, preservando transições |
| Índice espacial para deduplicar sementes | Aplicado junto da fila dinâmica |
| Navmesh completa no estilo Recast | Não incorporada: exige outro processamento de geometria/polígonos e integração com movimentos/scripts GoldSrc; não é uma native AMXX/ReAPI disponível para substituir o mapper |
| Parse completo do BSP para aprovar o chão | Não usado como certificado único: ignora entidades e alterações do mundo; BSP continua fonte de limites e ferramenta de diagnóstico offline |
| Compactar interiores durante o scan | Aplicado em checkpoints congelados, com remapeamento dos estados e proteção das fronteiras/ações físicas necessárias |
| `Array:` em todas as variáveis | Recusado: limitações e padrões de acesso distintos; arrays densos continuam apropriados ao planejador |
| JSON como otimização presumida | Recusado sem medição; integridade e escrita incremental foram melhoradas no `.nav` |
| Navegação hierárquica entre clusters maiores | Possível evolução se profiling mostrar busca dominante; falta benchmark que justifique outro nível de cache e invalidação agora |
| Índice espacial de volumes e escadas | Possível se mapas com muitas entidades mostrarem custo dominante; hoje a classificação testa um volume por etapa. Um índice teria de representar caixas em várias células e atualizar volumes móveis, sem perder a exclusão conservadora |

As referências de cobertura, fronteiras, Recast e planejamento estão em [MAPPING_STRATEGY.md](MAPPING_STRATEGY.md); contratos AMXX/ReAPI conferidos estão em [REFERENCES.md](REFERENCES.md).

## Arquivos e validação

Fontes do repositório: `anpc_core.sma`, `anpc_mapper.sma`, `anpc_navigation.sma`, importador, verificadores, testes e documentação. As includes foram editadas diretamente em `ANPC_INCLUDE_DIR`, conforme `LOCAL.md`, e não são cópias no Git:

```text
advanced_npc_limits.inc       advanced_npc_navigation.inc
mapper_coverage.inc           mapper_frontiers.inc
mapper_motion.inc             mapper_storage.inc
mapper_team.inc               mapper_world.inc
movement.inc                  perception.inc
navigation_areas.inc          navigation_graph.inc
navigation_portals.inc
```

Passaram **93 testes Python** e a conferência estrutural de **27 fontes Pawn**. Os 33 novos testes interpretam controle de fluxo de funções selecionadas das fontes instaladas, com doubles determinísticos; a busca é comparada com Dijkstra independente em trinta grafos dirigidos. Exercitam compactação, capacidade, remapeamento, publicação, conectores finais, portas, pulos/escadas e substituição sem dispensar decolagem. Os demais verificam condições, geometria e integridade de arquivos. Não houve compilação, execução de bytecode AMXX/HLDS ou medição de aceleração, cobertura final, memória real e FPS. Os cenários e comandos manuais estão em [TESTING.md](TESTING.md).

Para instalar: recompile manualmente os seis plugins com as includes atuais, carregue os binários juntos e use `anpc_scan start new` para comparar sem amostras antigas. Confirme primeiro o caso de imobilidade das imagens; depois examine passagens agachadas, saltos, escadas, buracos, pisos sobrepostos, pausas e compactação. Compare um e quatro scouts sob o mesmo orçamento e BSP, registrando contadores e custo do servidor.
