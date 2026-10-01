# Referências e decisões de API

## Combate e desenho — revisão 1.7, 01/10/2026

- [Renderer studio do SDK da Valve](https://github.com/ValveSoftware/halflife/blob/master/cl_dll/StudioModelRenderer.cpp): estima frame a partir de `animtime`, `framerate`, FPS e flag de repetição, além de interpolar modelos `MOVETYPE_STEP`. O core conserva relógio consistente e impede repetição prevista de execuções únicas.
- [GetSequenceInfo](https://github.com/ValveSoftware/halflife/blob/master/dlls/animation.cpp) e [studio v10](https://github.com/ValveSoftware/halflife/blob/master/engine/studio.h): quantidade de frames, flags e deslocamento linear usados para cadência nominal. O modelo padrão instalado foi lido como fixture binária; seu ataque de faca tem flag de repetição.
- [Datagramas no ReHLDS](https://github.com/rehlds/ReHLDS/blob/master/rehlds/engine/sv_main.cpp): descarte de dados não confiáveis quando excedem o espaço disponível. A fila do visualizador reduz a rajada anterior; o motivo de desaparecimento em jogo ainda requer logs/medição.
- [DropToFloor no ReHLDS](https://github.com/rehlds/ReHLDS/blob/master/rehlds/engine/pr_cmds.cpp): -1 para all-solid, 0 sem contato e 1 para piso encontrado. A criação aceita somente 1.
- [dtPathCorridor](https://recastnav.com/classdtPathCorridor.html): ajuste de corredor/posição durante o movimento, como referência conceitual para separar percurso global, aproximação e ações locais. Não foi adicionada dependência Detour.

A pesquisa inicial de `message_begin` na API indicada pelo projeto não retornou conteúdo acessível. As assinaturas e o tempo de permanência do HUD foram conferidos nas includes locais `amxmodx.inc`, `file.inc` e `fakemeta_const.inc`, preservando os módulos já usados. [COMBAT_REVIEW.md](COMBAT_REVIEW.md) explica a implementação e seus limites.

## Ambiente e consultas iniciais

Consultas realizadas em 30/09/2026. Foram examinadas as includes locais do servidor configurado em `.vscode/settings.json`: AMXX 1.10 e ReAPI 5.26.0.338. A referência disponibilizada pelo projeto também indexava ReAPI 5.29.0.358. As interfaces empregadas existem nas includes locais e foram comparadas com a documentação e/ou fonte do provedor.

## YaPB

Revisão consultada: `4967a220ba3a58c461ee1cef8b6fb37c6fd93b5e`.

- [graph.h](https://github.com/yapb/yapb/blob/4967a220ba3a58c461ee1cef8b6fb37c6fd93b5e/inc/graph.h): nós, flags, `Path`, `PathLink`, `StorageHeader` e `ExtenHeader`.
- [storage.cpp](https://github.com/yapb/yapb/blob/4967a220ba3a58c461ee1cef8b6fb37c6fd93b5e/src/storage.cpp): formato binário atual e ULZ.
- [navigate.cpp](https://github.com/yapb/yapb/blob/4967a220ba3a58c461ee1cef8b6fb37c6fd93b5e/src/navigate.cpp): caminhos, recuperação, obstáculos, saltos e tratamento próprio de elevadores.
- [crlib ULZ](https://github.com/yapb/crlib/blob/92abc88773c710eedd8299a5ae86d1d94d9f7d22/crlib/ulz.h): descompressão e codificação aditiva de comprimentos.
- [Banco de grafos](https://github.com/yapb/graph/tree/19b802d42fbdadabd3205fb767c8ea59d976a7de): origem do exemplo `de_dust2`, autor `$_Vladislav`.

Os plugins Pawn são uma implementação própria para entidades. O importador reproduz a interpretação do formato e a descompressão ULZ em Python, com validações de tamanho e índices. Avisos de licença constam em `THIRD_PARTY_NOTICES.md`.

## ReAPI e AMXX

- [Pesquisa fornecida pelo projeto](https://amxx-api.csrevo.com/search.json?q=SetThink).
- [SetThink](https://amxx-api.csrevo.com/reapi-5-26-0-338/reapi_gamedll/function/SetThink): callback específico de entidade, evitando um loop global de Think.
- [rg_create_entity](https://amxx-api.csrevo.com/reapi-5-26-0-338/reapi_gamedll/function/rg_create_entity): argumento `useHashTable = false` necessário para depois alterar classname sem deixar entradas nessa tabela.
- [Fonte oficial ReAPI](https://github.com/rehlds/ReAPI/blob/master/reapi/extra/amxmodx/scripting/include/reapi_gamedll.inc): `rg_remove_entity`, `rg_find_ent_by_class`, callbacks e hooks de rodada.
- [Fonte oficial engine ReAPI](https://github.com/rehlds/ReAPI/blob/master/reapi/extra/amxmodx/scripting/include/reapi_engine.inc): acesso tipado a entvars.
- [AMXX oficial](https://github.com/alliedmodders/amxmodx/tree/master/plugins/include): arquivos, `hash_file`, cvars vinculadas, `Array`, forwards, Fakemeta e Hamsandwich.
- [Leitura binária do AMXX](https://github.com/alliedmodders/amxmodx/blob/master/amxmodx/file.cpp): `fread` retorna bytes lidos; `fread_blocks` retorna blocos completos. Uma leitura `BLOCK_INT` completa retorna 4 no primeiro e 1 no segundo. Contrato conferido na correção dos limites do BSP em 01/10/2026.
- [Resultado de trace do Fakemeta](https://github.com/alliedmodders/amxmodx/blob/master/modules/fakemeta/fm_tr2.cpp) e [FNullEnt no SDK](https://github.com/alliedmodders/hlsdk/blob/master/dlls/util.h): worldspawn tem offset zero e `get_tr2(..., TR_pHit)` o converte para -1. Aprovar mundo exige também fração de contato e normal válidas; o índice sozinho não prova apoio. Contrato conferido na correção de áreas e paredes em 01/10/2026.
- [Câmera atual na ReAPI](https://github.com/rehlds/ReAPI/blob/master/reapi/src/natives/natives_common.cpp): `get_viewent` consulta a entidade de visão do cliente. A assinatura existe na include local `reapi.inc`; `m_hObserverTarget` existe em `reapi_gamedll_const.inc` e identifica o jogador acompanhado por um spectator.
- [Visão no SDK GoldSrc](https://github.com/ValveSoftware/halflife/blob/master/cl_dll/view.cpp): câmeras de entidade usam `origin`/`angles`; primeira pessoa acompanha o alvo, perseguição livre usa os ângulos do espectador e perseguição travada usa os ângulos do alvo com pitch invertido. O recuo de perseguição é calculado no cliente, com distância padrão de 112 unidades. [Movimento de spectator no ReGameDLL](https://github.com/rehlds/ReGameDLL_CS/blob/master/regamedll/pm_shared/pm_shared.cpp) mantém no servidor a posição do alvo para o PVS, sem fornecer a posição final da câmera de perseguição.
- [Ciclo de carga do AMXX](https://github.com/alliedmodders/amxmodx/blob/master/amxmodx/meta_api.cpp): todos os `plugin_precache` executam antes dos `plugin_init`. O núcleo limita o registro de tipos/animações à fase de precache.
- [Física ReHLDS](https://github.com/rehlds/ReHLDS/blob/master/rehlds/engine/sv_phys.cpp): movimento terrestre/velocidade, gravidade, fly e toss.
- [Física de jogador ReGameDLL](https://github.com/rehlds/ReGameDLL_CS/blob/master/regamedll/pm_shared/pm_shared.cpp): comandos de jogador, salto, agachamento e movimento em escadas usados pelo fake client.
- [Hook de entidades físicas na ReAPI](https://github.com/rehlds/ReAPI/blob/master/reapi/extra/amxmodx/scripting/include/reapi_engine_const.inc): `RH_SV_AllowPhysent(entity, client)` retorna `bool`. O [ReHLDS chama o hook antes de acrescentar a entidade ao movimento](https://github.com/rehlds/ReHLDS/blob/master/rehlds/engine/sv_user.cpp). O mapper usa esse filtro somente entre membros com identidade válida da equipe, sem modificar `solid`, grupos de colisão ou a física do mapa.
- [Passos e apoio no ReHLDS](https://github.com/rehlds/ReHLDS/blob/master/rehlds/engine/sv_move.cpp): `SV_movestep` eleva a consulta vertical por `sv_stepsize`; `SV_CheckBottom` verifica o centro e os quatro cantos. Esses testes explicam por que uma passada longa ou uma rampa diagonal pode falhar para uma entidade enquanto o jogador encontra uma passagem. `FL_PARTIALGROUND` permite a recuperação de apoio usada pelo núcleo, somente após sua prova de piso inclinado e hull.
- [Colisão de hull no ReHLDS](https://github.com/rehlds/ReHLDS/blob/master/rehlds/engine/world.cpp): `SV_RecursiveHullCheck` pode sair de um sólido inicial e encontrar um contato posterior. A consulta de piso exige fração positiva quando isso ocorre e normal caminhável; as consultas de passagem permanecem estritas. As poses e as passagens ainda são verificadas por hull, inclusive quando piso e teto pertencem a brushes diferentes.
- [PreThink do jogador no ReGameDLL](https://github.com/rehlds/ReGameDLL_CS/blob/master/regamedll/dlls/player.cpp): escreve `pev->iuser4` como estado de contato com veículos a cada processamento. A identidade do scout usa vaga/`userid` e não modifica esse campo. [Movimento no ReHLDS](https://github.com/rehlds/ReHLDS/blob/master/rehlds/engine/sv_user.cpp) copia os campos `iuser*` entre o edict e `pmove`.
- [Fakemeta do AMXX](https://github.com/alliedmodders/amxmodx/blob/master/plugins/include/fakemeta_const.inc): assinaturas de `CreateFakeClient`, `RunPlayerMove`, hulls e callbacks da DLL.
- [Criação do fake client no ReHLDS](https://github.com/rehlds/ReHLDS/blob/master/rehlds/engine/pr_cmds.cpp): `CreateFakeClient_internal` aloca o cliente/edict; [ClientPutInServer no ReGameDLL](https://github.com/rehlds/ReGameDLL_CS/blob/master/regamedll/dlls/client.cpp) constrói a instância de jogador. [Validação de set_entvar na ReAPI](https://github.com/rehlds/ReAPI/blob/master/reapi/src/natives/natives_members.cpp) exige private data. [Despacho Fakemeta](https://github.com/alliedmodders/amxmodx/blob/master/modules/fakemeta/dllfunc.cpp) exige `charsmax(rejection)` em `DLLFunc_ClientConnect` e usa o buffer de userinfo do motor em `DLLFunc_ClientUserInfoChanged`.
- [CBaseEntity ReGameDLL](https://github.com/rehlds/ReGameDLL_CS/blob/master/regamedll/dlls/cbase.cpp): `TraceAttack`, `AddMultiDamage`, dano e remoção por `Killed` da entidade base.

ReAPI atende criação, remoção, leitura/escrita de variáveis e rodada. Fakemeta fornece primitivas do motor para hull, trace, tamanho, origem e `WalkMove`. Hamsandwich atende funções virtuais genéricas de entidades (`TraceAttack`, `TakeDamage`, `BloodColor`, `Use`) e despacho do dano de jogador. Usar essas interfaces evita offsets privados e simulação manual da geometria do BSP.

`hash_file(..., Hash_Md5, ...)` é a interface atual do AMXX, substituindo o native depreciado `md5_file`. O digest identifica o BSP usado para gerar o arquivo; o plugin calcula-o apenas ao inicializar o mapa.

## Exploração e cobertura do mapper

- [Yamauchi, 1997: exploração por fronteiras](https://www.cs.cmu.edu/~motionplanning/papers/sbp_papers/integrated2/yamauchi_frontier_explor.pdf): transição entre espaço conhecido e desconhecido como destino de exploração.
- [Choset e Pignon: decomposição boustrophedon](https://publications.ri.cmu.edu/coverage-path-planning-the-boustrophedon-decomposition): divisão em células para cobertura física de superfície.
- [FUEL](https://arxiv.org/abs/2010.11561) e [implementação dos autores](https://github.com/HKUST-Aerial-Robotics/FUEL): fronteiras incrementais e planejamento hierárquico para exploração.
- [Geração de áreas da Valve](https://github.com/ValveSoftware/source-sdk-2013/blob/master/src/game/server/nav_generate.cpp): regiões retangulares, conexões nas bordas e união preservando a forma convexa. Referência conceitual para os portais do projeto.
- [Configuração geométrica do Recast](https://recastnav.com/structrcConfig.html): raio, altura e inclinação do agente precisam entrar na construção de áreas.
- [Recast heightfield](https://recastnav.com/structrcHeightfield.html): grade de spans de altura usada na construção de regiões caminháveis.
- [Consulta de navegação Detour](https://recastnav.com/classdtNavMeshQuery.html): distinguir posição acessível, corredor de regiões e movimento ao destino; referência conceitual da busca entre posições e conectores, sem dependência ou código Detour no projeto.

Essas fontes orientam a camada adaptativa de cobertura e a seleção por fronteiras/custo. O mapper mantém seu grafo e as provas físicas próprias, sem importar código dessas bibliotecas nem resultados de desempenho de robôs para o HLDS. Veja [MAPPING_STRATEGY.md](MAPPING_STRATEGY.md) para a comparação e a decisão de implementação.

## Arrays e JSON — revisão 1.4, 01/10/2026

A pesquisa inicial em `https://amxx-api.csrevo.com/search.json?q=ArrayGetCell` não retornou conteúdo acessível nesta sessão. As assinaturas foram conferidas em `cellarray.inc`, `file.inc` e `json.inc` da instalação configurada em `LOCAL.md`, e comparadas com a referência oficial AMXX:

- [ArrayCreate](https://www.amxmodx.org/api/cellarray/ArrayCreate): tamanho do registro e reserva inicial; reserva não cria itens válidos e a estrutura cresce.
- [ArrayGetArray](https://www.amxmodx.org/api/cellarray/ArrayGetArray) e [ArraySetArray](https://www.amxmodx.org/api/cellarray/ArraySetArray): transferência de registros entre Pawn e o armazenamento dinâmico.
- [ArrayGetCell](https://www.amxmodx.org/api/cellarray/ArrayGetCell) e [ArraySetCell](https://www.amxmodx.org/api/cellarray/ArraySetCell): o argumento `block` seleciona a célula dentro do registro; usado para flags, ligação e estados isolados.
- [json_parse](https://www.amxmodx.org/api/json/json_parse): parse de texto/arquivo em uma chamada, retornando uma árvore com handle que precisa ser liberado.
- [fflush](https://www.amxmodx.org/api/file/fflush): zero indica sucesso; a promoção do temporário exige flush bem-sucedido.

Conclusão de projeto, sem benchmark: mover registros esparsos para `Array:` remove reservas/caches artificiais, mas não torna acesso por native automaticamente mais rápido que arrays densos. JSON pode servir a ferramentas externas; trocar o grafo textual por uma árvore JSON não comprova aceleração e perderia o contrato atual de escrita incremental se fosse serializado em uma chamada. Mantém-se `ANPC_NAV 4`, com integridade de contagens e processamento de registros por etapas no mapper. A análise completa está em [SCAN_REVIEW.md](SCAN_REVIEW.md).
