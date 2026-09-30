# Advanced NPC 1.1

NPCs por entidade para CS 1.6, com navegação A*, animações, percepção e combate. O novo `anpc_mapper.sma` cria um fake client temporário para explorar o mapa e gerar a navegação pelo próprio servidor. Esse modo usa AMXX, ReAPI, Fakemeta e Hamsandwich; não exige YaPB, Python nem um módulo próprio em C++.

O explorador usa a física de jogador para andar, agachar, saltar e subir escadas. Traces sugerem trajetos; uma conexão nova só é gravada depois de um deslocamento real. Retornos também são tentados fisicamente, pois saltos e quedas podem funcionar em apenas um sentido.

## Instalação

1. Copie os seis `.amxx` de `compiled/advanced_npc/` para `cstrike/addons/amxmodx/plugins/advanced_npc/`.
2. Instale `configs/plugins-advanced_npc.ini` conforme a organização do servidor, preservando a ordem dos plugins. O mapper fica depois do core.
3. Copie `configs/advanced_npc.cfg` para `cstrike/addons/amxmodx/configs/advanced_npc/advanced_npc.cfg`. Os arquivos de mapa ficam na subpasta `maps/`.
4. Instale o modelo `models/player/zpn_z_default/zpn_z_default.mdl` já usado pelo projeto para o tipo de NPC padrão. O explorador usa um modelo de jogador do CS.

As includes permanecem em `D:\GOOGLE DRIVE\Counter-Strike\Ferramentas\compiler\include\advanced_npc`. Recompile os consumidores da API junto com o provedor; `anpc_nav_link_at` agora também retorna a velocidade de salto.

`core/zpn_main.sma` permanece sem integração do scanner. Faça a geração em uma sessão de manutenção, sem modos de jogo ou outros plugins controlando a equipe, a classe ou a vida do bot.

## Gerar navegação

No console do servidor ou via RCON:

```text
anpc_clear
anpc_status
anpc_scan start new
anpc_scan status
```

Aguarde a remoção dos NPCs antes de iniciar. `start new` começa um grafo vazio em memória. A navegação anterior só é substituída ao salvar um checkpoint, com backup `.bak`.

O explorador anda sozinho. Para observar pelo cliente de um administrador com `ADMIN_RCON`:

```text
anpc_scan watch 1
anpc_nav_show 1
```

Para salvar e encerrar:

```text
anpc_scan stop
```

Espere `anpc_scan status` mostrar `active=0`: a gravação é distribuída por vários frames. Para continuar depois, inclusive após trocar/recarregar o mapa:

```text
anpc_scan start
```

O próprio plugin grava `maps/<mapa>.nav`, `maps/<mapa>.scan` e `maps/<mapa>.scan.txt` dentro de `configs/advanced_npc/`. O `.nav` já é o arquivo consumido pelos NPCs. A memória `.scan` só é reutilizada se mapa, BSP, arquivo `.nav` e parâmetros físicos corresponderem.

Veja [o funcionamento e os limites do explorador](docs/AUTOMAPPER.md), [o editor de navegação](docs/NAVIGATION.md), [a API](docs/API.md) e [os cenários para teste manual](docs/TESTING.md).

Os seis plugins foram compilados com AMXX 1.10.0.5467, sem erros nem avisos. A validação em jogo do scanner fica a cargo do usuário nesta entrega.
