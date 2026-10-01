# Explorador autônomo

`anpc_mapper.sma` gera navegação no mapa carregado, inteiramente por plugins AMXX. Cada scout ocupa uma vaga de jogador durante a análise; a equipe deixa uma vaga adicional disponível para o administrador. Os NPCs usados no jogo continuam sendo entidades sem ocupar vagas.

## Exploração com vários scouts

Defina `anpc_scan_bots 4` antes de `anpc_scan start` ou `start new` para usar quatro exploradores. A cvar aceita 1 a 8, com padrão 1. O início captura a quantidade e a reduz às vagas disponíveis, preservando uma vaga livre; se nenhuma estiver disponível, não inicia. Uma falha de criação libera todos os clientes e rotas já alocados. Alterar a cvar durante uma sessão afeta o próximo início.

Cada scout mantém sensores, sondagens, postura, saltos, prazos, histórico de rotas impossíveis e Dijkstra próprios. O grafo, a cobertura geométrica, as sementes e a memória são compartilhados. As sementes são escolhidas longe dos exploradores ativos. Uma reserva por âncora impede que dois scouts analisem a mesma origem ou escolham a mesma fronteira enquanto o responsável viaja até ela. Reservas são devolvidas ao terminar, falhar, pausar ou salvar. Descobertas de outros scouts não reiniciam constantemente uma varredura ou busca em andamento.

Na caminhada, os scouts antecipam encontros e tentam um comando lateral com hull e apoio comprovados, mantendo o destino da tentativa. O hook ReAPI `RH_SV_AllowPhysent` exclui somente outros membros válidos da equipe da física de cada scout. Assim, corredores sem espaço lateral não bloqueiam a equipe, e um explorador não serve de apoio para saltos de outro. Paredes, portas, terreno e jogadores fora da equipe conservam suas colisões. Saltos, quedas e escadas seguem seus comandos físicos próprios. O desvio e o filtro não acrescentam conexões: continuam valendo as provas de movimento e terreno.

Pausa e checkpoint interrompem todos os scouts em suas últimas âncoras verificadas, cancelam as rotas e devolvem as sementes que ainda estavam assentando. Só tentativas encerradas entram na máscara do journal; uma interrupção preserva segmentos já provados por qualquer scout. A conclusão automática espera toda a equipe ficar sem trabalho, terminar a amostragem e conferir novamente as fronteiras compartilhadas. Se qualquer cliente perder sua identidade, a sessão é encerrada e o último checkpoint confirmado permanece preservado.

## Como ele explora

O scanner começa nos spawns de CT/TR e nas posições de jogadores presentes. Faz uma varredura incremental de oito setores horizontais, com alcance de até três vezes o espaçamento. As leituras de hull identificam espaço livre e obstáculos antes da caminhada. A escolha prioriza a quantidade de amostras ainda desconhecidas; alcance, continuidade da direção e visitas desempatam os candidatos. Em corredores inclinados, pode ajustar a direção para a tangente de uma parede estática alta, mantendo o ajuste dentro do setor original. Obstáculos baixos continuam disponíveis para os testes de salto.

Um hull horizontal que encontra uma superfície caminhável (`normal.z >= 0.7`) mantém o candidato longo de exploração. A inclinação observada ajuda a estimar a altura das amostras usadas na escolha; ela não certifica a passagem. Antes de andar, o mapper acompanha o piso em pequenos intervalos XY, obtendo os pés pelo contato de um hull de jogador com o chão. A subida acumulada de uma rampa pode superar a altura de um degrau ou de um salto, desde que cada intervalo continue caminhável. Se o piso termina ou encontra um obstáculo depois de um avanço útil, o alvo pode ser encurtado para o fim desse trecho validado.

