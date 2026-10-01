# Navegação e ferramentas

## Gerador autônomo pelo plugin

`anpc_scan start new` cria um fake client que explora o mapa sozinho e grava caminhadas, agachamento, saltos, quedas e escadas depois de executá-los. Esse modo não precisa do YaPB nem de conversão externa. `anpc_scan stop` salva e encerra; `anpc_scan start` continua um grafo e sua memória correspondente.

O gerador escreve diretamente o `.nav` na pasta de configurações do servidor. [AUTOMAPPER.md](AUTOMAPPER.md) descreve instalação, comandos, checkpoints, orçamento e limites. Durante a análise, edição manual e criação de NPCs ficam bloqueadas. `anpc_nav_show` continua disponível para observar o grafo.

## Grafos do YaPB

Use um `.graph` **atual, versão 2**, do [banco de grafos YaPB](https://github.com/yapb/graph) ou do seu próprio YaPB. O importador lê o header, descomprime ULZ com limites e valida os registros `Path` de 220 bytes. Usa somente Python 3.11+ e sua biblioteca padrão.

Exemplo no PowerShell, a partir da raiz deste projeto, ajustando os caminhos do servidor:

```powershell
python -B .\addon\advanced_npc\tools\import_yapb_graph.py `
  "C:\cstrike\addons\yapb\data\graph\zm_nome.graph" `
  --bsp "C:\cstrike\maps\zm_nome.bsp" `
  --output ".\addon\advanced_npc\configs\maps\zm_nome.nav"
```

O comando cria `.nav` e `.report.json`. O BSP precisa ser o arquivo exato usado no servidor. A extensão do YaPB, quando presente, fornece tamanho esperado do BSP; uma diferença cancela a importação. O MD5 do BSP fornecido fica no arquivo final e é verificado pelo plugin ao carregar o mapa.

Se o destino já existe, o importador pede outra saída ou a opção explícita `--force`. O plugin não baixa grafos durante o jogo. Formatos antigos `.pwf` e formatos de forks não fazem parte desta API.

O relatório apresenta autor, nós, conexões, componentes, pontos sem entrada/saída, ações desabilitadas e transições que precisam de revisão. Componentes fracamente conectados não comprovam alcançabilidade direcionada nem viabilidade física de todos os saltos.

Flags de agachamento e escada são convertidas. Saltos preservam a referência de velocidade aprendida, inclusive referências que precisam ser resolvidas novamente sob a física do NPC. Descidas sem flag de salto com diferença vertical maior que 64 unidades são classificadas conservadoramente como descidas e listadas para revisão no mapa.

Pontos com `Button`, `Lift` e `DoubleJump` ficam desabilitados. Essas ações dependem de lógica própria e não devem ser tratadas como uma caminhada comum. Flags táticas, de equipe e de objetivos de bots não limitam o deslocamento do NPC.

## Referência para de_dust2

O [grafo de_dust2 do YaPB](https://github.com/yapb/graph/blob/19b802d42fbdadabd3205fb767c8ea59d976a7de/graph/de_dust2.graph) pode ser importado com o BSP exato do servidor. O importador atual gera `ANPC_NAV 3`; grafos YaPB fornecem pontos e conexões, sem áreas certificadas. Para obter áreas e portais, execute o mapper no servidor. O BSP e arquivos `.nav` gerados não são distribuídos no projeto.

## Editor de mapa

Os comandos exigem `ADMIN_RCON`. Limpe os NPCs e aguarde a liberação dos slots antes de editar. O gravador não cria ligações de posições no ar ou em noclip.

```text
anpc_clear
anpc_nav_show 1
anpc_nav_record 1
```

Caminhe pelos corredores, escadas e passagens agachadas. O gravador adiciona pontos com aproximadamente 128 unidades de espaçamento ou variação de altura relevante, reutiliza âncoras próximas e cria ligações terrestres verificadas nos dois sentidos. Salve ao terminar:

```text
anpc_nav_record 0
anpc_nav_save
anpc_nav_show 0
```

O gravador cobre trechos efetivamente percorridos. Para completar a cobertura, percorra ramificações, conecte segmentos e teste a rota de cada região importante. Saltos, quedas e escadas verticais são ligações explícitas.

`anpc_nav_show 1` acompanha a câmera e atualiza a cada 0,2 segundo. Seleciona até 32 âncoras no cone frontal de 120 graus, a até 5.000 unidades, e até 32 arestas físicas. Até oito áreas são selecionadas independentemente dos pontos e desenhadas em azul, acompanhando a inclinação do piso. Portais têm marcadores azuis. Durante o scan, amostras comuns já cobertas deixam de ocupar o desenho; o HUD identifica a contagem total como `scan samples`, pois esses IDs temporários continuam necessários ao journal. Após a conclusão automática, mostra `anchors`. `areas X/Y` significa áreas desenhadas/áreas existentes; `0/Y` pode ser apenas ausência de áreas no campo de visão, enquanto `0/0` indica nenhuma área aprovada.

O desenho continua ao morrer ou entrar em spectator, sem precisar repetir o comando. Em câmera livre, usa a posição e os ângulos do administrador; em primeira pessoa, usa os olhos e a direção do jogador acompanhado. Câmeras de entidade criadas com `SetView`, como as do addon de câmera do projeto, usam a própria posição e os próprios ângulos. Nas câmeras de perseguição, usa o alvo acompanhado e aproxima o recuo padrão de 112 unidades com trace contra o mapa; a posição exata, uma distância de perseguição personalizada, o autodirector e o overview são calculados pelo cliente e não estão disponíveis nessa consulta do servidor. Primeira pessoa e câmera livre são os modos indicados para conferir o grafo em spectator.

| Comando | Uso |
| --- | --- |
| `anpc_nav_add [flags] [radius]` | Nó nos seus pés; no chão, ou próximo de uma escada real com flag de escada |
| `anpc_nav_link from to 0` | Caminhada direcionada; hull e chão são verificados, exceto a transição marcada de escada |
| `anpc_nav_link from to 1` | Salto com solução física calculada no jogo |
| `anpc_nav_link from to 1 vx vy vz` | Salto com referência aprendida de tempo/velocidade |
| `anpc_nav_link from to 2` | Descida direcionada; destino deve estar mais de 18 unidades abaixo |
| `anpc_nav_unlink from to` | Remove somente essa direção |
| `anpc_nav_flags node flags` | Atualiza flags do nó |
| `anpc_nav_save` / `anpc_nav_reload` | Grava/recarrega o mapa atual |
| `anpc_nav_show 0|1` | Nós, ligações e retângulos à frente da câmera; desenho limitado ao admin, inclusive morto/spec |
| `anpc_nav_record 0|1` | Gravação de trechos terrestres válidos |

Uma conexão é direcionada. Para caminhar também na volta, crie `to -> from`. Quedas e saltos podem ser viáveis em apenas um sentido. O máximo é oito arestas físicas por nó. Conexões WALK implícitas entre âncoras da mesma área não consomem essas vagas.

Flags de nó: `1` agachado, `2` escada, `4` desabilitado, `8` portal; podem ser somadas. Raio deve ficar entre 8 e 64. O seguidor limita tolerância de avanço a 24 unidades e a quatro unidades nos portais ou antes de uma saída de salto/queda. Para posições precisas, prefira raio 8.

## Formato atual `.nav`

A ordem é nós, áreas opcionais e conexões. IDs de nós e de áreas são sequenciais a partir de zero em contagens independentes. Coordenadas representam os pés, com decimais; `NaN`, infinitos, índices fora dos limites e registros desconhecidos são rejeitados.

```text
ANPC_NAV 3 "nome_do_mapa" tamanho_do_bsp md5_do_bsp
N id x y z raio flags
A id min_x min_y max_x max_y z_em_min_xy normal_x normal_y normal_z flags
E origem destino flags vx vy vz
```

O header contém cinco campos, `N` e `E` sete campos e `A` onze. O MD5 tem 32 caracteres hexadecimais minúsculos. Linhas vazias e comentários começando com `;` ou `#` são aceitos. O provedor aceita somente a versão atual; arquivos antigos devem ser gerados ou importados novamente.

Cada `A` descreve uma região convexa de piso estático, horizontal ou inclinado: lados de 32 a 256 unidades dentro de uma célula espacial de 256, normal unitária com `z >= 0,7` e flags `0` ou `1` (agachamento). `z_em_min_xy` é a altura dos pés em `(min_x,min_y)`; nos outros pontos, `z = z_em_min_xy - ((x-min_x)·normal_x + (y-min_y)·normal_y)/normal_z`. Não se trata da altura da superfície visível do brush: o hull determina o plano de apoio dos pés. Limites incluem bordas compartilhadas, com tolerância XY de 0,01 e Z de uma unidade. Pisos sobrepostos ficam separados pelo plano. Há até 4.096 áreas.

Uma borda compartilhada de pelo menos 16 unidades e planos de apoio contínuos admite um portal. Contato somente por uma quina, parede, lacuna ou mudança de piso não cria essa passagem. Portais persistem como registros `N` com flag `8`; sua associação às áreas é reconstruída ao carregar. A* combina arestas físicas `E` com caminhada implícita entre âncoras pertencentes à mesma área. Colisões atuais ainda são verificadas no movimento. É válido um arquivo com áreas e zero nós: o NPC pode andar dentro da região isolada, sem precisar de âncora para nascer ou perseguir um alvo nela.

Velocidade da aresta fica zerada para caminhada/descida. No salto, uma referência zero solicita cálculo pelo perfil. A referência define uma preferência de tempo quando viável; o núcleo sempre calcula o lançamento usando a gravidade atual e verifica o arco.

O loader valida estrutura, mapa, tamanho, MD5 e limites. A geometria das ligações importadas é verificada durante o deslocamento; esse arquivo não contém um certificado de viabilidade física de cada aresta.

## Spawns

Posicione os NPCs com `anpc_spawn`, depois execute `anpc_spawns_save`. Isso grava as posições **atuais** dos NPCs vivos; use o comando antes de eles se afastarem das posições que você deseja persistir. `anpc_spawns_load` cria os pontos salvos quando não existem outros NPCs.

```text
ANPC_SPAWNS 1 "nome_do_mapa" tamanho_do_bsp md5_do_bsp
S "zombie_default" x y z yaw
```

O tipo é persistido pelo nome, para independência da ordem de registro. Todos os registros são validados antes do primeiro spawn. Cada criação ainda pode falhar por hull ocupado, ausência de âncora ou capacidade; o log identifica o ponto.

`anpc_auto_spawn 1` usa esses pontos após o freeze time. Com a bridge, os NPCs aguardam jogadores elegíveis e o início efetivo da rodada ZPN.

## Regiões que precisam de tratamento próprio

Elevadores, botões que abrem rotas, cooperação para saltos duplos, água profunda e teletransportes roteirizados precisam de lógica de travessia adicional. O primeiro tipo suporta solo, degraus do motor, agachamento, saltos/descidas viáveis, escadas reais, portas comuns e obstáculos quebráveis.

Uma região ausente do grafo, uma conexão desabilitada ou um salto além do limite do perfil pode impedir a perseguição. Use o relatório e o editor para localizar o caso, representar a travessia real e testar a conexão. A recuperação não transporta o NPC através de obstáculos.
