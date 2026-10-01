# API pública

As includes do projeto ficam em `ANPC_INCLUDE_DIR`, a subpasta `advanced_npc` de `AMXX_INCLUDE_DIR`. Consulte os caminhos em `addon/advanced_npc/LOCAL.md`; para configurar outra máquina, siga a [preparação do ambiente local](../README.md#ambiente-local) e o [modelo público](../LOCAL.example.md). Edite as includes nesse diretório externo, sem adicioná-las ou duplicá-las neste repositório.

## Tipos

Registre cada tipo em `plugin_precache()`, seguindo `anpc_zombie_default.sma` como exemplo. Defina um `profile[AnpcProfile]`, chame `anpc_register_type()` e registre os sete slots de animação por **label**. O núcleo lê o descriptor studio v10 do modelo, obtendo sequência, FPS e quantidade de frames. Índices de outro modelo não precisam ser copiados.

O perfil é copiado e fica imutável durante o mapa. O modelo é precacheado nessa fase. Tipos incompletos ficam desabilitados. Novos tipos entram por outro plugin, sem adicionar condições específicas de classe ao núcleo.

| Campo | Significado/faixa validada |
| --- | --- |
| `ANPC_HEALTH` | 1 a 1.000.000 |
| `ANPC_SPEED` | 50 a 450 unidades/s |
| `ANPC_GRAVITY` | Multiplicador entre 0,1 e 2 |
| `ANPC_DAMAGE` | 1 a 10.000 |
| `ANPC_ATTACK_RANGE` | 32 a 112, medido até a superfície atingida pelo trace |
| `ANPC_ATTACK_COOLDOWN` | 0,2 a 10 s |
| `ANPC_ATTACK_WINDUP` | Pelo menos 0,05 s, menor que o cooldown |
| `ANPC_HEAD_MULTIPLIER` | 1 a 10 |
| `ANPC_KNOCKBACK` | 0 a 5; velocidade final recebe um limite |
| `ANPC_SENSE_INTERVAL` | 0,1 a 2 s |
| `ANPC_MEMORY_TIME` | 0 a 60 s |
| `ANPC_SIGHT_RANGE` | 64 a 8.192 |
| `ANPC_JUMP_SPEED` | Limite vertical entre 100 e 600 |
| `ANPC_CAPABILITIES` | Máscara `CROUCH`, `JUMP`, `LADDER`, `DOOR`, `BREAKABLE` |
| `ANPC_FACTION` | Neutra 0, zumbi 1, humana 2; outros ids podem ser definidos por uma integração |
| `ANPC_BLOOD_COLOR` | Valor do motor; o zumbi usa 110 |
| `ANPC_GLOBAL_HUNT` | 1 para rastreamento global; 0 para visão/memória |

## Entidades

| Native | Resultado/contrato |
| --- | --- |
| `anpc_register_type(name, model, profile)` | Id do tipo ou `ANPC_INVALID_TYPE` |
| `anpc_register_animation(type, slot, label)` | `bool`; somente o plugin que registrou o tipo pode configurar animações |
| `anpc_find_type(name)` | Procura o tipo por nome; use nomes em arquivos persistentes |
| `anpc_get_type_name(type, buffer, length)` | Copia o nome; retorna tamanho copiado |
| `anpc_create(type, feet, yaw)` | Edict do NPC ou 0; exige grafo, âncora, hull livre, chão e capacidade |
| `anpc_remove(entity)` | Agenda remoção; retorna `bool` |
| `anpc_remove_all()` | Quantidade de entidades cuja remoção foi agendada |
| `anpc_is_npc(entity)` | Valida identidade do edict, incluindo slot/serial |
| `anpc_get_type(entity)` / `anpc_get_faction(entity)` | Tipo/facção; invalidez retorna tipo -1/facção neutra |
| `anpc_get_state(entity)` | Estado; entidade inválida retorna `ANPC_DEAD` |
| `anpc_get_target(entity)` | Jogador alvo ou 0 |
| `anpc_get_serial(entity)` | Serial próprio ou 0; associe-o ao edict ao guardar referências |
| `anpc_get_count()` / `anpc_get_capacity()` | Slots ocupados/capacidade configurada |

Exemplo de criação em um addon, depois do carregamento/configuração:

```pawn
new Float:feet[3] = {256.0, -128.0, 0.0}
new type = anpc_find_type("zombie_default")
new entity = anpc_create(type, feet, 90.0)
if (entity)
{
    // Guarde também anpc_get_serial(entity) se usar essa referência depois.
}
```

Callbacks podem usar a remoção diferida. Para extensões, use a API de remoção em vez de destruir diretamente o edict durante outro callback. Não pause/descarregue o provedor de navegação enquanto consumidores mantêm entidades ou rotas abertas.

## Forwards

`anpc_target_filter`, `anpc_damage_pre` e `anpc_attack_pre` aceitam `ANPC_BLOCK` para impedir a operação; `ANPC_CONTINUE` permite. Os argumentos são valores de observação, sem alteração por referência. `anpc_attack_pre/post` são emitidos para ataques a jogadores; obstáculos usam o fluxo original de dano do mapa.

`anpc_spawn_post` informa edict/tipo. `anpc_state_changed` informa estado anterior/atual. `anpc_damage_post` acontece depois de atualizar HP. `anpc_death_post` informa NPC morto/agressor; o corpo ainda existe. `anpc_remove_pre` acontece antes da destruição final.

`anpc_attack_post` informa que o golpe foi enviado ao fluxo de dano. Outros plugins, armadura e regras do jogo ainda podem alterar seu resultado; o valor do forward é o dano solicitado.

## Navegação

`anpc_nav_open()` cria um handle de rota. A geração e o proprietário são validados em `close`, `cancel`, `request`, `status` e leitura de caminho. Retorne o recurso com `anpc_nav_close()`. O limite de rotas abertas é compartilhado com os slots máximos de NPCs.

O consumidor solicita `anpc_nav_request(route, start, goal, capabilities)`, aguarda `ANPC_PATH_READY` ou `ANPC_PATH_FAILED` e consulta `anpc_nav_path_size()`/`anpc_nav_path_node()`. Um caminho inclui nó inicial e final. Requisições são assíncronas e invalidam o caminho anterior daquele handle.

`anpc_nav_nearest()` procura âncora fisicamente acessível próxima dos pés. `anpc_nav_find_near(feet, radius, max_height, exclude = ANPC_INVALID_NODE)` faz consulta geométrica pelo índice espacial, sem provar acesso; `exclude` impede reutilizar o próprio nó de origem. `anpc_nav_nearest()` usa alcance padrão de 512 unidades e prioriza âncoras da área atual. `anpc_nav_walkable()` verifica até 512 unidades de terreno amostrado, ou 768 quando todo o segmento possui cobertura de áreas. `anpc_nav_node()` consulta coordenadas/flags/raio. `anpc_nav_link()` consulta uma ligação disponível, respeitando bloqueio temporário. `anpc_nav_link_count()` e `anpc_nav_link_at(node, index, destination, flags, jump_velocity)` enumeram somente arestas físicas, incluindo velocidade. `anpc_nav_link()` também reconhece WALK implícito dentro de uma área. Para enumerar toda a conectividade, use `anpc_nav_neighbor_next` com cursor inicialmente zero; `ANPC_NEIGHBOR_EDGE` fornece destino/flags/custo, `ANPC_NEIGHBOR_PENDING` pede outra chamada e `ANPC_NEIGHBOR_DONE` encerra. `anpc_nav_ladder()` procura uma escada real na região.

`anpc_nav_walkable()` reutiliza o apoio estático quando o segmento inteiro passa por retângulos validados e acompanha seus planos, mas ainda verifica o hull contra os sólidos atuais. Nos outros casos, mede o apoio com hull de jogador, acompanha rampas/cristas e respeita a inclinação caminhável da normal (`z >= 0.7`) e o `sv_stepsize` atual por intervalo. Um teste de corredor atende pisos planos e rampas uniformes; geometrias curvas usam verificações locais de piso e folga. Exige que a altura de chegada corresponda ao piso do destino, sem trocar de andar apenas por compartilhar XY. A consulta geométrica não cria uma ligação e não garante execução por todos os perfis de NPC.

| Native de área | Contrato |
| --- | --- |
| `anpc_nav_area_count()` | Quantidade de retângulos em memória |
| `anpc_nav_area(area, mins, maxs, normal, flags)` | Lê limites XY, plano de apoio dos pés e postura; Z em cada vetor corresponde ao seu canto |
| `anpc_nav_area_at(feet, capabilities = ANPC_CAP_ALL)` | Maior retângulo que contém os pés e aceita as capacidades, ou `-1`; não prova rota |
| `anpc_nav_area_add(mins, maxs, normal, flags = 0)` | Somente proprietário da edição; recebe um retângulo previamente validado, retorna ID ou `-1`; pode reutilizar/unir áreas compatíveis |
| `anpc_nav_area_clear()` | Somente proprietário da edição; remove certificados e conectividade implícita, preservando nós/arestas físicas |
| `anpc_nav_area_segment(from, to, capabilities = ANPC_CAP_ALL)` | Apoio contínuo em até 64 retângulos, sem trace de colisão; planos e posturas precisam corresponder |
| `anpc_nav_area_finish_step(remap, removed, portals, physical_links, portal_limit)` | Somente proprietário da edição, após esgotar exploração; 16 operações por chamada; retorna -1 erro, 0 pendente ou 1 pronto. Ao concluir entrega IDs antigos→novos (-1 removido), contagens, arestas físicas e tentativas de portal recusadas por capacidade |

O chamador de `area_add` deve provar piso estático plano e espaço de hull em toda a resolução da área, excluindo volumes sensíveis, antes da gravação. A native valida estrutura e limites, não repete essa análise. Lados devem ter 32 a 256 unidades e permanecer na mesma célula espacial de 256; flags admitem somente `ANPC_NODE_CROUCH`. A união exige planos/posturas compatíveis, contato por uma borda e extensão igual no outro eixo, sem preencher buracos ou formas em L. Bordas XY são inclusivas para associação de portais; pisos sobrepostos são independentes.

Mutadores `add`, `set_flags`, `connect` e `disconnect` invalidam rotas e emitem `anpc_nav_changed(revision)`. O editor exige ausência de NPCs para essas operações. Consumidores de baixo nível devem respeitar essa mesma política de operação. `block_link` é a indisponibilidade temporária usada durante o jogo e não altera permanentemente o arquivo.

`anpc_nav_begin_edit()` adquire edição exclusiva para o plugin chamador e invalida rotas anteriores. Durante essa edição, somente o proprietário pode alterar, bloquear ligações, salvar, recarregar ou solicitar novas rotas. Suas mutações acumulam uma alteração pendente, evitando invalidar a rota do explorador a cada nó acrescentado. `anpc_nav_end_edit()` libera e publica a revisão final. `anpc_nav_editing()` consulta o estado; `anpc_nav_reset()` esvazia a topologia em memória e só aceita o proprietário. O arquivo salvo não é apagado por `reset`. O chamador deve liberar a edição antes de pausar/descarregar seu plugin.

`nav_save` grava somente o formato atual. `nav_reload` rejeita registros inválidos; arquivo malformado deixa o grafo vazio e invalida rotas. Se o arquivo não existe, o reload retorna falso sem substituir o grafo em memória.

## Scanner

A include `advanced_npc/advanced_npc_mapper.inc` declara a biblioteca `advanced_npc_mapper`.

| Native | Contrato |
| --- | --- |
| `anpc_scan_start(reset_graph = false)` | Inicia uma sessão; `false` se já existe scan, NPCs, falta vaga/rota/BSP ou falha a criação do bot |
| `anpc_scan_stop(save = true)` | Solicita encerramento; salvar é assíncrono e mantém `running=true` até o commit final |
| `anpc_scan_running()` | Sessão ativa, inclusive durante pausa/gravação |
| `anpc_scan_bot()` | Id do fake client com identidade/userid válidos, ou 0 |
| `anpc_scan_status()` | `AnpcScanStatus`, definido na include |

`anpc_scan_started(bot)` informa a sessão iniciada. `anpc_scan_finished(completed, saved, nodes, links)` informa encerramento; `completed` significa candidatos esgotados e `saved` significa navegação confirmada em arquivo. O último checkpoint anterior pode continuar existindo mesmo com `saved=false`. `anpc_scan_edge_verified(from, to, flags)` observa uma ligação validada: passagem percorrida ou sua caminhada inversa provada por cobertura estática plana. Os callbacks são de observação e não autorizam modificar o grafo enquanto o mapper o possui.

Para addons, `anpc_scan_bot()` identifica o explorador pela vaga, `userid`, conexão, private data e estado de fake client. Não use campos `iuser*` do jogador como marcadores: `iuser4` pertence ao estado de veículos do GameDLL e é sobrescrito durante o movimento. O scanner exige ausência de NPCs e mantém a criação deles bloqueada enquanto possui o grafo. O mapper não altera o núcleo ZPN; consumidores podem consultar as natives ou `anpc_scan_active` quando desejarem cooperar com uma sessão de análise.
