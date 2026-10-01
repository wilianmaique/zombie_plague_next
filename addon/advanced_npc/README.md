# Advanced NPC 1.3

NPCs por entidade para CS 1.6, com navegação A*, animações, percepção e combate. O `anpc_mapper.sma` cria de um a oito fake clients temporários, configurados por `anpc_scan_bots`, para explorar o mapa e gerar a navegação pelo próprio servidor. Esse modo usa AMXX, ReAPI, Fakemeta e Hamsandwich; não exige YaPB, Python nem um módulo próprio em C++.

Áreas retangulares representam chão plano ou rampas uniformes, com espaço verificado para o hull. O NPC navega entre portais e transições; o interior certificado dispensa uma malha de pontos. O HUD desenha as áreas mesmo quando não há nós dentro delas.

O explorador usa a física de jogador para andar, agachar, saltar e subir escadas. As travessias geram conexões após movimento real. Dentro de piso estático plano validado, a mesma prova permite acrescentar a caminhada inversa sem repetir o percurso; saltos, quedas, escadas e regiões irregulares continuam exigindo testes separados da volta.

A navegação combina retângulos de piso livre com âncoras de passagem. Quadrados de 256 a 32 unidades são validados por etapas e gravados no `.nav`; quadrados adjacentes compatíveis podem formar retângulos. O mapper dispensa pontos intermediários dentro desses interiores e reutiliza âncoras próximas somente com acesso comprovado. Bordas, quinas, rampas, saltos e escadas preservam pontos necessários. Saídas desconhecidas têm prioridade e o custo das rotas direcionadas orienta a próxima região.

Caixas recebem candidatos de aterrissagem perto da face encontrada, evitando mirar apenas um ponto além do obstáculo. O mapper verifica recuo, apoio da corrida e velocidade real antes de saltar; tentativas que falham deixam de criar grupos de pontos de decolagem. O NPC pode encurtar caminhos dentro de um retângulo validado e usar agachamento no ar quando o perfil permite.

Rampas usam apoio medido pelo hull inteiro e acompanhamento do relevo, com alvos longos e nós pelo espaçamento XY. Mudanças de inclinação preservam âncoras antes de cristas. O provedor usa as mesmas consultas, e o NPC tenta passadas menores no mesmo Think antes dos desvios laterais; há tratamento restrito para o teste de apoio em rampas diagonais.

## Ambiente local

Os caminhos do compilador e das includes ficam em `LOCAL.md`, nesta pasta. Esse arquivo é ignorado pelo Git. O [modelo público](LOCAL.example.md) explica os campos sem expor caminhos pessoais.

Para configurar outra máquina, copie o modelo a partir da raiz do repositório, somente se `LOCAL.md` ainda não existir:

```powershell
Copy-Item .\addon\advanced_npc\LOCAL.example.md .\addon\advanced_npc\LOCAL.md
```

Preencha `AMXX_COMPILER`, `AMXX_INCLUDE_DIR` e `ANPC_INCLUDE_DIR` com os caminhos dessa máquina. A documentação usa esses nomes para se referir aos caminhos registrados no arquivo local.

## Instalação

1. Copie os seis `.amxx` de `compiled/advanced_npc/` para `cstrike/addons/amxmodx/plugins/advanced_npc/`.
2. Instale `configs/plugins-advanced_npc.ini` conforme a organização do servidor, preservando a ordem dos plugins. O mapper fica depois do core.
3. Copie `configs/advanced_npc.cfg` para `cstrike/addons/amxmodx/configs/advanced_npc/advanced_npc.cfg`. Os arquivos de mapa ficam na subpasta `maps/`.
4. Instale o modelo `models/player/zpn_z_default/zpn_z_default.mdl` já usado pelo projeto para o tipo de NPC padrão. O explorador usa um modelo de jogador do CS.

