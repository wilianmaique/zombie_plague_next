# Verificação e testes

## Equipe de exploradores — 01/10/2026

`anpc_scan_bots` permite 1 a 8 scouts, com padrão 1. Esta alteração exige recompilação manual de `anpc_mapper.sma` com todas as includes externas atuais, incluindo `mapper_team.inc` e `advanced_npc_mapper.inc`. O Codex não executou o compilador, os plugins no HLDS nem mediu aceleração/FPS.

O log de compilação enviado pelo usuário revelou o uso indevido da palavra reservada `forward` como parâmetro de `scan_avoid_peers`, invalidando sua declaração e as expressões que usavam esse parâmetro. Ele foi renomeado para `forward_speed`; a chamada mantém seus quatro argumentos. A nova checagem de parâmetros reproduziu a falha antes da correção e passou depois dela. A recompilação dessa correção continua manual.

- Os 45 testes Python passaram, incluindo 17 verificações relacionadas à equipe. As condições são extraídas das fontes Pawn instaladas e avaliadas com doubles; blocos de atribuição verificam devolução da semente correta e liberação somente da reserva própria. A suíte cobre identidade reutilizada, colisão restrita aos scouts, reservas, journal interrompido, buscas não reiniciadas por descobertas de parceiros, proteção de movimentos especiais, vagas disponíveis, conclusão conjunta, pausa deferida durante checkpoint e palavras reservadas em parâmetros das funções do mapper e de sua API. Não executa a máquina de estados Pawn, o escalonador ou a física do motor.
- As oito fontes do mapper passaram na conferência estática de delimitadores, aridade das chamadas próprias, argumentos de formatação, globais e índices dos estados individuais. Essa conferência não substitui o compilador nem os testes no servidor.

```powershell
rtk proxy python -B -m unittest discover -s addon/advanced_npc/tools -p "test_*.py"
```

| Teste manual | Resultado esperado |
| --- | --- |
| `anpc_scan_bots 1`, depois 4 e 8, em sessões novas do mesmo mapa | Quantidade indicada por `bots`; entidades, rotas, sondagens e posições independentes |
| Poucas vagas livres, com quantidade configurada maior que o disponível | Reduz a equipe, mantendo uma vaga para administrador; sem vagas suficientes, não inicia |
| Falha de conexão/respawn durante a criação de um scout | Remove todos os clientes criados, fecha rotas e libera edição sem remover outra identidade |
| Alterar `anpc_scan_bots` durante o scan | Equipe atual permanece; próxima sessão usa a nova quantidade |
| Explorar saídas de uma região comum | Reservas distintas; nenhuma origem analisada simultaneamente por dois scouts |
| Dois scouts frente a frente, em corredor largo e depois estreito | Desvio apoiado quando possível; filtro entre parceiros permite passagem sem bloquear ou inventar conexões |
| Um scout abaixo de outro, junto a caixa, salto ou escada | Nunca ganha apoio no parceiro; salto, queda e escada continuam físicos |
| Um scout termina antes dos demais ou enquanto o survey ainda avança | Aguarda; a sessão continua até a equipe inteira esgotar o trabalho compartilhado |
| Pausar/salvar enquanto dois scouts assentam sementes consumidas fora de ordem | Cada um devolve sua semente; direções já provadas por parceiros permanecem no journal |
| Salvar durante caminhada/salto/rota e continuar | Todos congelam em âncoras; retoma sem reservar trabalho para clientes antigos |
| Pausar durante preparação inicial e pedir `save` ou `stop` | Inicialização compartilhada termina; gravação não fica presa na pausa; `save` mantém a pausa |
| Parar e depois retomar com outra quantidade de scouts | Reutiliza o journal atual; sementes, antecessores e direções independem da quantidade |
| `watch 1 1` e `watch 1 2` por administradores distintos | Câmeras independentes, corpo correto oculto e blocos próximos do scout selecionado |
| Remover qualquer scout e reutilizar sua vaga | Encerra a equipe, preserva o último checkpoint e não remove o novo ocupante |
| Encerrar por conclusão, `stop`, mudança de física ou troca de mapa | Todos os clientes/rotas/câmeras/hooks liberados; sem grafo alterado por reposicionamento |

