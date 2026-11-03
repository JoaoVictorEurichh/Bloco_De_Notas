// Testes das regras de segurança (firestore.rules) no Firebase Emulator.
// Executar: npm test (dentro de firestore_rules_test/)
import { after, before, beforeEach, describe, it } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  serverTimestamp,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

let env;

const note = (id, uid, extra = {}) => ({
  id,
  uid,
  title: 'Título',
  content: 'Conteúdo',
  categoryId: null,
  createdAt: 1,
  updatedAt: 2,
  deletedAt: null,
  serverUpdatedAt: serverTimestamp(),
  ...extra,
});

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-bloco-notas',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
  });
});

after(async () => env?.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  // Dados existentes da Ana, gravados sem passar pelas regras.
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users/ana/notes/n1'), {
      ...note('n1', 'ana'),
      serverUpdatedAt: null,
    });
  });
});

describe('dono das notas', () => {
  it('lê, cria, edita e exclui as próprias notas', async () => {
    const db = env.authenticatedContext('ana').firestore();
    await assertSucceeds(getDoc(doc(db, 'users/ana/notes/n1')));
    await assertSucceeds(getDocs(collection(db, 'users/ana/notes')));
    await assertSucceeds(setDoc(doc(db, 'users/ana/notes/n2'), note('n2', 'ana')));
    await assertSucceeds(
      setDoc(doc(db, 'users/ana/notes/n1'), note('n1', 'ana', { title: 'Novo' })),
    );
    await assertSucceeds(deleteDoc(doc(db, 'users/ana/notes/n1')));
  });

  it('gerencia as próprias categorias', async () => {
    const db = env.authenticatedContext('ana').firestore();
    const ref = doc(db, 'users/ana/categories/c1');
    await assertSucceeds(
      setDoc(ref, { id: 'c1', uid: 'ana', name: 'Estudos', colorIndex: 0, updatedAt: 1 }),
    );
    await assertSucceeds(getDocs(collection(db, 'users/ana/categories')));
    await assertSucceeds(deleteDoc(ref));
  });
});

describe('outro usuário', () => {
  it('não consegue ler as notas da Ana', async () => {
    const db = env.authenticatedContext('bruno').firestore();
    await assertFails(getDoc(doc(db, 'users/ana/notes/n1')));
    await assertFails(getDocs(collection(db, 'users/ana/notes')));
  });

  it('não consegue alterar nem excluir as notas da Ana', async () => {
    const db = env.authenticatedContext('bruno').firestore();
    await assertFails(setDoc(doc(db, 'users/ana/notes/n1'), note('n1', 'ana')));
    await assertFails(updateDoc(doc(db, 'users/ana/notes/n1'), { title: 'hack' }));
    await assertFails(deleteDoc(doc(db, 'users/ana/notes/n1')));
  });

  it('não consegue criar nota na área da Ana se passando por ela', async () => {
    const db = env.authenticatedContext('bruno').firestore();
    await assertFails(setDoc(doc(db, 'users/ana/notes/n9'), note('n9', 'ana')));
  });
});

describe('usuário não autenticado', () => {
  it('não acessa nada', async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, 'users/ana/notes/n1')));
    await assertFails(setDoc(doc(db, 'users/ana/notes/n2'), note('n2', 'ana')));
  });
});

describe('validação dos dados', () => {
  it('rejeita nota com uid diferente do dono do caminho', async () => {
    const db = env.authenticatedContext('ana').firestore();
    await assertFails(setDoc(doc(db, 'users/ana/notes/n2'), note('n2', 'bruno')));
  });

  it('rejeita nota com id diferente do documento', async () => {
    const db = env.authenticatedContext('ana').firestore();
    await assertFails(setDoc(doc(db, 'users/ana/notes/n2'), note('outro', 'ana')));
  });

  it('rejeita campos extras ou com tipo errado', async () => {
    const db = env.authenticatedContext('ana').firestore();
    await assertFails(
      setDoc(doc(db, 'users/ana/notes/n2'), note('n2', 'ana', { admin: true })),
    );
    await assertFails(
      setDoc(doc(db, 'users/ana/notes/n2'), note('n2', 'ana', { updatedAt: 'ontem' })),
    );
  });

  it('rejeita categoria sem nome', async () => {
    const db = env.authenticatedContext('ana').firestore();
    await assertFails(
      setDoc(doc(db, 'users/ana/categories/c1'), { id: 'c1', uid: 'ana', name: '', updatedAt: 1 }),
    );
  });

  it('bloqueia coleções fora de users/{uid}', async () => {
    const db = env.authenticatedContext('ana').firestore();
    await assertFails(setDoc(doc(db, 'notes/n1'), note('n1', 'ana')));
    await assertFails(getDocs(collection(db, 'users')));
  });
});
