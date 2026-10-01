# Explorador autônomo

`anpc_mapper.sma` gera navegação no mapa carregado, inteiramente por plugins AMXX. O bot ocupa uma vaga de jogador durante a análise e deixa uma vaga adicional disponível para o administrador. Os NPCs usados no jogo continuam sendo entidades sem ocupar vagas.

## Como ele explora

O scanner começa nos spawns de CT/TR e nas posições de jogadores presentes. Faz uma varredura incremental de oito setores horizontais, com alcance de até três vezes o espaçamento. As leituras de hull identificam espaço livre e obstáculos antes da caminhada. A escolha prioriza a quantidade de amostras ainda desconhecidas; alcance, continuidade da direção e visitas desempatam os candidatos. Em corredores inclinados, pode ajustar a direção para a tangente de uma parede estática alta, mantendo o ajuste dentro do setor original. Obstáculos baixos continuam disponíveis para os testes de salto.

Um hull horizontal que encontra uma superfície caminhável (`normal.z >= 0.7`) mantém o candidato longo de exploração. A inclinação observada ajuda a estimar a altura das amostras usadas na escolha; ela não certifica a passagem. Antes de andar, o mapper acompanha o piso em pequenos intervalos XY, obtendo os pés pelo contato de um hull de jogador com o chão. A subida acumulada de uma rampa pode superar a altura de um degrau ou de um salto, desde que cada intervalo continue caminhável. Se o piso termina ou encontra um obstáculo depois de um avanço útil, o alvo pode ser encurtado para o fim desse trecho validado.

Trechos livres recebem alvos mais distantes; um ponto conhecido perto do bot não encurta um alvo desconhecido mais adiante. Em interiores planos já validados, o mapper dispensa âncoras intermediárias periódicas. Fora deles, preserva espaçamento e pontos necessários para representar o terreno. Cada nó novo guarda seu antecessor de descoberta. A verificação física da volta é adiada enquanto existe uma fronteira nova alcançável pelo grafo. Uma ida real inteiramente em cobertura estática plana permite comprovar a caminhada inversa sem repetir o percurso; nos demais casos, a volta mantém sua própria tentativa física. Retornos impossíveis são encerrados sem inventar conexões. As direções de ligações percorridas também ficam registradas.

Ao começar com um `.nav` atual existente, também examina suas arestas por etapas. Para nós sem antecessor, pode agendar uma volta ausente para um nó de ID menor que já tenha ligação de ida. Isso mantém uma árvore sem ciclos e permite verificar retornos mesmo sem journal; uma tentativa já encerrada na memória é preservada. Essa preparação não cria a inversa presumindo que um salto ou uma queda são reversíveis.

As leituras de alcance orientam o planejamento, sem certificar piso, salto ou passagem. O bot mantém testes de caminhada, agachamento, salto, queda e duas direções de escada. Alvos conhecidos são reutilizados quando estão no setor e têm acesso por hull; a conexão só entra no grafo depois da travessia. O índice espacial do provedor evita comparar cada amostra com todos os nós.

Quando a região local já foi analisada, um Dijkstra incremental compara o custo das rotas direcionadas existentes até outras fronteiras, com penalidades de agachamento, escada, salto/queda e visitas, favorecendo destinos com mais direções pendentes. Isso evita escolher um destino próximo em linha reta que exige uma volta longa. O A* do provedor produz a rota de deslocamento. Limites inferiores de pontuação permitem encerrar a seleção antes de visitar todo o grafo quando já existe uma escolha melhor que as restantes. Buscas impossíveis são lembradas até uma alteração relevante na topologia; arestas que falham em movimento recebem também bloqueio temporário na seleção.

A amostragem incremental dos limites do BSP procura outros pisos enquanto o bot caminha, usando o orçamento restante do frame, e acrescenta pontos iniciais para regiões separadas. Sementes dentro de blocos de piso já analisados são dispensadas. Âncoras do grafo sem rota podem iniciar episódios diretamente, sem duplicar nem consumir a fila de 512 sementes; âncoras que não conseguem assentar um jogador são registradas como rejeitadas.