Trechos livres recebem alvos mais distantes; um ponto conhecido perto do bot não encurta um alvo desconhecido mais adiante. Em interiores planos já validados, o mapper dispensa âncoras intermediárias periódicas. Fora deles, preserva espaçamento e pontos necessários para representar o terreno. Cada nó novo guarda seu antecessor de descoberta. A verificação física da volta é adiada enquanto existe uma fronteira nova alcançável pelo grafo. Uma ida real inteiramente em cobertura estática plana permite comprovar a caminhada inversa sem repetir o percurso; nos demais casos, a volta mantém sua própria tentativa física. Retornos impossíveis são encerrados sem inventar conexões. As direções de ligações percorridas também ficam registradas.

Ao começar com um `.nav` atual existente, também examina suas arestas por etapas. Para nós sem antecessor, pode agendar uma volta ausente para um nó de ID menor que já tenha ligação de ida. Isso mantém uma árvore sem ciclos e permite verificar retornos mesmo sem journal; uma tentativa já encerrada na memória é preservada. Essa preparação não cria a inversa presumindo que um salto ou uma queda são reversíveis.

As leituras de alcance orientam o planejamento, sem certificar piso, salto ou passagem. O bot mantém testes de caminhada, agachamento, salto, queda e duas direções de escada. Alvos conhecidos são reutilizados quando estão no setor e têm acesso por hull; a conexão só entra no grafo depois da travessia. O índice espacial do provedor evita comparar cada amostra com todos os nós.

Quando a região local já foi analisada, um Dijkstra incremental compara o custo das rotas direcionadas existentes até outras fronteiras, com penalidades de agachamento, escada, salto/queda e visitas, favorecendo destinos com mais direções pendentes. Isso evita escolher um destino próximo em linha reta que exige uma volta longa. O A* do provedor produz a rota de deslocamento. Limites inferiores de pontuação permitem encerrar a seleção antes de visitar todo o grafo quando já existe uma escolha melhor que as restantes. Buscas impossíveis são lembradas até uma alteração relevante na topologia; arestas que falham em movimento recebem também bloqueio temporário na seleção.

A amostragem incremental dos limites do BSP procura outros pisos enquanto o bot caminha, usando o orçamento restante do frame, e acrescenta pontos iniciais para regiões separadas. Sementes dentro de blocos de piso já analisados são dispensadas. Âncoras do grafo sem rota podem iniciar episódios diretamente, sem duplicar nem consumir a fila dinâmica de sementes; âncoras que não conseguem assentar um jogador são registradas como rejeitadas.

Mudanças de episódio e recuperação podem reposicionar o explorador em uma âncora validada. **Esse reposicionamento não grava uma conexão.** Regiões separadas continuam separadas no `.nav` até existir uma travessia física verificada.

## Blocos adaptativos e redução das repetições

A navegação usa retângulos convexos, inclusive inclinados, e âncoras para passagens e movimentos especiais. Uma âncora inicia a análise de um quadrado de 256 unidades. Se houver obstáculo, desnível irregular ou volume sensível, os quatro filhos são analisados em 128/64/32 unidades, incluindo partes sem pontos. Trechos que não aprovam o tamanho mínimo continuam detalhados por âncoras.

O teste começa junto aos pés com o hull real, sem lançar o raio de dentro do teto. O plano de apoio vem da normal do contato (`z >= 0,7`); amostras de piso a cada no máximo 16 unidades precisam permanecer nesse plano. Faixas sobrepostas do hull verificam paredes, caixas e folga. Se o hull em pé não cabe, o bloco tenta agachamento. Buracos, degraus, água, piso móvel e volumes sensíveis não recebem uma área simples. Dois pisos no mesmo XY são independentes. A certificação tem resolução finita; mantenha a validação no jogo dos detalhes estreitos.

Retângulos coplanares de mesma postura podem ser unidos em um retângulo completo dentro da célula de 256 unidades. A união não preenche L, lacunas ou andares diferentes. Direções de exploração cobertas por apoio contínuo deixam de gerar tentativas repetidas; rampas uniformes também participam. Ao continuar, o mapper lê os planos de todas as áreas anteriores e revalida a geometria por etapas antes de explorar. Essa revalidação independe de nós internos, incluindo arquivos somente com áreas. A geometria também é invalidada e reconstruída depois de ações de obstáculo.

