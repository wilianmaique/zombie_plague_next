# Verificação e testes

## Realizado em 30/09/2026

- Pesquisa das interfaces do YaPB e ReAPI/AMXX, com consulta às includes do ambiente configurado do projeto.
- Leitura do modelo studio v10 `zpn_z_default.mdl`: 111 sequências; confirmação dos sete labels usados pelo tipo inicial.
- Conferência estática das chamadas, registro dos natives próprios e integridade de delimitadores nas fontes.
- Compilação dos seis plugins, incluindo `anpc_mapper`, com `D:\GOOGLE DRIVE\Counter-Strike\Ferramentas\compiler\amxxpc.exe` (AMXX 1.10.0.5467), usando as includes de `D:\GOOGLE DRIVE\Counter-Strike\Ferramentas\compiler\include`: zero erros e zero avisos.
- Correção da criação do fake client: `set_entvar` e as funções de jogador da ReAPI só são chamadas após `ClientPutInServer` e confirmação de private data. A conexão recebe o tamanho do buffer de rejeição; a rotina também registra o fake client no AMXX quando necessário e remove conexões incompletas ao liberar a sessão.
- Correção do encerramento imediato na revisão `1.1.2`: o ReGameDLL escreve `iuser4` durante `PreThink`, invalidando o antigo marcador. A identidade agora usa vaga/`userid`, conexão, private data e estado de bot. O marcador foi removido da API e da percepção; a sessão já exige zero NPCs e bloqueia sua criação. Os encerramentos registram motivo/etapa e a perda de identidade inclui seus campos de diagnóstico. Os seis plugins foram recompilados com zero erros e zero avisos; a validação no jogo dessa revisão permanece manual.
- Correção do parâmetro reservado `state` na rotina de troca de estado, dos índices sem tag `AnpcAnimation` e da indentação na include local `advanced_npc/movement.inc`.
- 11 testes Python do importador: ULZ com overlap e comprimentos estendidos, limites de saída, arquivo truncado, header/versão/tamanho inválidos, conversão de agachamento, saltos calculados, ações sem implementação, vínculo ao mapa, CLI e proteção contra sobrescrita.
- Importação de um grafo real da base oficial do YaPB para o BSP `de_dust2` local, com tamanho correspondente e MD5 gravado.

A compilação foi executada por solicitação explícita do usuário. Os seis binários `.amxx` e seus logs estão em `compiled/advanced_npc/`. A validação em execução do scanner permanece pendente para os testes manuais do usuário; a tentativa de preparar um HLDS isolado foi encerrada a pedido dele. Compilar sem erros não valida física, carregamento, cobertura nem combate no HLDS. Nenhuma integração do scanner foi mantida em `core/zpn_main.sma`.

## Scanner: validação manual

A revisão atual altera o mapper e as seis includes internas, incluindo `mapper_coverage.inc` e `mapper_frontiers.inc`. Essa revisão não foi compilada nem executada no HLDS; as compilações acima pertencem às revisões anteriores. Recompile o mapper manualmente com as includes externas atualizadas antes destes testes. O formato da memória permanece `ANPC_SCAN 2`, com assinatura de política `blocks-frontiers-1`; memórias da política anterior são descartadas, preservando o `.nav`.

A conferência estática passou para as sete fontes Pawn: delimitadores, funções e variáveis referenciadas, natives próprios, 49 chamadas com formatos/argumentos, sete campos do registro de nó `ANPC_SCAN 2` e protocolo do beam com trace separado. A propriedade angular do ajuste de parede foi conferida em 288.008 combinações de setor/ângulo.

Uma conferência auxiliar em Python comparou modelos dos algoritmos com referências independentes: 5.512 segmentos em precisão float32 contra interseções racionais exatas da grade, e 2.000 grafos direcionados contra cálculo completo dos menores custos e da pontuação de fronteiras. Passaram os casos de coordenadas negativas/grandes, direções quase alinhadas a um eixo, cantos, bordas da grade, limite de travessia, decrease-key do heap e parada antecipada. Também foram conferidos spans sobrepostos, rejeição de blocos pendentes/obsoletos, sobreposição das faixas de hull, ausência de mutação de grafo e exclusão da cobertura do journal.

