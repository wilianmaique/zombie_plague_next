# Ambiente local do Advanced NPC

Este é o modelo público. Copie-o para `LOCAL.md`, na mesma pasta, e preencha os caminhos da sua máquina conforme o [README](README.md#ambiente-local). O arquivo `LOCAL.md` é ignorado pelo Git; mantenha este modelo sem informações pessoais.

## Caminhos

| Identificador | Caminho a preencher | Finalidade |
| --- | --- | --- |
| `AMXX_COMPILER` | `<pasta-do-compilador>/amxxpc.exe` | Executável usado na compilação manual. |
| `AMXX_INCLUDE_DIR` | `<pasta-do-compilador>/include` | Diretório das includes do AMXX, ReAPI e do projeto. |
| `ANPC_INCLUDE_DIR` | `<pasta-do-compilador>/include/advanced_npc` | Includes do Advanced NPC, dentro de `AMXX_INCLUDE_DIR`. |

Substitua `<pasta-do-compilador>` pelo caminho absoluto da instalação usada nessa máquina. Confirme que o executável e os dois diretórios existem. O histórico de testes registra AMXX 1.10.0.5467; use as includes correspondentes ao ambiente configurado do projeto.

Os identificadores são nomes de referência usados na documentação. Este arquivo não é carregado pelos plugins nem define variáveis de ambiente.

## Uso

- Antes de consultar ou alterar a API, leia `LOCAL.md` para localizar as includes externas.
- Edite as includes diretamente em `ANPC_INCLUDE_DIR`, sem criar cópias no repositório. Isso inclui `advanced_npc.inc`, `advanced_npc_navigation.inc`, `advanced_npc_mapper.inc` e as includes internas, como `navigation_areas.inc`.
- Atualize provedores, consumidores e includes juntos quando uma assinatura mudar. A compilação é manual; o Codex só pode compilar quando o usuário solicitar explicitamente.
- Os caminhos relativos dos comandos públicos continuam sendo resolvidos a partir da raiz do repositório, salvo quando a documentação indicar uma pasta do servidor.
