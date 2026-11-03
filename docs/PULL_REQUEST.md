# Bloco de Notas: sincronização SQLite + Firebase, categorias, pesquisa e lixeira

## Resumo

Evolução do bloco de notas com armazenamento **offline-first**: as notas são
gravadas no SQLite e sincronizadas com o Cloud Firestore, associadas ao
usuário autenticado e protegidas por regras de segurança. Foram adicionadas
categorias, pesquisa por título/conteúdo e, como funcionalidades extras,
**lixeira com recuperação** e **ordenação por data**.

## O que foi desenvolvido

### Banco local + Firebase
- Novo esquema SQLite (v2) com ids UUID, categorias, datas de criação/
  atualização, lixeira (`deleted_at`), status de sincronização e índice de
  pesquisa normalizado. Migração a partir da v1 (cujo `CREATE TABLE` tinha
  erro de sintaxe).
- Camada remota `FirestoreDataSource` (`users/{uid}/notes` e
  `users/{uid}/categories`), com timeout e tradução de erros (`RemoteException`).
- `SyncService` + `SyncMerger`: envia pendências, baixa alterações de outros
  aparelhos, replica exclusões e resolve conflitos por *last write wins*.
- Sincroniza ao entrar, após cada alteração, ao puxar a lista, pelo botão e
  quando a conexão volta (`connectivity_plus`).
- Tratamento de erros: sem rede, timeout, acesso negado, sessão expirada e
  Firebase não configurado, com aviso na tela e nenhuma perda de dados.
- `firestore.rules`: cada usuário só acessa `users/{seu uid}`; validação de
  campos e tipos. Testado com 11 cenários no Firebase Emulator.

### Categorias e pesquisa
- Categorias padrão + criar, renomear e excluir categorias; escolha (ou
  criação) da categoria no formulário da nota; filtro por categoria.
- Pesquisa por título ou conteúdo, sem diferenciar acentos/maiúsculas, com
  destaque do termo e contador de resultados.

### Funcionalidades adicionais
- Lixeira com restauração, "Desfazer", exclusão definitiva, esvaziar e
  expiração automática em 30 dias (sincronizada entre aparelhos).
- Ordenação por última atualização, data de criação ou título.

### Segurança
- `google-services.json` removido do repositório; as chaves passam a ser
  lidas de `firebase.env.json` (ignorado pelo Git) via
  `--dart-define-from-file`. Modelo em `firebase.env.example.json`.
- Permissões de rede adicionadas ao `AndroidManifest.xml` principal.

## Arquivos principais
- `lib/data/local/database_helper.dart`, `lib/data/remote/*`
- `lib/repositories/*`, `lib/services/sync_service.dart`, `lib/services/sync_merger.dart`
- `lib/controllers/notes_controller.dart`, `lib/core/app_dependencies.dart`
- `lib/pages/*` (notas, formulário, categorias, lixeira, auth gate)
- `firestore.rules`, `firestore_rules_test/`, `test/`, `README.md`

## Como testar
1. Configurar o Firebase conforme a seção 5 do README.
2. `flutter pub get`
3. `flutter run --dart-define-from-file=firebase.env.json`
4. Testes: `flutter analyze`, `flutter test` (32 testes) e
   `cd firestore_rules_test && npm install && npm test` (11 testes).

## Evidências
Capturas do app e do Console do Firebase na seção 2 do README.