Compare tempo até conclusão e cobertura com o mesmo BSP, perfil, survey e orçamento, primeiro com um scout e depois com quatro. Os limites de análise permanecem globais; a física e a prova imediata de cada comando somam custo indivisível. Confirme o grafo produzido com um NPC no servidor antes de avaliar o ganho de tempo.

## Revisão 1.3: áreas e portais — 01/10/2026

Recompile manualmente `anpc_mapper.sma`, `anpc_navigation.sma`, `anpc_core.sma` e `anpc_admin.sma` com as includes externas atuais, inclusive a nova `navigation_portals.inc`. Carregue os quatro juntos. O formato é `ANPC_NAV 3` e a política do journal `ANPC_SCAN 2` é `planar-regions-1`. Não houve compilação, execução dos plugins no HLDS ou medição de FPS.

- Conferência estática de 26 fontes Pawn: includes/globais, chamadas próprias e formatos/argumentos. Nenhum compilador foi invocado.
- 28 testes Python passaram: 11 do importador atualizado, 10 de geometria sobre BSPs sintéticos e sete das condições Pawn de fronteira com natives AMXX. Cobrem plano inclinado, coordenadas negativas, teto baixo, postura, buraco entre extremos válidos, parede/subdivisão e separação de pisos. Os hulls sintéticos são comparados com interseções analíticas independentes. As condições extraídas das includes são avaliadas com doubles dos contratos nativos, sem executar Pawn ou compilar plugins; os sete testes dependem das includes configuradas em `LOCAL.md` e são pulados quando elas não estão disponíveis.
- O verificador offline leu o BSP local `de_dust2`, MD5 `74d6d81b4b818b691fafd2e56a5ae362`. Entre 623 sementes de superfícies caminháveis, 125 tinham inclinação rejeitada pela regra horizontal anterior. O modelo encontrou 573 blocos válidos inclinados. O teste inclui somente a geometria estática: não executa Pawn, não inclui entidades/plugins e não mede a quantidade de áreas/portais que o scan real produzirá após união.

```powershell
python -B -m unittest discover -s addon/advanced_npc/tools -p "test_*.py"
python -B addon/advanced_npc/tools/check_nav_regions.py "CAMINHO_DO_SERVIDOR/cstrike/maps/de_dust2.bsp"
```

| Teste manual no servidor | Resultado esperado |
| --- | --- |
| `anpc_scan start new` no `de_dust2`, com `anpc_nav_show 1` e `anpc_scan status` | Áreas em terreno livre e rampas uniformes; razões de rejeição disponíveis |
| Teto de 80 unidades e passagem que exige agachar | Área em pé no primeiro caso; área agachada no segundo |
| Caixa, parede, buraco, trigger ou degrau dentro do quadrado | Subdivide ou mantém trecho detalhado; não certifica uma passagem através do obstáculo |
| Área sem pontos e câmera olhando para ela | Contorno azul aparece; `areas` independe dos nós desenhados |
| Sala convexa conectada a dois corredores | Após conclusão, portais/âncoras das entradas; NPC atravessa o interior sem cadeia de pontos |
| Fronteira entre regiões e entre pisos sobrepostos | Porta geométrica só com borda e apoio contínuos; não liga apenas por quina ou XY |
| Esperar conclusão automática | Log informa amostras removidas/portais; arquivo e journal usam IDs compactados |
| Salvar/parar antes de concluir e depois retomar | Mantém amostras e memória de exploração, sem compactação prematura |
| Continuar um scan concluído, inclusive com regiões sem nós | Revalida planos das áreas anteriores antes da exploração e preserva regiões válidas |
| Nascer e perseguir em uma região isolada sem nós | Criação e perseguição local funcionam, com postura e colisão verificadas |
| Saltos, quedas, escadas, caixa quebrada e bloqueio temporário de passagem | Mantém ações físicas, precisão e busca alternativa; não atravessa sólidos |

As verificações geométricas e de fonte não substituem esses testes de execução.

O status enviado pelo usuário após 14 minutos mostrou 647 nós, 26.690 blocos rejeitados exclusivamente por piso, zero áreas e `survey 0/0`. A fonte do AMXX confirmou dois erros na integração: `get_tr2(..., TR_pHit)` retorna `FM_NULLENT` (-1) para worldspawn por meio de `FNullEnt`; `fread(..., BLOCK_INT)` retorna quatro bytes, enquanto `fread_blocks` retorna a quantidade de blocos. As comparações anteriores com índice zero e leitura de um elemento impediam a aprovação de áreas e a inicialização dos limites do BSP. As consultas de parede do mapper usavam o mesmo índice incorreto e também foram corrigidas.