Durante a exploração, o scout mantém amostras temporárias para suas rotas, antecessores e checkpoints. Dispensa amostras periódicas em área conhecida; fora dela usa `anpc_scan_spacing`, limitado à prova de dezesseis amostras. Reutilizar uma âncora exige hull e apoio, nunca apenas proximidade. Pontos de salto, queda, escada e crista mantêm precisão.

Quando os candidatos são esgotados, a gravação final termina a análise pendente e compacta o grafo por etapas. Remove apenas pontos comuns cujas conexões WALK podem ser substituídas pelo interior convexo da mesma área e postura. Preserva ambos os extremos das outras conexões, além de pontos precisos, escadas e pontos desabilitados. Gera portais em bordas compartilhadas de pelo menos 16 unidades com planos contínuos. A* pode andar entre âncoras da mesma área sem criar uma malha de arestas internas. Limite de pontos impede adicionar portais extras, mas não remove as conexões físicas entre regiões já preservadas.

A compactação remapeia também os IDs do journal; antecessores removidos ficam encerrados. **`save`, `stop` e checkpoints de um scan incompleto preservam as amostras**, para permitir retomada sem perder fronteiras. Aguarde a conclusão automática para avaliar a contagem final de âncoras. No debug, contornos aparecem independentemente dos pontos; o HUD distingue `scan samples` de `anchors` e mostra áreas desenhadas/total.

`anpc_scan status` e `<mapa>.scan.txt` informam áreas abertas e rejeições por piso, plano, hull, volume sensível ou capacidade. Esses contadores explicam `areas 0/0`; uma rampa uniforme ou um teto baixo válido não deve ser rejeitado pela regra antiga de piso horizontal/raio elevado. Consultas geométricas de áreas não dispensam colisão atual nem validam automaticamente saltos e escadas.

`Floor probe failures` detalha as consultas recusadas: `support` indica ausência de apoio válido, `solid-start` um hull inicialmente dentro de sólido, `non-world` apoio em uma entidade e `height` afastamento do piso previsto. Contam consultas, inclusive as duas posturas e provas de trechos conhecidos, não blocos únicos. Um contato válido com worldspawn aparece como `FM_NULLENT` (-1) no Fakemeta; fração e normal distinguem apoio real de uma consulta sem contato. `Survey: enabled` e `valid-BSP-bounds` distinguem varredura desligada de limites do BSP indisponíveis.

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
| `anpc_scan watch 1 [scout]` / `watch 0` | Liga/desliga a câmera; índice de 1 até a quantidade ativa, padrão 1 |
| `anpc_scan blocks 1` / `blocks 0` | Liga/desliga quadrados azuis de piso analisado perto do scout, apenas para esse administrador |

O modo `watch` acompanha a posição dos olhos e os ângulos completos do scout, inclusive ao virar, agachar e subir/descer escadas. `watch 1 2` seleciona o segundo explorador; administradores podem observar scouts diferentes. Há uma câmera por scout observado, compartilhada por seus observadores. O corpo selecionado fica oculto apenas para quem usa sua câmera. `watch 0` ou o encerramento devolvem a visão; câmeras sem observadores são liberadas. A câmera não acrescenta traces ao planejamento.

Os estados numéricos individuais são `0` desligado, `1` preparando episódio, `2` escolhendo fronteira, `3` aguardando/seguindo rota, `4` analisando geometria, `5` movendo, `6` pausado, `7` salvando e `8` candidatos esgotados. O estado da sessão mostra preparação compartilhada (`1`), exploração (`2`), pausa (`6`), gravação (`7`) ou encerramento (`0`/`8`). `status` lista também entidade, estado, âncora, reserva e posição de cada scout.