Mudanças de episódio e recuperação podem reposicionar o explorador em uma âncora validada. **Esse reposicionamento não grava uma conexão.** Regiões separadas continuam separadas no `.nav` até existir uma travessia física verificada.

## Blocos adaptativos e redução das repetições

A navegação combina áreas planas e um grafo de âncoras. Uma âncora conhecida começa a classificação de um quadrado de 256 unidades no seu piso. Quando ele contém irregularidades, o bloco dessa âncora é subdividido sob demanda em 128, 64 e 32 unidades. Cada bloco aprovado passa a ser um retângulo do provedor, gravado no `.nav` e usado pelos NPCs. Onde nenhum tamanho passa nos testes, permanecem nós e provas detalhadas de movimento.

A classificação usa amostras de piso com intervalo máximo de 24 unidades e faixas de hull sobrepostas. Exige piso estático quase horizontal, diferença de altura menor que uma unidade e espaço para o hull do jogador. Traces de cima, acima do salto admitido, impedem que plataformas acessíveis e tetos baixos desapareçam dentro de um bloco plano. Água, rampas, degraus e volumes próximos de escadas, triggers, portas, botões, quebráveis ou plataformas móveis permanecem na análise detalhada. Blocos no mesmo XY guardam alturas distintas: conhecer o térreo não resolve automaticamente um andar acima.

Direções inteiramente contidas em blocos analisados deixam de gerar caminhadas de exploração. A consulta percorre todas as células cruzadas, incluindo os lados de uma quina e os dois lados de uma borda da grade; um destino conhecido não basta se o caminho até ele cruza espaço desconhecido. Uma parede estática confirmada acima do salto também pode encerrar um setor quando todo o piso até ela já foi analisado.

Nas bordas irregulares, outra verificação evita caminhar de volta para dentro de uma área conhecida. Ela exige um trecho plano, sem volume sensível na origem, análise do pequeno prefixo ainda fora dos blocos e uma rota direcionada já existente até a âncora de destino. Só dispensa a caminhada se o custo dessa rota não superar `1,75 × (distância até a âncora + metade do espaçamento)`. Sem rota ou com um desvio maior, mantém a tentativa física para descobrir a ligação ou um atalho útil.

No interior conhecido, a posição atual não recebe um nó apenas por atingir o intervalo de espaçamento. Entrada, destino e último ponto alcançado antes de sair para terreno irregular continuam representados. Âncoras comuns próximas são reutilizadas até `0,55 × anpc_scan_spacing`, com prova de hull e apoio entre as coordenadas realmente gravadas; proximidade através de paredes ou buracos não basta. Âncoras precisas reutilizam apenas posições a menos de quatro unidades. O mapper termina fisicamente numa âncora reutilizada antes da próxima análise, evitando deslocar uma decolagem por causa dessa tolerância maior.

Retângulos adjacentes com mesma altura/postura podem ser unidos quando a extensão no outro eixo é igual e a união continua dentro da mesma célula espacial de 256 unidades. A união não preenche formas em L nem buracos. O provedor pode manter retângulos menores contidos num maior; a consulta escolhe o maior que aceita as capacidades. O A* continua usando conexões explícitas, enquanto o NPC dispensa pontos comuns da rota dentro do mesmo retângulo e mantém teste do hull atual. Saltos, quedas, escadas, posições precisas e mudanças de postura interrompem essa simplificação.

Depois de uma caminhada real cujo segmento inteiro está em cobertura plana estática, a prova permite sua inversa, respeitando capacidade de saídas e flags. Saltos, quedas, escadas, volumes sensíveis e piso desconhecido conservam retornos físicos. Atravessar uma região conhecida para alcançar outra continua podendo ser necessário.

Depois que o mapper executa `Use`/`TakeDamage` em um obstáculo, invalida cobertura e retângulos e os reconstrói por etapas. Ao iniciar uma sessão, também refaz as áreas a partir da geometria atual. As máscaras de exploração derivadas ficam fora do journal; o `.nav` conserva áreas para uso em jogo. A comparação com exploração por fronteiras, varredura de cobertura e navmeshes está em [MAPPING_STRATEGY.md](MAPPING_STRATEGY.md).

