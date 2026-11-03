# Evidências no Firebase — roteiro de captura

Estas capturas precisam ser feitas no **seu** projeto Firebase, depois de
executar o app (seção 4 do README). Salve cada imagem nesta pasta com o nome
indicado; o README principal já aponta para esses arquivos.

Antes de capturar:

1. Crie **duas contas** no app (ex.: `aluno1@teste.com` e `aluno2@teste.com`).
2. Com a conta 1, crie 3 ou mais notas em categorias diferentes, crie uma
   categoria nova e mova uma nota para a lixeira.
3. Confirme no topo da tela do app a mensagem **"Sincronizado às HH:mm"**.

| Arquivo | O que capturar |
|---|---|
| `01_authentication.png` | Console › **Authentication › Usuários**, mostrando as duas contas e seus UIDs. |
| `02_firestore_notas.png` | Console › **Firestore Database › Dados**, caminho `users › {uid da conta 1} › notes`, com a lista de notas. |
| `03_firestore_documento.png` | Um documento de nota aberto, mostrando `title`, `content`, `categoryId`, `uid`, `updatedAt`, `serverUpdatedAt` (e `deletedAt` preenchido na nota que está na lixeira). |
| `04_firestore_categorias.png` | Caminho `users › {uid} › categories`, com as categorias padrão e a criada por você. |
| `05_regras.png` | Console › **Firestore › Regras**, mostrando o conteúdo de `firestore.rules` publicado. |
| `06_rules_playground.png` | Na aba Regras, abra o **Rules Playground**: tipo `get`, local `/users/{uid da conta 1}/notes/{id de uma nota}`, *Autenticado* com o UID da **conta 2** → clique em Executar e capture o resultado **Negado**. |

Evidências extras recomendadas (opcionais):

- Edite uma nota no app e capture o documento com o `updatedAt` alterado.
- Coloque o celular em modo avião, crie uma nota (o app mostra "Sem conexão"),
  reative a internet e capture a nota aparecendo no Firestore.
- Instale o app em outro aparelho/emulador, entre com a conta 1 e capture as
  notas recuperadas da nuvem.