Use `anpc_nav_show 1` para desenhar as âncoras e os contornos azuis de até oito retângulos visíveis, selecionados independentemente dos pontos. A edição manual e a criação de NPCs ficam bloqueadas enquanto o scanner mantém a edição exclusiva. O gravador manual ativo é encerrado ao começar a análise.

Com `anpc_scan_beam 1` (padrão), lasers verdes saem dos olhos dos scouts e acompanham seus ângulos reais de visão, incluindo a inclinação nas escadas. Cada linha termina no primeiro sólido/jogador encontrado ou em 1.024 unidades. O desenho alterna entre exploradores, até dez atualizações por segundo no total, usando somente o orçamento restante. `anpc_scan_beam 0` desliga o efeito. O laser representa o olhar do bot, não todas as direções da varredura geométrica.

`blocks 1` desenha uma seleção de até 12 blocos próximos, no piso atual do scout, cerca de duas vezes por segundo por observador e sob o orçamento disponível. Não acrescenta traces e fica desligado por padrão. Azul indica um bloco que passou na classificação geométrica desta sessão, sem significar cobertura integral do BSP ou passagem física em todos os seus pontos.

O scout é identificado pela vaga e pelo `userid` da conexão, com confirmação de private data e estado de bot. O mapper preserva os campos `iuser*` usados pela física/GameDLL. Toda linha `Mapper ended` informa `reason` e a etapa em que a sessão terminou. Quando a identidade deixa de ser válida, o log também mostra a vaga, os userids esperado/atual, conexão, flag de fake client e private data antes de liberar a sessão.

## Checkpoints

Os arquivos ficam em `addons/amxmodx/configs/advanced_npc/maps/`:

| Arquivo | Conteúdo |
| --- | --- |
| `<mapa>.nav` | Nós, áreas `A` e conexões no formato atual `ANPC_NAV 4` |
| `<mapa>.scan` | Memória `ANPC_SCAN 2`: direções/visitas, antecessores, retornos pendentes, âncoras rejeitadas, sementes e amostragem |
| `<mapa>.scan.txt` | Contadores, perfil físico, limites atingidos e movimentos não representados |
| `*.bak` | Versão anterior do respectivo arquivo |
| `*.tmp` | Gravação em andamento; um arquivo incompleto nunca é promovido |

A escrita congela a exploração e distribui registros por frames. O commit de cada arquivo usa renomeação com backup. A memória inclui MD5 do BSP, do `.nav` e uma assinatura dos parâmetros físicos e da política de exploração. Se houver interrupção entre os commits, a memória que não corresponde ao novo `.nav` é descartada; o grafo permanece utilizável e as direções são examinadas novamente.

O formato de memória permanece `ANPC_SCAN 2`; memórias em outro formato são descartadas. O provedor aceita somente `ANPC_NAV 4`, descrito em [NAVIGATION.md](NAVIGATION.md). Gere um scan novo ou reimporte grafos antigos antes de usar esta revisão. Continuar um grafo preserva IDs até a compactação final; `anpc_scan start new` facilita comparar a geração atual sem amostras antigas. Os antecessores têm IDs menores que seus filhos, impedindo ciclos na árvore de descoberta. Retornos interrompidos por pausa/checkpoint continuam pendentes.

A política atual tem a assinatura `planar-regions-team-2`. Um `.scan` com outra assinatura é descartado mesmo no formato 2; o grafo atual permanece e a exploração é reanalisada. Checkpoints desta revisão podem ser retomados com outra quantidade de scouts, pois a memória conserva trabalho compartilhado, sem identidades ou reservas transitórias. As áreas e a cobertura são reconstruídas a partir do mapa e das âncoras; durante o checkpoint, retângulos atuais são gravados junto do grafo.

Pausa e checkpoint mantêm pendentes as tentativas interrompidas, preservando direções já comprovadas em segmentos parciais. Um desligamento inesperado preserva o último checkpoint confirmado. O comando `stop` termina a gravação antes de remover todos os bots; evite desligar o mapa enquanto `active=1`.