## Movimento e provas de passagem

`EngFunc_RunPlayerMove` envia comandos de jogador ao motor. O plugin controla direção, velocidade solicitada e botões; colisão, gravidade, degraus, agachamento e contato com escadas são executados pela física do jogo. Não injeta velocidade para fazer um salto nem usa noclip para validar uma rota.

Antes de cada comando, o mapper limpa a trava `fixangle` do fake client, que pode permanecer pendente após o nascimento por ele não receber pacotes de ângulo. Assim, o motor atualiza também a orientação do corpo conforme o olhar, usando a convenção de pitch do modelo de jogador.

O planejamento testa hulls em pé/agachado, altura e inclinação do piso, apoio de toda a corrida de preparação e arcos de salto em etapas. Quando a prova terrestre encontra a face de uma caixa estática perto da origem, procura o topo em cinco profundidades após o contato: 32, 48, 72, 96 e 128 unidades. Isso permite aterrissar numa caixa curta que ficava antes do antigo alvo distante. Cada candidato precisa de piso e hull válidos e de uma travessia real.

Um arco que colide com a face pode tentar recuos de 16, 32, 48, 72, 96 e 128 unidades, verificando o apoio de cada aproximação. O explorador recua, freia e acumula velocidade horizontal na direção da decolagem antes de pressionar salto. Também aguarda a penalidade natural de saltos consecutivos terminar na aproximação apoiada, sem alterar `fuser2` ou injetar velocidade. Limites de tempo continuam ativos.

No salto com saída em pé, o mapper mantém o hull original no primeiro comando e agacha no ar, elevando os pés em 18 unidades sem deslocar o centro. A postura de chegada pode exigir permanecer agachado; onde há espaço, levanta após pousar. O hook ReAPI `RG_PM_Jump` captura posição, postura e velocidade real, corrigindo a referência vertical pelo meio passo de gravidade que o hook já observou. A aterrissagem estável e útil é exigida antes de criar as âncoras precisas de saída/chegada e a ligação. Saltar e voltar ao chão diante de uma caixa elevada não deixa uma ligação nem novos pontos de decolagem fracassada.

Quedas começam com caminhada até a borda real. A gravação só acontece após alcançar o piso seguinte, respeitando `anpc_scan_max_drop`. Dano de queda, `trigger_hurt`, `trigger_push`, teletransporte ou um deslocamento inesperado invalidam a tentativa. O bot protegido contra dano não transforma uma passagem perigosa em rota segura.

Trechos terrestres fora de áreas certificadas têm pontos intermediários, verificação de hull e amostras de chão para evitar conexões que cortem paredes, quinas ou buracos. Dentro das áreas, a prova de apoio pode ser reutilizada com o teste do hull atual. As âncoras de saída e chegada de movimentos aéreos usam tolerância menor.

O planejamento e a gravação usam o hull inteiro para medir apoio, evitando confundir o piso sob o centro com a altura dos pés necessária numa inclinação. O intervalo de amostragem é `min(16, sv_stepsize × 0,75)` unidades XY, com mínimo de 0,25; na configuração usual de 18, resulta em 13,5. A altura de degrau limita cada intervalo, sem limitar a subida total. Uma crista pode exigir elevação parcial do corpo: os testes consultam a folga real nas duas extremidades e verificam a passagem elevada, incluindo os trechos verticais. Um trace de busca de piso pode começar no teto e sair para espaço livre antes de tocar o chão; os hulls que verificam deslocamento continuam exigindo passagem livre.

Subir 14 unidades deixa de gerar um nó por si só. O espaçamento XY mantém pontos intermediários; mudanças importantes na normal do chão preservam uma âncora no último ponto alcançado antes da curva. Isso reduz nós redundantes em rampas uniformes e impede que uma ligação corte uma crista. A prova de um ponto já gravado no frame não é repetida ao concluir o movimento. Escadas continuam recebendo âncoras por mudança de altura.

Em caminhada, o pitch do olhar acompanha a diferença de altura até o destino, limitado a ±45 graus. Câmera e laser usam esses ângulos reais do scout.