A preparação de retornos em grafos existentes passou por mais 1.000 grafos direcionados, comparando os antecessores escolhidos com o conjunto de arestas de entrada elegíveis. Foram preservados antecessores existentes, tentativas encerradas e nós desabilitados; IDs estritamente menores impediram ciclos. A fonte dessa preparação usa apenas consultas de grafo, sem gravar inversas presumidas.

Esses checks verificam propriedades matemáticas e referências nas fontes; não executam Pawn, a máquina de estados nem a física do HLDS, e não substituem a compilação e os testes abaixo. Corpo, câmera, beam, cobertura e seleção precisam de validação no servidor.

Prepare uma sessão sem NPCs nem plugins controlando o fake client. Carregue os seis plugins na ordem do manifesto e use `anpc_scan start new`. Observe a posição e os contadores com `anpc_scan status`; pelo cliente de um administrador, use `anpc_scan watch 1`, `anpc_scan blocks 1` e `anpc_nav_show 1`.

| Cenário | Resultado esperado |
| --- | --- |
| Iniciar sem navegação/YaPB | Um fake client explora e acrescenta nós/conexões por deslocamentos reais |
| Primeiros comandos e `PreThink` do scout | Sessão permanece ativa após começar a assentar a primeira semente; `iuser4` mantém o estado original de veículos, sem invalidar a identidade |
| Scout muda de direção após nascer | Corpo gira com a direção do movimento, sem permanecer no ângulo do spawn; laser acompanha o olhar |
| `watch 1` em curvas, agachamento e escadas | Câmera acompanha os olhos e yaw/pitch completos, sem a cabeça do scout cobrir a visão |
| Dois administradores usam `watch`; um desliga ou desconecta | O outro continua acompanhando o scout; câmera compartilhada preservada |
| Último `watch 0`, desconexão ou encerramento do scan | Câmera e hook liberados; clientes conectados que encerram a observação recuperam a própria visão |
| `anpc_scan_beam 1`, em pé/agachado/escada e `watch` | Laser verde parte dos olhos, acompanha yaw/pitch reais e termina em obstáculo; leituras do planejamento permanecem independentes |
| `anpc_scan_beam 0` ou encerrar o scan | Sem novos beams; último efeito expira em 0,2 segundo |
| Corredor aberto longo | Percursos de até três espaçamentos, nós intermediários e continuidade; nenhuma volta automática após cada segmento |
| Sala plana larga | Blocos azuis em interiores livres; nós intermediários continuam no grafo, mas não iniciam novas caminhadas inteiramente dentro da cobertura |
| Parede corta um bloco de 256 unidades | Subdivisão sob demanda até 32; interior livre pode ser aproveitado, borda irregular mantém testes por nó |
| Destino conhecido com uma célula desconhecida no caminho | Não dispensar o trajeto só por conhecer o destino |
| Linha diagonal toca uma quina desconhecida ou segue uma borda da grade | Preservar os lados ainda desconhecidos; nenhum salto da consulta de cobertura por cima deles |
| Coordenadas negativas e grandes | Blocos coerentes, sem repetição por erro de arredondamento nem espera infinita na consulta de segmento |
| Térreo e plataforma/andar no mesmo XY | Coberturas de altura independentes; plataforma acessível e outro piso continuam sendo procurados |
| Regiões e ramificações abertas | Amostras desconhecidas precedem continuidade; fronteiras alcançáveis precedem manutenção das voltas; A* para regiões com trabalho pendente |
| Ponto conhecido perto do scout e saída nova ao fundo | Alvo mantém alcance até a fronteira distante, sem virar outra volta curta ao ponto próximo |
| Região perto em linha reta, mas com desvio longo no grafo | Destino comparado por custo direcionado, trabalho restante e visitas |
| Trecho da borda para um interior plano com rota curta existente | Pode dispensar a caminhada redundante; nenhuma nova ligação no grafo |
| Mesmo trecho sem rota, ou com desvio além do limite | Mantém a tentativa física para conectar a região ou descobrir um atalho útil |
| Dois administradores usam `blocks 1`; um desliga ou desconecta | Desenho independente por cliente; contagem de observadores coerente; efeitos antigos expiram |
| Blocos durante pausa | Desenho pode continuar sem explorar; `blocks 0` interrompe novas mensagens |
| Corredor inclinado com parede alta | Direção adaptada à tangente quando cabe no setor; nenhum avanço que atravesse a parede |
| Saída com conexão já comprovada | Incremento de `known-direction skips`; nenhuma nova tentativa da mesma conexão |
| Antecessor com conexão inversa existente | Retorno marcado como resolvido; deslocamento ao antecessor só quando o planejamento precisar dele |
| `.nav` existente com ligações de ida, sem journal correspondente | Preparação incremental de voltas para nós sem antecessor; blocos não dispensam sua prova física |
| Grafo existente com ciclos, nós desabilitados ou retornos já encerrados | Antecessores adotados sempre têm ID menor; nós desabilitados e tentativas encerradas não são reagendados |
| Queda cuja volta não funciona | Volta rejeitada uma vez, preservando apenas as ligações fisicamente verificadas |
| Sétima saída com volta pendente | Última vaga reservada à tentativa de retorno, respeitando oito saídas por nó |
| Parede ou quina | Ausência de conexões que cortem sólidos |
| Piso descontínuo/buraco | Não gerar ligação de caminhada só porque o hull horizontal passa |
| Passagem baixa | Agachar; altura dos pés preservada; flags coerentes |
| Degraus | Pontos intermediários e caminhada dentro dos limites do motor |
| Caixa/plataforma acessível por salto | Salto real e aterrissagem estável; `E` com flag `1` e velocidade observada |
| Salto agachado com folga | Botões de salto/agachamento aplicados pela física, sem velocidade injetada |
| Queda segura | Saída pela borda; `E` com flag `2`, velocidade de arquivo zerada |
| Queda com dano ou além do limite | Tentativa rejeitada, sem conexão que exija invulnerabilidade |
| `func_ladder` | Subida/descida física, nós de escada, sem voo fora do volume |
| Porta comum/quebrável | Callbacks originais; cobertura invalidada e reconstruída; conexão após travessia efetiva |
| Escada, trigger, botão ou plataforma móvel junto a bloco | Área sensível conserva análise detalhada; não vira interior plano resolvido |
| Elevador, botão encadeado, teleporte ou `trigger_push` | Nenhuma conexão artificial representando a ação não implementada |
| Área separada descoberta pela amostragem | Novo episódio, sem aresta entre a posição antiga e a relocação |
| Editar/criar NPC durante scan | Mutação/criação bloqueada; desenho do grafo permanece disponível |
| Pausar e retomar durante uma tentativa | Retoma de uma âncora; direção interrompida disponível para reanálise |
| Pausar/salvar durante o retorno adiado | Antecessor e direção permanecem pendentes; retomada não os trata como comprovados |
| Fila de sementes cheia ou semente inicial já usada | Âncoras pendentes do grafo iniciam episódios diretamente, sem exigir outra entrada na fila |
| Salvar e continuar | `.nav`, `.scan` e relatório confirmados; análise retomada |
| Encerrar com `stop` | `active=1` durante gravação; depois bot removido e edição liberada |
| Scout removido ou identidade inválida | Sessão encerrada com `reason`/etapa no log; vaga reutilizada por outro jogador/bot não é removida |
| Reiniciar o scan com os mesmos arquivos/parâmetros | Memória correspondente reutilizada |
| `.scan` truncado, NAV alterado ou outro perfil | Memória descartada; grafo preservado e exploração refeita |
| Antecessor negativo inválido, igual/maior que o filho ou estado não booleano | Memória rejeitada antes de aceitar a árvore de descoberta |
| Desligar no meio de um `.tmp` | Último checkpoint confirmado preservado |
| Alterar física global durante a sessão | Salva os segmentos provados e encerra |
| Atingir 4.096 nós ou oito saídas | Sem escrita fora dos arrays; limites informados e grafo parcial salvo |
| Limite de blocos ou excesso de volumes sensíveis/escadas | Sem escrita fora dos arrays nem cobertura presumida; exploração detalhada preservada e limite informado |
| `status` em grafo grande | Consulta resultados em cache, sem refazer todos os trajetos geométricos; `pending-estimate` pode diminuir com a análise seguinte |