As includes permanecem em `ANPC_INCLUDE_DIR`, a subpasta `advanced_npc` de `AMXX_INCLUDE_DIR` indicada em `LOCAL.md`, incluindo `navigation_areas.inc` e `navigation_portals.inc`. Edite-as nesse diretório externo, sem duplicá-las no repositório. Recompile os consumidores alterados junto com o provedor para usar as consultas de áreas e a assinatura atual de `anpc_nav_find_near`.

`core/zpn_main.sma` permanece sem integração do scanner. Faça a geração em uma sessão de manutenção, sem modos de jogo ou outros plugins controlando a equipe, a classe ou a vida do bot.

## Gerar navegação

No console do servidor ou via RCON:

```text
anpc_clear
anpc_status
anpc_scan_bots 4
anpc_scan start new
anpc_scan status
```

Aguarde a remoção dos NPCs antes de iniciar. `start new` começa um grafo vazio em memória. A navegação anterior só é substituída ao salvar um checkpoint, com backup `.bak`. Esta revisão usa `ANPC_NAV 3`: gere novamente mapas antigos ou reimporte seus grafos YaPB com o importador atualizado. Use `start new` para medir a nova geração de áreas sem os pontos anteriores. Checkpoints preservam IDs de exploração; quando o scan esgota os candidatos, remove amostras comuns do interior certificado e gera portais nas bordas compartilhadas. Saltos, escadas e trechos irregulares mantêm suas âncoras.

Cada explorador tem movimento, sondagens e rota próprios. Sementes afastadas e reservas de fronteiras distribuem o trabalho; todos alimentam o mesmo grafo. O mapper usa as vagas disponíveis, mantendo uma livre para o administrador. O padrão é um explorador; a quantidade é capturada ao iniciar. Desvios com apoio validado e o filtro de colisão entre scouts evitam bloqueios e impedem que um sirva de chão para outro.

Para observar o primeiro explorador pelo cliente de um administrador com `ADMIN_RCON`:

```text
anpc_scan watch 1
anpc_scan blocks 1
anpc_nav_show 1
```

Use `anpc_scan watch 1 2` para observar o segundo, ou outro índice de 1 até a quantidade ativa. `status` mostra cada scout. Pausa, checkpoints e encerramento abrangem toda a equipe; a conclusão automática aguarda todos esgotarem o trabalho.

Para salvar e encerrar:

```text
anpc_scan stop
```

Espere `anpc_scan status` mostrar `active=0`: a gravação é distribuída por vários frames. Para continuar depois, inclusive após trocar/recarregar o mapa:

```text
anpc_scan start
```

O próprio plugin grava `maps/<mapa>.nav`, `maps/<mapa>.scan` e `maps/<mapa>.scan.txt` dentro de `configs/advanced_npc/`. O `.nav` já é o arquivo consumido pelos NPCs. A memória `.scan` só é reutilizada se mapa, BSP, arquivo `.nav`, parâmetros físicos e política de exploração corresponderem.

Veja [o funcionamento e os limites do explorador](docs/AUTOMAPPER.md), [a análise das técnicas de cobertura](docs/MAPPING_STRATEGY.md), [o editor de navegação](docs/NAVIGATION.md), [a API](docs/API.md) e [os cenários para teste manual](docs/TESTING.md).

Esta revisão precisa de compilação manual de `anpc_mapper.sma`, `anpc_navigation.sma`, `anpc_core.sma` e `anpc_admin.sma`, com as includes externas atualizadas. Os binários existentes pertencem a revisões anteriores. As conferências de fontes e do importador estão em `docs/TESTING.md`; compilação e validação no HLDS ficam para o usuário.

A alteração para vários exploradores exige recompilar manualmente `anpc_mapper.sma` com as includes externas atuais, incluindo `mapper_team.inc`. O orçamento de geometria continua compartilhado; o ganho de tempo e o custo adicional da física dos jogadores precisam ser medidos no servidor.