## Configuração e custo

| Cvar | Padrão | Efeito |
| --- | --- | --- |
| `anpc_scan_auto` | `0` | Inicia automaticamente apenas se não houver grafo |
| `anpc_scan_bots` | `1` | De 1 a 8 scouts independentes; limitado às vagas disponíveis, com uma reservada |
| `anpc_scan_beam` | `1` | Mostra o laser de direção do olhar durante a sessão; 0/1 |
| `anpc_scan_spacing` | `128` | Espaçamento de exploração e dos nós comuns; 48 a 160, sujeito ao limite de prova do piso |
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

Quantidade, espaçamento, velocidade, gravidade e limite de queda são capturados no início da sessão. Alterá-los na configuração afeta a próxima sessão. Mudanças relevantes na física global durante o scan fazem o plugin salvar os segmentos já provados e encerrar, para evitar misturar condições de teste.

Para conferir no `de_dust2`, encerre a sessão anterior e aguarde `active=0`. Recompile manualmente os seis plugins com as includes externas atualizadas, incluindo `navigation_portals.inc`; carregue os binários juntos. Use `anpc_scan start new`, `anpc_nav_show 1` e `anpc_scan status`. Observe áreas nas rampas e corredores, aguarde a conclusão automática e compare as âncoras finais. O formato atual é `ANPC_NAV 4`; nenhum formato anterior é aceito. A execução no HLDS continua pendente.

O movimento recebe serviço a aproximadamente 50 Hz, com um comando de até 50 ms por execução. Trabalho geométrico, seleção e escrita respeitam limites por frame. O ciclo aceita até 96 etapas leves por frame, sempre sob o orçamento cooperativo. Cada etapa de Dijkstra executa até oito operações limitadas de enumeração de vizinhos, conservando nó e cursor entre frames; inclui caminhadas implícitas nas áreas já certificadas durante o scan; a classificação divide testes de volumes, faixas de hull e amostras de chão entre chamadas. O trabalho em segundo plano aceita até oito etapas de blocos e oito células de amostragem, com prioridade para os blocos conhecidos. A preparação de uma semente e a consulta de rota interna aguardam outros frames em vez de repetir sua espera no mesmo frame. O A* conserva seu orçamento próprio de `anpc_nav_expansions`. As chamadas internas da física do motor não entram no contador de traces do mapper.

Os 96 passos, traces, orçamento de CPU e escrita são compartilhados por toda a equipe. O movimento tem prioridade e a ordem de atendimento alterna; consultas aguardando física/rotas não monopolizam os passos restantes. Cada cliente continua recebendo comandos a aproximadamente 50 Hz. A física do motor e a prova imediata de um comando são indivisíveis e podem ultrapassar o orçamento cooperativo; mais scouts aumentam esse custo, sem garantir aceleração proporcional.

O orçamento em milissegundos é cooperativo: uma chamada nativa, hashing de arquivo ou renomeação não pode ser interrompida no meio. Não representa uma medição ou garantia de FPS. A árvore de descoberta e os estados de retorno/rejeição usam 48 KiB de arrays Pawn; as reservas acrescentam 16 KiB. Busca e histórico de inacessibilidade reservam cerca de 96 KiB por scout, com arrays para até oito. Blocos usam `Array:` com 19 células (76 bytes de dados) por registro, crescendo conforme a análise; foi removida a reserva estática de 2,375 MiB. Sementes também têm índice espacial próprio de 16 KiB para deduplicação local. A reserva e os metadados das arrays acrescentam custo além dos registros. O provedor acrescenta associação área/âncoras, remapeamento e finalização. Permanecem 0,125 MiB reservados para heap/stack, além do provedor e das vagas dos bots.