Confira também `addons/amxmodx/logs/` e o `<mapa>.scan.txt`. Teste um NPC consumindo o `.nav` gerado: física de fake client e física do perfil de NPC precisam funcionar no mapa real. Os contadores mostram atividades/tentativas, sem certificar cobertura integral do BSP.

Para comparar a exploração, use o mesmo BSP, parâmetros, posição inicial e orçamento de CPU. Observe tempo até esgotar candidatos, nós/conexões, regiões cobertas e as distâncias `explore` e `travel/return`, junto com `pruned bearings`, `skipped interior trials` e `cost-ranked targets`. Um tempo menor com áreas ausentes não representa melhora de cobertura. A medição de ganho e a validação dos saltos/escadas continuam dependendo do servidor real. A escolha das técnicas e suas limitações estão em [MAPPING_STRATEGY.md](MAPPING_STRATEGY.md).

Para repetir os testes do importador, a partir da raiz do projeto:

```powershell
python -B -m unittest discover -s addon/advanced_npc/tools -p "test_*.py" -v
```

## Validação no servidor

| Cenário | Resultado esperado |
| --- | --- |
| Carregamento dos plugins na ordem indicada | Bibliotecas/natives disponíveis; tipos completos e modelo precacheado |
| Mapa sem grafo | Log informativo; `anpc_spawn` retorna 0 |
| Arquivo com mapa, tamanho ou hash incorreto | Grafo rejeitado, sem criar uma topologia parcial |
| NPC em corredor aberto | Caminha com hull e animação, sem ocupar vaga de jogador |
| Jogador atrás de parede, em outra região conectada | Planeja caminho e segue os corredores |
| Escadas/degraus | Usa as regras de step height do motor |
| Túnel agachado | Ajusta hull; só levanta com espaço |
| Salto marcado | Calcula e verifica o arco; mantém gravidade e colisão durante o salto |
| Escada vertical | Sobe/desce junto de `func_ladder`; saída devolve gravidade normal |
| Porta comum | Executa `Use` respeitando a política de portas do pacote |
| Porta com ação própria | Não abre a rota sem a implementação dessa ação |
| Caixa quebrável | Golpes usam dano original e disparam destruição/targets do mapa |
| Jogador sai do alcance durante a preparação | Golpe não causa dano fora do alcance |
| Jogador se torna zumbi durante a preparação | Bridge bloqueia impacto aliado |
| Tiros, shotgun, faca, HE e cabeça | NPC perde HP pelo fluxo de dano; headshot usa multiplicador do perfil |
| Morte | Corpo sem colisão/dano; animação; slot liberado após o tempo configurado |
| Jogador desconecta e a vaga é reutilizada | `userid` antigo não identifica o novo jogador |
| Muitos NPCs em uma passagem | Yield/recuperação; colisões de atores não bloqueiam globalmente a aresta |
| Caminho impossível | Rejeição temporária do alvo e tentativa de outros candidatos |
| `anpc_clear` durante combate | Remoção diferida segura e rotas devolvidas |
| Restart da rodada | NPCs antigos removidos; spawns opcionais repostos após freeze time |
| Edição e reload | Rotas invalidadas por revisão; arquivos salvos com backup |

## Desempenho

Compare servidor sem NPCs, 4, 12 e 24 NPCs, com jogadores espalhados em regiões diferentes do mapa. Observe CPU, FPS do servidor, estabilidade e atraso para encontrar novas rotas. Teste também corredor estreito e bloqueio por grupo, porque traces e colisões custam mais nesses casos.

O limite de expansões é global por frame. Aumentá-lo reduz fila de rotas e aumenta trabalho naquele frame. Diminuir o intervalo de Think aumenta frequência de movimento e checagens. Ajuste os valores com medição no mapa real; não há medição de FPS/custo de HLDS nesta entrega.
