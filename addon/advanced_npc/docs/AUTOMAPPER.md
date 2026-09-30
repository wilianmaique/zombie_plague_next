# Explorador autônomo

`anpc_mapper.sma` gera navegação no mapa carregado, inteiramente por plugins AMXX. O bot ocupa uma vaga de jogador durante a análise e deixa uma vaga adicional disponível para o administrador. Os NPCs usados no jogo continuam sendo entidades sem ocupar vagas.

## Como ele explora

O scanner começa nos spawns de CT/TR e nas posições de jogadores presentes. Mantém uma memória de direções tentadas e de visitas em cada nó, examina oito direções horizontais e duas direções de escada e alterna o comprimento das tentativas perto de obstáculos. Usa o índice espacial do provedor para reutilizar pontos, evitando uma comparação com todos os nós em cada passo.

Quando a região local já foi analisada, procura outra fronteira no grafo e usa A* para chegar até ela. Buscas impossíveis são lembradas até uma alteração relevante na topologia. A amostragem incremental dos limites do BSP procura outros pisos e acrescenta pontos iniciais para regiões separadas.

Mudanças de episódio e recuperação podem reposicionar o explorador em uma âncora validada. **Esse reposicionamento não grava uma conexão.** Regiões separadas continuam separadas no `.nav` até existir uma travessia física verificada.

## Movimento e provas de passagem

`EngFunc_RunPlayerMove` envia comandos de jogador ao motor. O plugin controla direção, velocidade solicitada e botões; colisão, gravidade, degraus, agachamento e contato com escadas são executados pela física do jogo. Não injeta velocidade para fazer um salto nem usa noclip para validar uma rota.

O planejamento testa hulls em pé/agachado, altura e inclinação do piso, espaço para corrida de preparação e arcos de salto em etapas. Em salto, o hook ReAPI `RG_PM_Jump` captura a posição de saída e a velocidade efetivamente produzida pela física. Depois da aterrissagem estável, o grafo recebe a ligação direcionada e essa velocidade. Saltos agachados são tentados para obter a folga adicional do hull de jogador.

Quedas começam com caminhada até a borda real. A gravação só acontece após alcançar o piso seguinte, respeitando `anpc_scan_max_drop`. Dano de queda, `trigger_hurt`, `trigger_push`, teletransporte ou um deslocamento inesperado invalidam a tentativa. O bot protegido contra dano não transforma uma passagem perigosa em rota segura.

Trechos terrestres têm pontos intermediários, verificação de hull e amostras de chão para evitar conexões que cortem paredes, quinas ou buracos. As âncoras de saída e chegada de movimentos aéreos usam tolerância menor.

Escadas são localizadas por volumes reais de `func_ladder`. O bot precisa entrar em contato com a escada usando a física de jogador. Portas comuns sem `targetname` e quebráveis vulneráveis recebem `Use`/`TakeDamage` originais, com distância, intervalo e número de tentativas limitados. Isso pode abrir portas ou destruir caixas do mapa durante a análise.

## Comandos

Todos exigem `ADMIN_RCON`; o console do servidor também pode executá-los. `watch` e `seed` sem coordenadas exigem um cliente.

| Comando | Ação |
| --- | --- |
| `anpc_scan start new` | Novo grafo em memória; ignora a memória de exploração anterior |
| `anpc_scan start` | Continua o grafo atual e usa memória correspondente, se existir |
| `anpc_scan status` | Estado, posição do bot, nós, conexões, movimentos verificados, rejeições e orçamento |
| `anpc_scan pause` | Suspende exploração, mantendo o bot e a edição exclusiva |
| `anpc_scan resume` | Retoma de uma âncora verificada; a tentativa interrompida pode ser refeita |
| `anpc_scan save` | Checkpoint incremental, seguido de continuação; mantém a pausa se já estava pausado |
| `anpc_scan stop` | Salva e encerra; aguarde `active=0` |
| `anpc_scan seed` | Acrescenta os pés do administrador à fila de regiões a analisar |
| `anpc_scan seed x y z` | Acrescenta coordenadas de pés, também pelo console/RCON; chão e hull serão validados |
| `anpc_scan watch 1` / `watch 0` | Liga/desliga a câmera do explorador para esse administrador |

Os estados numéricos são `0` desligado, `1` preparando episódio, `2` escolhendo fronteira, `3` aguardando/seguindo rota, `4` analisando geometria, `5` movendo, `6` pausado, `7` salvando e `8` candidatos esgotados.