Essa correção exige recompilação manual somente de `anpc_mapper.sma`, com `mapper_coverage.inc`, `mapper_world.inc`, `mapper_exploration.inc` e `mapper_storage.inc` atuais. Não altera o formato de arquivo nem APIs. Recarregue o plugin/mapa para reler o BSP; `anpc_scan start new` permite avaliar a geração corrigida sem as tentativas já encerradas. Confira áreas abertas, `Floor probe failures` e `Survey: enabled=1 valid-BSP-bounds=1`. O total da varredura depende das dimensões do BSP e `anpc_scan_survey`; quando habilitada com limites válidos, deve ser maior que zero. Falhas de piso ainda são esperadas perto de paredes, degraus, buracos e entidades. Não houve nova compilação nem validação em execução dessa correção.

## Histórico das revisões anteriores em 30/09/2026

- Pesquisa das interfaces do YaPB e ReAPI/AMXX, com consulta às includes do ambiente configurado do projeto.
- Leitura do modelo studio v10 `zpn_z_default.mdl`: 111 sequências; confirmação dos sete labels usados pelo tipo inicial.
- Conferência estática das chamadas, registro dos natives próprios e integridade de delimitadores nas fontes.
- Compilação dos seis plugins, incluindo `anpc_mapper`, com `amxxpc.exe` (AMXX 1.10.0.5467), usando as includes externas do ambiente local: zero erros e zero avisos.
- Correção da criação do fake client: `set_entvar` e as funções de jogador da ReAPI só são chamadas após `ClientPutInServer` e confirmação de private data. A conexão recebe o tamanho do buffer de rejeição; a rotina também registra o fake client no AMXX quando necessário e remove conexões incompletas ao liberar a sessão.
- Correção do encerramento imediato na revisão `1.1.2`: o ReGameDLL escreve `iuser4` durante `PreThink`, invalidando o antigo marcador. A identidade agora usa vaga/`userid`, conexão, private data e estado de bot. O marcador foi removido da API e da percepção; a sessão já exige zero NPCs e bloqueia sua criação. Os encerramentos registram motivo/etapa e a perda de identidade inclui seus campos de diagnóstico. Os seis plugins foram recompilados com zero erros e zero avisos; a validação no jogo dessa revisão permanece manual.
- Correção do parâmetro reservado `state` na rotina de troca de estado, dos índices sem tag `AnpcAnimation` e da indentação na include local `advanced_npc/movement.inc`.
- 11 testes Python do importador: ULZ com overlap e comprimentos estendidos, limites de saída, arquivo truncado, header/versão/tamanho inválidos, conversão de agachamento, saltos calculados, ações sem implementação, vínculo ao mapa, CLI e proteção contra sobrescrita.
- Importação de um grafo real da base oficial do YaPB para o BSP `de_dust2` local, com tamanho correspondente e MD5 gravado.

A compilação foi executada por solicitação explícita do usuário. Os seis binários `.amxx` e seus logs estão em `compiled/advanced_npc/`. A validação em execução do scanner permanece pendente para os testes manuais do usuário; a tentativa de preparar um HLDS isolado foi encerrada a pedido dele. Compilar sem erros não valida física, carregamento, cobertura nem combate no HLDS. Nenhuma integração do scanner foi mantida em `core/zpn_main.sma`.