A prova de terreno processa um intervalo por etapa e reserva até 14 traces para tentar as duas posturas. Sem essa reserva, aguarda o próximo frame. Rampas uniformes normalmente precisam apenas da busca de apoio e do hull entre os dois apoios; buscas de teto/piso e folga adicional são usadas quando necessário. A caminhada continua atendida antes desse trabalho.

O status e o relatório mostram `sweeps` (varreduras locais), `known-direction skips` (saídas já ligadas), `long walks` (tentativas terrestres acima de 1,5 vezes o espaçamento) e `deferred returns` (tentativas de volta adiadas). As distâncias separam exploração de deslocamento/retorno, em unidades do mapa; reposicionamentos não entram nessas distâncias. São contadores da sessão, não porcentagens de cobertura nem medição de ganho de velocidade.

Há também contadores de blocos abertos/detalhados, setores dispensados pela geometria, tentativas interiores dispensadas e destinos selecionados por custo. `Navigation areas` informa retângulos atuais; `suppressed node samples` conta amostras periódicas dispensadas, podendo contar vários frames do mesmo trecho; `symmetric floor returns` conta inversas comprovadas pela área plana e `local landings` conta candidatos de topo validados. Esses valores não são uma contagem de nós removidos. `pending-estimate` usa resultados já consultados, para que um comando de status não refaça a geometria do mapa inteiro; pode superestimar o trabalho que os próximos testes de cobertura vão retirar.

Permanecem os limites de 4.096 âncoras, 4.096 áreas e oito scouts, além das vagas do motor. Ao atingir a capacidade de nós durante a exploração, o plugin salva um grafo parcial e encerra. Esgotar áreas mantém a exploração detalhada e aparece nas razões de rejeição. Blocos, sementes, escadas, volumes sensíveis e arestas físicas crescem em `Array:`; exceder os antigos caches de entidades não desativa mais a classificação inteira. O crescimento continua limitado pela memória disponível e, para arestas únicas, pela quantidade de nós. Arrays densos de heap, stamps, custos e estados por nó/scout permanecem para acesso direto. Remover também o limite de nós exigiria alterar esse planejador e seus orçamentos; veja [SCAN_REVIEW.md](SCAN_REVIEW.md).

O relatório acrescenta `Anchor reuse`, `bounded_alignments` e `certified_route_shortcuts`, também mostrados por `status`. Alinhamento não muda de âncora nem renova o prazo da tentativa; usa a mesma tolerância XY/altura da conclusão. Deslocamento em rota conhecida e alinhamento não criam amostras terrestres periódicas. A seleção de âncora examina até oito candidatos geométricos e faz até quatro provas de acesso, evitando que um ponto próximo atrás de uma parede esconda os outros. A fila de sementes consulta células próximas por hash e seu índice é reconstruído ao retomar o journal.

## Cobertura e teste manual

O scan é uma exploração heurística com prova física. Esgotar candidatos significa terminar as tentativas disponíveis, sem certificar que cada ponto de qualquer BSP foi encontrado. Passagens menores que a resolução escolhida, geometrias incomuns e regiões dependentes de scripts podem exigir sementes adicionais ou edição manual.

Elevadores, botões encadeados, plataformas móveis, água profunda, teletransportes, cooperação entre jogadores e saltos além da física escolhida não ganham conexões inventadas. O mapa é analisado por etapas e o relatório registra as limitações observadas. O seguidor de NPC usa o perfil de cada tipo e recalcula saltos: um grafo criado para um explorador não garante execução por um NPC mais lento, maior ou com outra gravidade.

O scanner é independente de `zpn_main.sma`. Use uma sessão de manutenção e evite que outros plugins infectem, movam, congelem ou removam o fake client. O próprio mapper suprime as verificações/restarts normais do CS durante sua sessão e mantém o bot protegido; regras próprias de outros plugins continuam sendo responsabilidade da configuração do servidor.

A validação de movimento e cobertura no HLDS será feita manualmente pelo usuário. Consulte `TESTING.md` para os cenários sugeridos.