Use `anpc_nav_show 1` para desenhar os pontos próximos. A edição manual e a criação de NPCs ficam bloqueadas enquanto o scanner mantém a edição exclusiva. O gravador manual ativo é encerrado ao começar a análise.

O scout é identificado pela vaga e pelo `userid` da conexão, com confirmação de private data e estado de bot. O mapper preserva os campos `iuser*` usados pela física/GameDLL. Toda linha `Mapper ended` informa `reason` e a etapa em que a sessão terminou. Quando a identidade deixa de ser válida, o log também mostra a vaga, os userids esperado/atual, conexão, flag de fake client e private data antes de liberar a sessão.

## Checkpoints

Os arquivos ficam em `addons/amxmodx/configs/advanced_npc/maps/`:

| Arquivo | Conteúdo |
| --- | --- |
| `<mapa>.nav` | Grafo no formato atual `ANPC_NAV 1`, pronto para o provedor |
| `<mapa>.scan` | Direções/visitas, fila de pontos iniciais e progresso da amostragem |
| `<mapa>.scan.txt` | Contadores, perfil físico, limites atingidos e movimentos não representados |
| `*.bak` | Versão anterior do respectivo arquivo |
| `*.tmp` | Gravação em andamento; um arquivo incompleto nunca é promovido |

A escrita congela a exploração e distribui registros por frames. O commit de cada arquivo usa renomeação com backup. A memória inclui MD5 do BSP, do `.nav` e dos parâmetros físicos. Se houver interrupção entre os commits, a memória que não corresponde ao novo `.nav` é descartada; o grafo permanece utilizável e as direções são examinadas novamente.

Pausa, checkpoint ou encerramento durante uma tentativa devolvem a direção interrompida à análise. Um desligamento inesperado preserva o último checkpoint já confirmado. O comando `stop` termina a gravação antes de remover o bot; evite desligar o mapa enquanto `active=1`.

## Configuração e custo

| Cvar | Padrão | Efeito |
| --- | --- | --- |
| `anpc_scan_auto` | `0` | Inicia automaticamente apenas se não houver grafo |
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

O movimento recebe serviço a aproximadamente 50 Hz, com um comando de até 50 ms por execução. Trabalho geométrico, seleção e escrita respeitam limites por frame. O A* conserva seu orçamento próprio de `anpc_nav_expansions`. As chamadas internas da física do motor não entram no contador de traces do mapper.

O orçamento em milissegundos é cooperativo: uma chamada nativa, hashing de arquivo ou renomeação não pode ser interrompida no meio. Não representa uma medição ou garantia de FPS. O mapper usa aproximadamente 0,17 MiB de dados Pawn e 0,125 MiB reservados para heap/stack, além do provedor e da vaga do bot.

Os limites atuais são 4.096 nós, oito saídas direcionadas por nó, 512 pontos iniciais e 128 volumes de escada. Ao atingir a capacidade de nós, o plugin salva um grafo parcial e encerra. O relatório identifica tentativas rejeitadas e limites de fila/conexões.

## Cobertura e teste manual

O scan é uma exploração heurística com prova física. Esgotar candidatos significa terminar as tentativas disponíveis, sem certificar que cada ponto de qualquer BSP foi encontrado. Passagens menores que a resolução escolhida, geometrias incomuns e regiões dependentes de scripts podem exigir sementes adicionais ou edição manual.

Elevadores, botões encadeados, plataformas móveis, água profunda, teletransportes, cooperação entre jogadores e saltos além da física escolhida não ganham conexões inventadas. O mapa é analisado por etapas e o relatório registra as limitações observadas. O seguidor de NPC usa o perfil de cada tipo e recalcula saltos: um grafo criado para um explorador não garante execução por um NPC mais lento, maior ou com outra gravidade.

O scanner é independente de `zpn_main.sma`. Use uma sessão de manutenção e evite que outros plugins infectem, movam, congelem ou removam o fake client. O próprio mapper suprime as verificações/restarts normais do CS durante sua sessão e mantém o bot protegido; regras próprias de outros plugins continuam sendo responsabilidade da configuração do servidor.

A validação de movimento e cobertura no HLDS será feita manualmente pelo usuário. Consulte `TESTING.md` para os cenários sugeridos.