Para localizar o compilador e as includes desta máquina, consulte `AMXX_COMPILER`, `AMXX_INCLUDE_DIR` e `ANPC_INCLUDE_DIR` em `addon/advanced_npc/LOCAL.md`. A [preparação do ambiente local](../README.md#ambiente-local) e o [modelo público](../LOCAL.example.md) descrevem como preencher esse arquivo em outra máquina. A compilação continua manual e só deve ser executada pelo Codex quando solicitada explicitamente pelo usuário.

## Visualização de navegação: validação manual

A seleção por câmera foi conferida na revisão anterior de `anpc_admin.sma`. A revisão 1.2 também desenha áreas do provedor; recompile os quatro consumidores indicados abaixo e carregue os binários atualizados. A revisão atual não foi compilada nem executada no HLDS.

Foram conferidos os delimitadores da fonte, os campos de `TE_BEAMPOINTS`, as guardas dos limites de seleção e a disponibilidade das novas interfaces nas includes locais. As expressões do filtro extraídas da fonte passaram em 10.100 casos de posição, yaw, pitch, frente/trás e alcance, comparadas com uma referência angular independente em Python. Essa conferência matemática não executa Pawn nem a câmera do cliente.

| Cenário | Resultado esperado |
| --- | --- |
| Ativar `anpc_nav_show 1` com nós à frente e atrás | Apenas nós no cone frontal; largura atual 10, ligações acima do piso e até oito retângulos azuis selecionados independentemente dos pontos |
| Girar 180 graus sem andar | Seleção acompanha a nova direção na atualização seguinte, em até 0,2 segundo |
| Olhar para cima/baixo ou agachar | Filtro acompanha pitch e posição dos olhos, sem inverter a direção |
| Mais de 32 nós à frente, com IDs em ordem diferente das distâncias | Os 32 nós mais próximos da câmera ocupam o limite; HUD/destaque correspondem ao primeiro |
| Morrer, entrar em spectator e depois renascer com o desenho ligado | Desenho continua e troca a referência de visão automaticamente |
| Spectator em câmera livre longe do corpo | Usa a câmera atual, sem desenhar apenas perto da posição da morte |
| Spectator em primeira pessoa; observado olha para o lado oposto ao admin | Usa os olhos e a direção do jogador observado; mensagens continuam somente para o admin |
| Trocar o jogador observado ou perder o alvo | Atualiza a referência na próxima passagem, sem consultar jogador desconectado |
| Perseguição livre/travada perto de paredes | Aproxima a posição padrão de perseguição, sem projetar o recuo através do mapa; alterações de distância/autodirector seguem a limitação descrita em `NAVIGATION.md` |
| Usar as câmeras de entidade do addon, inclusive frontal e superior | Desenho segue posição/ângulos da entidade de câmera |
| Nenhuma âncora no cone/alcance | HUD mostra `-1`; áreas visíveis continuam desenhadas independentemente |
| Desativar com `anpc_nav_show 0` ou desconectar e reutilizar a vaga | Atualizações encerradas; beams existentes expiram em 0,6 segundo; novo jogador começa com desenho desligado |

## Histórico das conferências do scanner 1.2

A revisão 1.2 altera mapper, provedor, núcleo e administrador, com as includes externas configuradas no projeto e a nova `navigation_areas.inc`. Recompile manualmente `anpc_mapper.sma`, `anpc_navigation.sma`, `anpc_core.sma` e `anpc_admin.sma`. Não houve compilação, execução no HLDS ou medição de FPS nesta revisão. O `.nav` atual é `ANPC_NAV 2`; regenere mapas antigos ou reimporte os grafos YaPB. A memória permanece `ANPC_SCAN 2`, com política atual `sparse-walk-1`. Para substituir os pontos densos anteriores, comece com `anpc_scan start new`.

A redução de densidade altera somente o mapper e suas includes internas `mapper_motion.inc`, `mapper_world.inc` e `mapper_exploration.inc`. O padrão de `anpc_scan_spacing` passa a 128; a gravação periódica fora das áreas usa o espaçamento completo, em vez de três quartos limitados a seis passadas, e a prova terrestre admite até dezesseis amostras. Recompile esse plugin após a alteração, carregue o binário e confira também a configuração do servidor. A mudança de assinatura descarta a memória anterior, mas não remove os nós de um grafo retomado. Pontos precisos e provas de hull/piso permanecem necessários. Não houve compilação nem execução no HLDS desse ajuste.

A conferência auxiliar desse ajuste verificou a coerência de configuração/constantes, delimitadores das quatro fontes alteradas e preservação integral do corpo da prova geométrica. Também passaram 791 combinações de espaçamento de 48 a 160 e `sv_stepsize` de 8 a 32: o intervalo com um comando de até 50 ms a 320 unidades/s e o adiamento da chegada com tolerância de 12 unidades cabem no limite de dezesseis amostras. Esses são limites matemáticos e checks de fonte; não executam Pawn, traces ou a física do HLDS.

Conferências realizadas nesta revisão:

- 11 testes existentes do importador passaram, incluindo o header `ANPC_NAV 2`, conversão, limites, arquivos inválidos e proteção contra sobrescrita.
- Conferência estática de 25 fontes Pawn de navegação, mapper, núcleo e administrador: delimitadores, resolução de globais/funções próprias, quantidades de argumentos e 99 chamadas com formatos/argumentos. Nenhum compilador foi invocado.
- Conferência auxiliar de expressões de limite, contenção e união extraídas das fontes: 12.000 adições de quadrados comparadas à união independente das células fornecidas, nas duas capacidades de postura; 351 registros de áreas salvos/recarregados preservaram IDs e contagem. Inclui coordenadas negativas/grandes, colisões do índice, pisos sobrepostos, limites semiabertos, flags inválidas e um buraco em L que não pode ser preenchido.
- 35 combinações de altura de caixa/recuo verificadas por equações balísticas, com limites de velocidade e passagem pela face expandida do hull. O caso de 80 unidades sob o perfil usual exige recuo maior que 48; a lista atual inclui 72, 96 e 128. A geometria diferencia agachamento no chão, que preserva os pés, de agachamento no ar, que preserva o centro e eleva os pés.
- Postura e ordem de salto/agachamento conferidas na implementação de [PM_Jump/PM_Duck do ReGameDLL](https://github.com/rehlds/ReGameDLL_CS/blob/master/regamedll/pm_shared/pm_shared.cpp) e nas assinaturas ReAPI instaladas. A penalidade de saltos consecutivos é aguardada naturalmente, sem alterar a velocidade ou o temporizador do jogador.

Essas conferências auxiliares não executam Pawn, traces, a máquina de estados ou a física do HLDS. Os cenários abaixo precisam de validação no mapa real, especialmente as aterrissagens e a retomada após ações de obstáculos.

### Conferências anteriores de exploração e rampas

A conferência estática do mapper passou para as oito fontes Pawn, incluindo `ground.inc`: delimitadores, funções e variáveis referenciadas, natives próprios, 49 chamadas com formatos/argumentos, sete campos do registro de nó `ANPC_SCAN 2` e protocolo do beam com trace separado. A propriedade angular do ajuste de parede foi conferida em 288.008 combinações de setor/ângulo. Também foram conferidos delimitadores, globais e quantidades de argumentos das chamadas próprias nos três consumidores de terreno: mapper, navegação e núcleo.

Uma conferência auxiliar em Python comparou modelos dos algoritmos com referências independentes: 5.512 segmentos em precisão float32 contra interseções racionais exatas da grade, e 2.000 grafos direcionados contra cálculo completo dos menores custos e da pontuação de fronteiras. Passaram os casos de coordenadas negativas/grandes, direções quase alinhadas a um eixo, cantos, bordas da grade, limite de travessia, decrease-key do heap e parada antecipada. Também foram conferidos spans sobrepostos, rejeição de blocos pendentes/obsoletos, sobreposição das faixas de hull, ausência de mutação de grafo e exclusão da cobertura do journal.

A preparação de retornos em grafos existentes passou por mais 1.000 grafos direcionados, comparando os antecessores escolhidos com o conjunto de arestas de entrada elegíveis. Foram preservados antecessores existentes, tentativas encerradas e nós desabilitados; IDs estritamente menores impediram ciclos. A fonte dessa preparação usa apenas consultas de grafo, sem gravar inversas presumidas.

Esses checks anteriores verificaram propriedades matemáticas e referências nas fontes daquela revisão; não executaram Pawn, a máquina de estados nem a física do HLDS. A antiga exclusão do overlay da criação de arestas foi substituída pela prova simétrica restrita ao piso estático plano. Corpo, câmera, beam, cobertura e seleção precisam de validação no servidor.

A revisão de rampas passou por modelos auxiliares com 12.000 planos/orientações, comparando a altura de apoio com o máximo dos quatro cantos do footprint, e 5.000 combinações de velocidade/intervalo, verificando a distância acumulada das passadas. Foram conferidos 15 cenários de terreno: rampas longas/subida/descida, limite de inclinação, degraus de 18/24 unidades, parede, buraco largo, tetos em pé/agachado, cristas e elevação triangular. Incluem a necessidade de preservar uma âncora na crista, a elevação parcial sob teto, a diferença do teste de cantos em rampas diagonais e a limpeza da flag temporária sem alterar outras flags. São modelos de geometria e conferências de fonte; não medem velocidade/FPS e não reproduzem integralmente a física ou os callbacks do motor.

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
| Corredor aberto longo | Percursos de até três espaçamentos; pontos intermediários somente fora da cobertura plana ou em transições; nenhuma volta automática após cada segmento |
| Corredor reto sem áreas, `sv_stepsize 18` e espaçamento 128 | Intervalo periódico de 128 unidades, sujeito ao frame de movimento; raio de reaproveitamento comum de 96, com prova de passagem e apoio |
| Destino próximo após atingir o intervalo periódico | Dispensar o ponto imediatamente anterior à chegada apenas quando o trecho restante cabe na prova limitada; chegada ainda registrada ou reutilizada |
| Destino distante ou piso com `sv_stepsize` menor | Preservar âncoras intermediárias conforme o limite de prova; não gravar uma ligação sem amostras suficientes |
| Nó próximo através de parede, buraco ou crista | Não reutilizar apenas pela distância; manter nós separados se hull ou apoio do segmento gravado falhar |
| Rampa longa que permite andar sem saltar, nas duas direções | Apoios medidos pelo hull, alvos longos e ausência de saltos/agachamento apenas por causa da inclinação; subida total pode superar um degrau/salto |
| Rampa uniforme com grande variação de Z | Nós pelo espaçamento XY, sem gerar outro nó a cada 14 unidades de subida; arestas só após travessia real |
| Entrada/saída da rampa, crista ou elevação estreita | Âncora antes da mudança importante do piso; ligações não cortam a elevação por dentro |
| Rampa sob teto que exige agachamento | Usar o hull agachado e a folga disponível, sem exigir uma elevação inteira de 18 unidades nem atravessar o teto |
| Rampa termina numa parede, buraco ou degrau alto | Avançar apenas pelo trecho apoiado, preservando a análise posterior do obstáculo; nenhum apoio presumido além da borda |
| Laser e `watch` numa subida/descida | Pitch acompanha a altura do destino e o movimento, limitado a ±45 graus |
| Sala plana larga | Retângulos azuis, registros `A` salvos e poucos pontos de entrada/saída; amostras periódicas interiores dispensadas; nenhuma nova varredura do mesmo interior |
| Quadrados vizinhos, uma parede em L ou pisos distintos | Unir somente retângulos compatíveis, sem preencher o espaço atrás da quina, buracos ou outro andar |
| Âncoras comuns próximas | Reutilizar somente com hull/apoio válidos; concluir fisicamente na posição reutilizada antes de analisar a próxima saída |
| Âncoras precisas de salto, escada ou crista | Preservar coordenadas necessárias e tolerância curta; nenhuma união através de paredes ou mudança de piso |
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
| `.nav` atual existente com ligações de ida, sem journal correspondente | Preparação incremental de voltas para nós sem antecessor; saltos, quedas e regiões detalhadas mantêm retorno físico |
| Ida real inteiramente em cobertura plana estática | Inversa de caminhada acrescentada pela prova simétrica, sem outra volta; contador correspondente sobe |
| Grafo existente com ciclos, nós desabilitados ou retornos já encerrados | Antecessores adotados sempre têm ID menor; nós desabilitados e tentativas encerradas não são reagendados |
| Queda cuja volta não funciona | Volta rejeitada uma vez, preservando apenas as ligações fisicamente verificadas |
| Sétima saída com volta pendente | Última vaga reservada à tentativa de retorno, respeitando oito saídas por nó |
| Parede ou quina | Ausência de conexões que cortem sólidos |
| Piso descontínuo/buraco | Não gerar ligação de caminhada só porque o hull horizontal passa |
| Passagem baixa | Agachar; altura dos pés preservada; flags coerentes |
| Degraus | Pontos intermediários e caminhada dentro dos limites do motor |
| Caixa curta antes do alvo distante, acessível por salto | Candidatos locais sobre o topo; salto real e aterrissagem estável; `E` com flag `1` e velocidade observada |
| Caixa alta junto ao scout | Recuar o suficiente, validar todo o apoio da aproximação e acumular velocidade antes de saltar; não insistir decolando contra a face |
| Buraco no meio da corrida de preparação | Não usar a corrida apenas porque seus dois extremos e o hull horizontal são livres |
| Caixa acima da altura/velocidade admitida | Nenhuma ligação artificial nem pontos precisos deixados por tentativas sem aterrissagem útil |
| Salto seguido rapidamente por outra caixa | Aguardar a penalidade natural de salto na aproximação; não rejeitar a segunda caixa apenas por redução temporária de altura |
| Salto com leve agachamento no ar | Primeiro comando sai com postura da origem, depois agacha; pés ganham folga sem velocidade injetada; levantar após pousar quando houver espaço |
| Chegada da caixa sob teto baixo, com origem em pé | Não agachar prematuramente no chão; agachar no ar e permanecer baixo na chegada |
| Permanecer vários frames após uma aterrissagem | Registrar a travessia uma vez; sem recapturar a antiga decolagem nem criar grupo de nós juntos |
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
| Salvar, recarregar e continuar | `.nav` versão 2 conserva nós, áreas e conexões; `.scan` e relatório confirmados; nova sessão reconstrói certificados a partir do mundo atual |
| Abrir `.nav` antigo ou `A` inválido/duplicado/fora da célula | Arquivo rejeitado integralmente; regenerar/reimportar no formato atual |
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

Para comparar a exploração, use o mesmo BSP, parâmetros, posição inicial e orçamento de CPU. Observe tempo até esgotar candidatos, nós/conexões/áreas, regiões cobertas e as distâncias `explore` e `travel/return`, junto com `pruned bearings`, `skipped interior trials`, `cost-ranked targets`, `suppressed node samples`, `symmetric floor returns` e `local landings`. Amostras dispensadas não equivalem a nós removidos. Um tempo menor com áreas ausentes não representa melhora de cobertura. A medição de ganho e a validação dos saltos/escadas continuam dependendo do servidor real. A escolha das técnicas e suas limitações estão em [MAPPING_STRATEGY.md](MAPPING_STRATEGY.md).

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
| NPC e alvo dentro do mesmo retângulo | Movimento direto pelo interior com hull atual; sem seguir todos os pontos comuns da rota |
| Rota com retângulo seguido de salto/queda, escada ou ponto preciso | Simplificação termina na transição; aproximação até quatro unidades antes de saída aérea |
| Sólido novo dentro de área salva | Hull e física bloqueiam a passagem; nenhum movimento através do sólido |
| Jogador atrás de parede, em outra região conectada | Planeja caminho e segue os corredores |
| Escadas/degraus | Usa as regras de step height do motor |
| NPC numa rampa com Think/passo longo | Completa a distância solicitada em partes menores antes de desviar; sem ganhar velocidade além do perfil |
| Rampa diagonal caminhável pelo jogador | Passada curta pode usar a recuperação de apoio; colisão com paredes/atores permanece e a flag acrescentada é limpa após a chamada |
| Bloqueio, piso sem apoio ou rampa acima do limite | Não aplicar recuperação de apoio indevida nem ultrapassar o obstáculo por ela |
| Descida de rampa marcada como queda no grafo | Andar quando o trecho tem apoio contínuo; uma queda real continua usando movimento aéreo |
| NPC morre, é removido ou muda de estado durante um passo | Interromper as partes restantes e evitar alterar outra entidade/serial ou sobrescrever a animação de ataque |
| Túnel agachado | Ajusta hull; só levanta com espaço |
| Salto marcado | Calcula e verifica o arco; mantém gravidade e colisão durante o salto |
| Referência aprendida colide, mas o salto completo do perfil cabe | Tentar solução com limite vertical do perfil, sem copiar a referência cegamente |
| Caixa que exige salto e agachamento no ar | Tentar salto normal primeiro; usar hull menor conservando o centro quando necessário e permitido; levantar somente com espaço |
| Destino baixo de um salto iniciado em pé | Postura de lançamento vem da origem, preservando a folga do agachamento no ar |
| Arco inviável para esse perfil | Consultas limitadas a cada 0,2 s e recuperação por falta de progresso; sem repetir dezenas de traces a cada Think |
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