Escadas são localizadas por volumes reais de `func_ladder`. O bot precisa entrar em contato com a escada usando a física de jogador. Portas comuns sem `targetname` e quebráveis vulneráveis recebem `Use`/`TakeDamage` originais, com distância, intervalo e número de tentativas limitados. Isso pode abrir portas ou destruir caixas do mapa durante a análise.

## Comandos

Todos exigem `ADMIN_RCON`; o console do servidor também pode executá-los. `watch`, `blocks` e `seed` sem coordenadas exigem um cliente.

| Comando | Ação |
| --- | --- |
| `anpc_scan start new` | Novo grafo em memória; ignora a memória de exploração anterior |
| `anpc_scan start` | Continua o grafo atual e usa memória correspondente, se existir |
| `anpc_scan status` | Estado, posição, nós, conexões, movimentos, rejeições, orçamento e contadores de exploração/deslocamento |
| `anpc_scan pause` | Suspende exploração, mantendo o bot e a edição exclusiva |
| `anpc_scan resume` | Retoma de uma âncora verificada; a tentativa interrompida pode ser refeita |
| `anpc_scan save` | Checkpoint incremental, seguido de continuação; mantém a pausa se já estava pausado |
| `anpc_scan stop` | Salva e encerra; aguarde `active=0` |
| `anpc_scan seed` | Acrescenta os pés do administrador à fila de regiões a analisar |
| `anpc_scan seed x y z` | Acrescenta coordenadas de pés, também pelo console/RCON; chão e hull serão validados |
| `anpc_scan watch 1` / `watch 0` | Liga/desliga a câmera do explorador para esse administrador |
| `anpc_scan blocks 1` / `blocks 0` | Liga/desliga quadrados azuis de piso analisado perto do scout, apenas para esse administrador |

O modo `watch` acompanha a posição dos olhos e os ângulos completos do scout, inclusive ao virar, agachar e subir/descer escadas. O corpo do scout fica oculto apenas para quem está usando essa câmera, para não cobrir a visão com a própria cabeça. `watch 0` ou o encerramento do scan devolvem a visão ao administrador; a câmera e seu hook de visibilidade são liberados quando o último observador sai. A câmera não acrescenta traces ao planejamento.

Os estados numéricos são `0` desligado, `1` preparando episódio, `2` escolhendo fronteira, `3` aguardando/seguindo rota, `4` analisando geometria, `5` movendo, `6` pausado, `7` salvando e `8` candidatos esgotados.

Use `anpc_nav_show 1` para desenhar os pontos e os contornos azuis de até oito retângulos do provedor associados aos nós selecionados. A edição manual e a criação de NPCs ficam bloqueadas enquanto o scanner mantém a edição exclusiva. O gravador manual ativo é encerrado ao começar a análise.

Com `anpc_scan_beam 1` (padrão), um laser verde sai dos olhos do fake client e acompanha seu ângulo real de visão, incluindo a inclinação nas escadas. A linha termina no primeiro sólido/jogador encontrado ou em 1.024 unidades. É visível para clientes próximos, inclusive usando `watch`, e usa um trace próprio, até dez atualizações por segundo sob o orçamento do mapper. `anpc_scan_beam 0` desliga o efeito. O laser representa o olhar do bot, não todas as direções da varredura geométrica.

`blocks 1` desenha uma seleção de até 12 blocos próximos, no piso atual do scout, cerca de duas vezes por segundo por observador e sob o orçamento disponível. Não acrescenta traces e fica desligado por padrão. Azul indica um bloco que passou na classificação geométrica desta sessão, sem significar cobertura integral do BSP ou passagem física em todos os seus pontos.

O scout é identificado pela vaga e pelo `userid` da conexão, com confirmação de private data e estado de bot. O mapper preserva os campos `iuser*` usados pela física/GameDLL. Toda linha `Mapper ended` informa `reason` e a etapa em que a sessão terminou. Quando a identidade deixa de ser válida, o log também mostra a vaga, os userids esperado/atual, conexão, flag de fake client e private data antes de liberar a sessão.

## Checkpoints

Os arquivos ficam em `addons/amxmodx/configs/advanced_npc/maps/`:

| Arquivo | Conteúdo |
| --- | --- |
| `<mapa>.nav` | Nós, áreas `A` e conexões no formato atual `ANPC_NAV 2` |
| `<mapa>.scan` | Memória `ANPC_SCAN 2`: direções/visitas, antecessores, retornos pendentes, âncoras rejeitadas, sementes e amostragem |
| `<mapa>.scan.txt` | Contadores, perfil físico, limites atingidos e movimentos não representados |
| `*.bak` | Versão anterior do respectivo arquivo |
| `*.tmp` | Gravação em andamento; um arquivo incompleto nunca é promovido |

A escrita congela a exploração e distribui registros por frames. O commit de cada arquivo usa renomeação com backup. A memória inclui MD5 do BSP, do `.nav` e uma assinatura dos parâmetros físicos e da política de exploração. Se houver interrupção entre os commits, a memória que não corresponde ao novo `.nav` é descartada; o grafo permanece utilizável e as direções são examinadas novamente.

O formato de memória permanece `ANPC_SCAN 2`; memórias em outro formato são descartadas. O provedor aceita somente `ANPC_NAV 2`, descrito em [NAVIGATION.md](NAVIGATION.md). Gere um scan novo ou reimporte grafos antigos antes de usar esta revisão. Continuar um grafo atual preserva seus IDs; para eliminar a geração densa de um scan anterior, use `anpc_scan start new`. Os antecessores têm IDs menores que seus filhos, impedindo ciclos na árvore de descoberta. Retornos interrompidos por pausa/checkpoint continuam pendentes.

A política atual tem a assinatura `areas-landings-1`. Um `.scan` com outra assinatura é descartado mesmo no formato 2; o grafo atual permanece e a exploração é reanalisada. Checkpoints desta revisão podem ser retomados normalmente. As áreas e a cobertura da sessão são reconstruídas a partir do mapa e das âncoras; durante o checkpoint, retângulos atuais são gravados junto do grafo.

Pausa, checkpoint ou encerramento durante uma tentativa devolvem a direção interrompida à análise. Um desligamento inesperado preserva o último checkpoint já confirmado. O comando `stop` termina a gravação antes de remover o bot; evite desligar o mapa enquanto `active=1`.

## Configuração e custo

| Cvar | Padrão | Efeito |
| --- | --- | --- |
| `anpc_scan_auto` | `0` | Inicia automaticamente apenas se não houver grafo |
| `anpc_scan_beam` | `1` | Mostra o laser de direção do olhar durante a sessão; 0/1 |
| `anpc_scan_spacing` | `96` | Espaçamento de exploração; 48 a 160 |
| `anpc_scan_speed` | `300` | Limite de velocidade do explorador; 100 a 320 |
| `anpc_scan_gravity` | `0.7` | Multiplicador de gravidade; 0,3 a 1,5 |
| `anpc_scan_max_drop` | `160` | Limite de descida; 18 a 256 |
| `anpc_scan_survey` | `1` | Procura pisos adicionais nos limites do BSP |
| `anpc_scan_traces` | `24` | Limite de traces de análise por frame; 16 a 64 |
| `anpc_scan_budget_ms` | `1.0` | Orçamento cooperativo de trabalho por frame; 0,2 a 4 |
| `anpc_scan_save_records` | `32` | Registros gravados por frame; 4 a 128 |
| `anpc_scan_checkpoint` | `60` | Intervalo em segundos; 15 a 600 |
| `anpc_scan_restart` | `0` | Restart opcional após encerrar |
| `anpc_scan_active` | Estado | Indica se o scanner mantém uma sessão; controlado pelo plugin |

Espaçamento, velocidade, gravidade e limite de queda são capturados no início da sessão. Alterá-los na configuração afeta a próxima sessão. Mudanças relevantes na física global durante o scan fazem o plugin salvar os segmentos já provados e encerrar, para evitar misturar condições de teste.

