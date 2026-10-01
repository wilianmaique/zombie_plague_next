# Estratégia de exploração e cobertura

## O que causava as voltas

A memória anterior era principalmente por nó: oito setores horizontais, visitas e antecessor. Um nó novo dentro de uma sala já percorrida podia iniciar outra série de tentativas sobre o mesmo interior. Conhecer pontos próximos não significava conhecer a região entre eles. Além disso, a escolha remota usava distância em linha reta, sem calcular o desvio exigido pelo grafo, e um ponto conhecido próximo podia encurtar um alvo mais distante que ainda continha espaço desconhecido.

A árvore de descoberta resolve a continuidade e adia a volta imediata, mas não resolve sozinha a redundância geométrica entre muitos nós na mesma sala. A representação atual combina retângulos de piso livre, âncoras de transição e custo de acesso às fronteiras. O resultado geométrico serve tanto à exploração quanto ao movimento dos NPCs.

## Técnicas examinadas

| Técnica | Ideia e aplicação neste mapper |
| --- | --- |
| Exploração por fronteiras | Procurar a transição de espaço conhecido para desconhecido. Orienta a seleção de saídas, em vez de repetir tentativas uniformemente em todos os pontos. |
| Células de cobertura / boustrophedon | Dividir espaço navegável em células e varrer cada uma em faixas. É útil quando a tarefa exige que o robô passe fisicamente por toda a superfície. Aqui as leituras geométricas podem analisar um interior sem percorrê-lo inteiro. |
| Fronteiras incrementais com custo e ganho | Manter trabalho pendente e escolher destinos considerando acesso e informação nova. Orienta a separação entre análise incremental, escolha de destino e rota de deslocamento. |
| Heightfield / navmesh | Representar pisos e regiões caminháveis, inclusive com alturas sobrepostas. O projeto usa uma parte dessa ideia: retângulos planos certificados com âncoras explícitas para ligar regiões e executar movimentos especiais. |

