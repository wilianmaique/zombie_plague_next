# Combate, movimento e desenho — revisão 1.7.0

Revisão de 01/10/2026, motivada por NPCs parados, ataque oscilando, poses abaixo do chão, jogador sobre mureta e desenho de navegação que desaparece. As correções são no core, administração e includes externas `studio.inc`, `combat.inc`, `perception.inc` e `movement.inc`. A versão está em `advanced_npc_limits.inc`. Os caminhos locais permanecem em `LOCAL.md`; as includes não devem ser copiadas para o repositório.

## Causas identificadas no código

O estado `ATTACK` terminava no impacto, com 0,28 s no perfil padrão, embora o próximo golpe só pudesse começar após 1 s. Nesse intervalo o NPC voltava a caminhar para dentro do jogador e trocava ataque/corrida repetidamente. Algumas esperas mantinham a corrida selecionada. Um hull abaixado também podia receber a sequência de repouso em pé, cujo centro está 18 unidades acima do centro desse hull.

O modelo padrão instalado tem `ref_shoot_knife` com 51 frames, 30 FPS e flag de repetição. Limitar o frame no servidor a 255 não impede sozinho que a previsão do cliente volte ao início: o renderer considera `frame`, `animtime`, `framerate` e a flag do descriptor. Isso foi conferido no [renderer do SDK da Valve](https://github.com/ValveSoftware/halflife/blob/master/cl_dll/StudioModelRenderer.cpp).

O desenho anterior podia emitir 96 beams de uma vez: 32 marcadores, 32 ligações e 32 lados de áreas, repetidos a cada 0,2 s. O HUD tinha tempo de permanência zero. O [ReHLDS descarta datagramas não confiáveis que excedem o espaço disponível](https://github.com/rehlds/ReHLDS/blob/master/rehlds/engine/sv_main.cpp). Esse volume é uma causa possível de perda dos efeitos; não há log do servidor que confirme que foi a causa das imagens enviadas.

## Ciclo de ataque e animação

O ataque fixa vítima e `userid`, prepara o golpe, verifica contato e emite dano uma vez, mantendo o estado durante a recuperação. Marca o impacto antes dos forwards para impedir reentrada. Após `anpc_attack_pre`, confere novamente identidade, elegibilidade, distância e obstáculo. Breakables conservam seu `TakeDamage` original.

O ciclo dura `max(cooldown, windup + 0.1)`. A sequência é ajustada ao ciclo; no perfil padrão são 1 s, com impacto em 0,28 s. O NPC acompanha a orientação da vítima e conserva o hull/postura durante o golpe. Continua sujeito à física e ao knockback. Se o jogador ficar ao alcance durante uma espera por cooldown, o NPC para de avançar contra ele.

O relógio de animação usa o tempo desde a troca/última atualização da sequência. Trocar a sequência não acrescenta o delta de movimento que precedeu a troca. Corrida e postura se baseiam no deslocamento observado, incluindo `WalkMove`; repouso tem a cadência normal e o NPC abaixado parado conserva uma pose abaixada sem girar o ciclo de caminhada. A troca corrida/repouso tem limiares de 12/6 unidades/s. Quando disponível, a velocidade nominal vem do deslocamento linear do MDL, conforme [GetSequenceInfo do SDK](https://github.com/ValveSoftware/halflife/blob/master/dlls/animation.cpp); caso contrário usa a velocidade do perfil e seu fator de agachamento.

Ataques/morte com flag de repetição são publicados com avanço de frames pelo servidor e sem extrapolação de ciclo no cliente. No fim da execução, o frame permanece limitado e `framerate` fica zerado. Não há modificação dos arquivos MDL. A suavidade visual precisa ser conferida no cliente CS 1.6, especialmente se a frequência de Think tiver sido aumentada para além dos 0,05 s padrão.

## Alcançar o jogador sobre uma mureta

O contato de melee considera até três pontos dentro do hull real do alvo: a superfície mais próxima e duas alturas superiores. O trace precisa atingir o próprio alvo dentro do alcance, sem sólido inicial. Paredes e outros jogadores/NPCs continuam bloqueando o golpe. Planejamento ignora atores móveis; o impacto efetivo testa todos eles novamente.

Para um alvo acima do passo normal, o core avalia até oito posições ao redor dele, com raio entre 36 e 96 unidades. Cada posição precisa de piso estático, hull em pé livre, altura próxima ao piso atual do NPC e uma linha de golpe ao alcance. A mais próxima compete como destino de movimento/busca. A aproximação usa o corredor e conectores existentes, em vez de exigir que o NPC alcance o topo exato da mureta.

A consulta fica em cache por 0,75 s; movimento do alvo de 24 unidades, mudança de piso ou limpeza da rota renovam a base. Se A* rejeitar uma posição de ataque, o core exclui sua amostra e tenta outra. A expiração do cache não apaga as exclusões. Candidatos próximos também preservam sua nova identidade enquanto aguardam o intervalo de replanejamento. O conjunto é finito; não se declara acessível um destino apenas por existir chão nele. Escadas e memória local antiga conservam o destino normal.

São amostras locais, não uma prova de melhor posição em todo o mapa. A* continua minimizando o custo no grafo e nos conectores validados disponíveis. A separação de corredor, movimento local e chegada segue o princípio de [dtPathCorridor/Detour](https://recastnav.com/classdtPathCorridor.html), aplicado às áreas retangulares do projeto, sem adicionar a biblioteca.

## Saltos e outros NPCs

Se a caminhada direta falhar perto de uma elevação, o core pode tentar um salto local antes de rejeitar a rota: distância XY de 24 a 128 unidades, altura maior que o passo, capacidade `JUMP` e ator apoiado. O destino precisa de piso e hull livre. O solver já usado nas arestas comprova toda a trajetória com gravidade, velocidade máxima e possível agachamento no ar. Não cria nós ou arestas permanentes.

Há no máximo duas provas locais por frame do motor e nova tentativa do mesmo ator após 0,4 s. Esperar a admissão no orçamento não rejeita um alvo por causa da rota anterior. Saltos longos e escadas continuam seguindo transições mapeadas.

Na previsão de obstáculos móveis, atores apoiados usam deslocamento observado: `var_velocity` permanece zerada na caminhada por `WalkMove`. Atores em voo usam velocidade física. O desvio conserva seu lado e verifica piso/hull; prioridade por serial continua permitindo ceder passagem em corredor estreito. Uma colisão com a multidão não basta para trocar para o hull abaixado: o fallback exige que o trecho em pé realmente falhe na geometria e que a postura abaixada passe.

Na criação, `DropToFloor` precisa retornar exatamente 1. O [motor retorna -1 para uma consulta inteiramente sólida](https://github.com/rehlds/ReHLDS/blob/master/rehlds/engine/pr_cmds.cpp), que antes passava no teste por negação booleana.

## Visualizador e validação

`anpc_nav_show` usa um callback de frame, com no máximo 32 beams por seleção: oito marcadores, oito ligações e quatro contornos. Envia quatro beams a cada 0,05 s, seleciona novamente após 0,5 s e depois de drenar a fila. O HUD permanece por 0,65 s. Desconexão e desativação limpam a fila; uma câmera sem amostras continua recebendo seleções futuras. A seleção de área também testa um ponto à frente da câmera, independentemente de âncoras.

Passaram **192 testes Python**, incluindo **42 novos casos** em `test_combat_animation.py`, e a conferência estrutural de **27 fontes Pawn** dos seis plugins. As fixtures executam funções das includes instaladas com colisões por slabs, descriptors MDL binários e doubles das natives. Não são bytecode AMXX nem execução do HLDS. Compilação, FPS, tráfego real e aspecto visual no CS 1.6 continuam pendentes de teste manual.

Recompile manualmente os seis plugins com as includes externas atuais e carregue os binários juntos. Os formatos continuam `ANPC_NAV 4` e `ANPC_SCAN 3`; esta revisão não exige refazer o scan. Compare repouso, ataque próximo, jogador sobre mureta, caixa acessível por salto, corredor com vários NPCs, câmera de espectador e ligar/desligar `anpc_nav_show 1`. A [matriz de testes](TESTING.md) registra os cenários e resultados esperados.