O movimento recebe serviço a aproximadamente 50 Hz, com um comando de até 50 ms por execução. Trabalho geométrico, seleção e escrita respeitam limites por frame. O ciclo aceita até 96 etapas leves por frame, sempre sob o orçamento cooperativo. Cada etapa de Dijkstra expande até oito nós; a classificação divide testes de volumes, faixas de hull e amostras de chão entre chamadas. O trabalho em segundo plano aceita até oito etapas de blocos e oito células de amostragem, com prioridade para os blocos conhecidos. A preparação de uma semente e a consulta de rota interna aguardam outros frames em vez de repetir sua espera no mesmo frame. O A* conserva seu orçamento próprio de `anpc_nav_expansions`. As chamadas internas da física do motor não entram no contador de traces do mapper.

O orçamento em milissegundos é cooperativo: uma chamada nativa, hashing de arquivo ou renomeação não pode ser interrompida no meio. Não representa uma medição ou garantia de FPS. A árvore de descoberta e os estados de retorno/rejeição usam 48 KiB de arrays Pawn; a cobertura e a seleção acrescentam cerca de 0,9 MiB. Permanecem 0,125 MiB reservados para heap/stack, além do provedor e da vaga do bot.

A prova de terreno processa um intervalo por etapa e reserva até 14 traces para tentar as duas posturas. Sem essa reserva, aguarda o próximo frame. Rampas uniformes normalmente precisam apenas da busca de apoio e do hull entre os dois apoios; buscas de teto/piso e folga adicional são usadas quando necessário. A caminhada continua atendida antes desse trabalho.

O status e o relatório mostram `sweeps` (varreduras locais), `known-direction skips` (saídas já ligadas), `long walks` (tentativas terrestres acima de 1,5 vezes o espaçamento) e `deferred returns` (tentativas de volta adiadas). As distâncias separam exploração de deslocamento/retorno, em unidades do mapa; reposicionamentos não entram nessas distâncias. São contadores da sessão, não porcentagens de cobertura nem medição de ganho de velocidade.

Há também contadores de blocos abertos/detalhados, setores dispensados pela geometria, tentativas interiores dispensadas e destinos selecionados por custo. `Navigation areas` informa retângulos atuais; `suppressed node samples` conta amostras periódicas dispensadas, podendo contar vários frames do mesmo trecho; `symmetric floor returns` conta inversas comprovadas pela área plana e `local landings` conta candidatos de topo validados. Esses valores não são uma contagem de nós removidos. `pending-estimate` usa resultados já consultados, para que um comando de status não refaça a geometria do mapa inteiro; pode superestimar o trabalho que os próximos testes de cobertura vão retirar.

Os limites atuais são 4.096 nós, 4.096 áreas, oito saídas direcionadas por nó, 512 pontos iniciais, 128 volumes de escada, 256 volumes sensíveis e 16.384 registros de blocos. Ao atingir a capacidade de nós, o plugin salva um grafo parcial e encerra. Esgotar registros de blocos/áreas mantém a exploração detalhada; exceder o cache de volumes sensíveis/escadas desativa a classificação de blocos. O relatório identifica esses limites e as tentativas rejeitadas.

## Cobertura e teste manual

O scan é uma exploração heurística com prova física. Esgotar candidatos significa terminar as tentativas disponíveis, sem certificar que cada ponto de qualquer BSP foi encontrado. Passagens menores que a resolução escolhida, geometrias incomuns e regiões dependentes de scripts podem exigir sementes adicionais ou edição manual.

Elevadores, botões encadeados, plataformas móveis, água profunda, teletransportes, cooperação entre jogadores e saltos além da física escolhida não ganham conexões inventadas. O mapa é analisado por etapas e o relatório registra as limitações observadas. O seguidor de NPC usa o perfil de cada tipo e recalcula saltos: um grafo criado para um explorador não garante execução por um NPC mais lento, maior ou com outra gravidade.

O scanner é independente de `zpn_main.sma`. Use uma sessão de manutenção e evite que outros plugins infectem, movam, congelem ou removam o fake client. O próprio mapper suprime as verificações/restarts normais do CS durante sua sessão e mantém o bot protegido; regras próprias de outros plugins continuam sendo responsabilidade da configuração do servidor.

A validação de movimento e cobertura no HLDS será feita manualmente pelo usuário. Consulte `TESTING.md` para os cenários sugeridos.