A exploração por fronteiras foi descrita por [Yamauchi (1997)](https://www.cs.cmu.edu/~motionplanning/papers/sbp_papers/integrated2/yamauchi_frontier_explor.pdf). A decomposição para cobertura física aparece em [Choset e Pignon](https://publications.ri.cmu.edu/coverage-path-planning-the-boustrophedon-decomposition). O [FUEL](https://arxiv.org/abs/2010.11561) apresenta estruturas incrementais de fronteiras e planejamento hierárquico para exploração rápida. O [heightfield do Recast](https://recastnav.com/structrcHeightfield.html) documenta células com spans de altura para representar o espaço caminhável. Esses trabalhos são referências conceituais; não houve importação de seus códigos, modelos de robô ou resultados de desempenho.

Para o objetivo deste projeto, a escolha é uma combinação de **blocos adaptativos, fronteiras e custo de rota**. A decisão de não exigir uma varredura física completa de cada sala é específica do mapper: o produto final precisa de uma topologia útil com passagens comprovadas, e o motor já fornece consultas de colisão. Isso não elimina a necessidade de testar movimentos especiais.

## Estrutura implementada

1. Uma âncora conhecida inicia um quadrado de 256 unidades. Piso e faixas de hull são examinados por etapas. Irregularidades fazem a análise descer para 128, 64 e 32 unidades, na região dessa âncora.
2. Um bloco aberto compartilha seu resultado com todos os nós do mesmo piso. Uma direção só é dispensada por cobertura se o segmento inteiro passa por células analisadas, preservando cantos e bordas desconhecidos.
3. Alturas distintas no mesmo XY são registros separados. Escadas, triggers, portas, quebráveis e outras regiões sensíveis mantêm provas detalhadas; degraus, rampas, buracos e falta de espaço também impedem a classificação plana.
4. A varredura local prioriza amostras desconhecidas antes da continuidade da direção. Só reutiliza uma âncora distante quando ela não corta o alcance do alvo; um nó próximo deixa de provocar voltas curtas repetidas.
5. Um Dijkstra incremental calcula custos sobre arestas direcionadas existentes, com heap de prioridade e parada por limite inferior. A pontuação combina custo, trabalho restante e visitas. O A* do provedor continua produzindo a rota efetiva.
6. Uma tentativa que retorna para um interior conhecido pode ser dispensada quando já existe uma rota suficientemente curta até sua âncora. Rotas ausentes ou desvios longos mantêm a tentativa para descobrir conexões e atalhos.
7. Novas fronteiras alcançáveis precedem a manutenção de ligações inversas. Após uma ida real em cobertura estática plana, a prova simétrica permite gravar a caminhada de volta; fora dela, o fake client continua executando o retorno.
8. Retângulos são persistidos no `.nav`, usados para dispensa de pontos intermediários e simplificação do caminho do NPC. A união exige a mesma extensão transversal, contato por uma borda, altura/postura compatíveis e a mesma célula espacial de 256 unidades. Não preenche formas em L, buracos ou espaços entre ilhas.
9. Âncoras próximas são reaproveitadas somente com provas de acesso e apoio. Saltos, escadas, bordas e cristas mantêm precisão. Pontos de decolagem só são acrescentados depois de aterrissagem útil, evitando grupos deixados por saltos fracassados.

O grafo continua fornecendo conectividade ao A*. Áreas certificadas não ligam componentes separados automaticamente. Movimentos observados fornecem arestas de ida e a cobertura estática plana permite sua caminhada inversa; movimentos especiais precisam de execução física. A geometria derivada é invalidada após ações de obstáculo do mapper e reconstruída ao retomar uma sessão; o journal conserva o trabalho por nó e a árvore de descoberta.

Um grafo existente também passa por uma preparação incremental de retornos: uma ligação de ida sem inversa pode fornecer o antecessor de um nó que ainda não tenha um. IDs estritamente menores impedem ciclos; essa preparação agenda uma tentativa física, sem acrescentar a ligação. Assim, dispensar interiores conhecidos não elimina a manutenção de voltas quando o journal está ausente.

## O que esperar e como medir

A hipótese de ganho é reduzir a distância de exploração repetida em interiores planos e evitar deslocamentos a destinos que parecem próximos, mas têm acesso caro. Mapas com muitas rampas, escadas, triggers ou corredores onde não cabe um bloco podem aproveitar menos essa redução. Ainda haverá trânsito por áreas conhecidas e retornos necessários para conectar o grafo corretamente.

Rampas continuam fora dos blocos planos, mas recebem acompanhamento de apoio por hull e alvos contínuos no mapper. A amostragem limita o desnível local e preserva mudanças relevantes do piso, sem transformar cada pequena subida numa nova âncora. Caixas recebem alvos locais sobre seu topo e recuos de decolagem com apoio verificado; a corrida acumula velocidade real antes do comando de salto. As mesmas posições precisas permitem ao NPC tentar salto normal ou com agachamento no ar.

Um bloco azul significa que ele passou nos testes geométricos desta sessão, na resolução adotada. Não significa “100% de qualquer detalhe do BSP”. As amostras de piso continuam discretas; detalhes menores que sua resolução e ações próprias de scripts precisam de validação no mapa real. Uma navmesh completa também precisaria representar esses movimentos e ações.

Compare a revisão anterior e a atual com o mesmo BSP, parâmetros, posição inicial e orçamento. Registre tempo, distâncias `explore` e `travel/return`, regiões descobertas, ligações úteis e contadores de tentativas dispensadas. Verifique especialmente saídas estreitas, plataformas acessíveis por salto, pisos sobrepostos e passagens após quebrar uma caixa. Mais rapidez com perda dessas regiões não satisfaz o objetivo.

As conferências matemáticas e estáticas estão em [TESTING.md](TESTING.md). Não há medição de ganho, execução no HLDS ou compilação desta revisão; essas etapas ficam para o teste manual do usuário.
